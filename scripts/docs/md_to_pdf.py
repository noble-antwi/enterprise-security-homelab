"""
Render a Markdown doc from docs/ into a styled PDF next to it, via headless Edge.

Usage (from the repo root):
    python scripts/docs/md_to_pdf.py docs/11-domain-controller-firewall.md
    python scripts/docs/md_to_pdf.py docs/*.md          # batch

Requirements: python-markdown (pip install markdown) and Microsoft Edge.
Output: docs/<name>.pdf alongside the source. Intermediate HTML is written to
the system temp directory and removed afterwards.
"""
from __future__ import annotations

import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zlib
from pathlib import Path

import markdown

EDGE_CANDIDATES = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

CSS = """
@page { size: A4; margin: 18mm 16mm 20mm 16mm; }
html { font-size: 10.5pt; }
body {
  font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
  color: #1b2630; line-height: 1.5; max-width: 100%; margin: 0;
}
h1 { font-size: 20pt; margin: 0 0 4pt; letter-spacing: .01em; }
h1 + p { color: #55677a; }
h2 { font-size: 14pt; margin: 22pt 0 8pt; padding-bottom: 3pt;
     border-bottom: 1.5px solid #0e7490; color: #0e4a5c; page-break-after: avoid; }
h3 { font-size: 11.5pt; margin: 16pt 0 6pt; color: #1b2630; page-break-after: avoid; }
p, li { orphans: 3; widows: 3; }
code { font-family: Consolas, "Cascadia Code", monospace; font-size: 9.2pt;
       background: #eef3f6; padding: 1px 4px; border-radius: 3px; }
pre code { display: block; padding: 8pt; overflow-x: auto; }
table { border-collapse: collapse; width: 100%; margin: 8pt 0 12pt; font-size: 9.2pt;
        page-break-inside: auto; }
tr { page-break-inside: avoid; }
th { text-align: left; background: #0e4a5c; color: #fff; padding: 5pt 7pt; font-weight: 600; }
td { padding: 5pt 7pt; border-bottom: 1px solid #d7e0e6; vertical-align: top; }
tr:nth-child(even) td { background: #f5f8fa; }
hr { border: 0; border-top: 1px solid #d7e0e6; margin: 16pt 0; }
strong { color: #0e4a5c; }
img { max-width: 100%; height: auto; display: block; margin: 12pt auto 4pt;
      border: 1px solid #cbd6dd; border-radius: 3px; page-break-inside: avoid; }
/* caption: a paragraph that is only emphasised text, sitting under a figure */
img + em, p > em:only-child { display: block; text-align: center; font-size: 8.8pt;
      color: #55677a; margin: 0 auto 10pt; max-width: 90%; }
blockquote { border-left: 3px solid #d97706; margin: 8pt 0; padding: 4pt 10pt; color: #55677a; }
.footer { margin-top: 24pt; font-size: 8.5pt; color: #8395a4; border-top: 1px solid #d7e0e6; padding-top: 6pt; }
"""


def find_edge() -> str:
    for p in EDGE_CANDIDATES:
        if os.path.exists(p):
            return p
    sys.exit("Microsoft Edge not found; install it or add its path to EDGE_CANDIDATES.")


def render(md_path: Path, edge: str) -> Path:
    text = md_path.read_text(encoding="utf-8")
    body = markdown.markdown(text, extensions=["tables", "fenced_code", "toc", "sane_lists"])
    title = next((ln.lstrip("# ").strip() for ln in text.splitlines() if ln.startswith("# ")), md_path.stem)
    # Resolve relative image paths (e.g. ../images/...) against the .md file's own
    # directory, since the rendered HTML lives in a temp dir. A trailing slash makes
    # the base act as a directory.
    base_uri = md_path.parent.resolve().as_uri() + "/"
    html = f"""<!doctype html><html><head><meta charset="utf-8"><title>{title}</title>
<base href="{base_uri}">
<style>{CSS}</style></head><body>{body}
<div class="footer">enterprise-security-homelab · docs/{md_path.name} · generated from Markdown</div>
</body></html>"""

    pdf_path = md_path.with_suffix(".pdf").resolve()
    # The intermediate HTML lives in its own directory and is NOT deleted until the
    # PDF has actually appeared. Edge with --headless=new can return from the parent
    # process before the render completes; deleting the source HTML in a finally block
    # then races the render, and Edge prints its "cannot reach this page" error page
    # instead. That failure is silent: a plausible-looking PDF is produced, identical
    # in size for every document.
    work_dir = Path(tempfile.mkdtemp(prefix="md2pdf-"))
    tmp_html = work_dir / "doc.html"
    tmp_html.write_text(html, encoding="utf-8")
    # A private profile dir stops Edge from handing the job to an already-running
    # instance (which would exit immediately without printing).
    profile_dir = tempfile.mkdtemp(prefix="edge-pdf-")
    before = pdf_path.stat().st_mtime if pdf_path.exists() else 0.0
    try:
        result = subprocess.run(
            [edge, "--headless=new", "--disable-gpu", "--no-first-run",
             f"--user-data-dir={profile_dir}", "--no-pdf-header-footer",
             # Let images and fonts load before the page is printed.
             "--virtual-time-budget=15000", "--run-all-compositor-stages-before-draw",
             f"--print-to-pdf={pdf_path}", tmp_html.as_uri()],
            capture_output=True, text=True, timeout=180,
        )
        # Wait for the file to appear and stop growing, rather than trusting the exit.
        deadline, last, stable = time.time() + 90, -1, 0
        while time.time() < deadline:
            if pdf_path.exists() and pdf_path.stat().st_mtime > before:
                size = pdf_path.stat().st_size
                stable = stable + 1 if size == last else 0
                last = size
                if stable >= 3 and size > 0:
                    break
            time.sleep(0.4)
        else:
            sys.exit(f"Edge did not produce {pdf_path}\nexit={result.returncode}\n{result.stderr[-2000:]}")
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)
        shutil.rmtree(profile_dir, ignore_errors=True)
    verify(md_path, pdf_path)
    return pdf_path


def verify(md_path: Path, pdf_path: Path) -> None:
    """Fail loudly if the PDF looks like Edge's error page rather than the document.

    Edge's error page renders as two pages carrying a single illustration and almost
    no text. A real document has more text operators than that, and one containing
    figures embeds an image object per figure.
    """
    data = pdf_path.read_bytes()
    pages = data.count(b"/Type /Page") + data.count(b"/Type/Page")
    text_ops = 0
    for m in re.finditer(rb"stream\r?\n(.*?)endstream", data, re.S):
        try:
            s = zlib.decompress(m.group(1))
        except Exception:
            continue
        text_ops += s.count(b"Tj") + s.count(b"TJ")
    # A render that lost the page entirely is fatal: it produces a plausible-looking
    # PDF, so nothing downstream would notice.
    if text_ops < 50:
        sys.exit(f"{pdf_path.name} failed verification ({pages} pages, {text_ops} text "
                 f"operators): the render is almost certainly Edge's error page, not the document.")

    # Broken image links are a defect in the Markdown rather than the render, so they
    # are reported and the PDF is still written.
    refs = re.findall(r"^!\[[^\]]*\]\(([^)]+)\)", md_path.read_text(encoding="utf-8"), re.M)
    missing = [r for r in refs if not (md_path.parent / r).exists()]
    images = data.count(b"/Subtype /Image") + data.count(b"/Subtype/Image")
    if missing:
        print(f"  WARNING: {len(missing)} image(s) referenced by {md_path.name} do not exist:",
              file=sys.stderr)
        for r in missing:
            print(f"    {r}", file=sys.stderr)
    elif refs and images < len(refs):
        print(f"  WARNING: {md_path.name} declares {len(refs)} figures but the PDF embeds "
              f"{images} images.", file=sys.stderr)


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        sys.exit(__doc__)
    edge = find_edge()
    files = [Path(f) for arg in argv[1:] for f in glob.glob(arg)]
    if not files:
        sys.exit("No matching .md files.")
    for md in files:
        out = render(md, edge)
        print(f"{md} -> {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main(sys.argv)
