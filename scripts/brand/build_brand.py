"""
Build the Biira Bank brand assets from a single source of truth.

Usage (from the repo root):
    python scripts/brand/build_brand.py

Writes SVG masters and rasterised PNGs into images/brand/, plus a favicon.
Every asset is generated, so changing a colour here changes it everywhere.

Requires PyMuPDF (rasterising) and Pillow (favicon assembly).
"""
from __future__ import annotations

import math
import pathlib

import fitz
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "images" / "brand"

# ---------------------------------------------------------------- palette --
# Colourway "Signal Cyan". Cyan is an accent, not a text colour: at #2DD4E8 it
# scores about 1.7:1 on white, so anything that must be read on a light ground
# uses CYAN_INK instead, which clears WCAG AA.
NAVY = "#08152F"   # deep field, headings, table fill
NAVY_MID = "#1B2F5E"   # field highlight, subheadings
CYAN = "#2DD4E8"   # accent: rules, ring, bars. Never body text on white.
CYAN_LIGHT = "#7FE9F5"   # hub, highlights on dark
CYAN_INK = "#0E7490"   # readable cyan-tone on white (4.9:1)
PAPER = "#FFFFFF"

SHIELD = ("M12 20C12 14 16 10 22 10h76c6 0 10 4 10 10v54"
          "c0 29-20 48-48 58C32 122 12 103 12 74Z")
INNER = ("M20.5 24c0-4 2.6-6.6 6.6-6.6h65.8c4 0 6.6 2.6 6.6 6.6v49"
         "c0 24.5-17 40.5-39.5 49.5C37.5 113.5 20.5 97.5 20.5 73Z")


def _spokes(cx: float, cy: float, r0: float, r1: float, n: int, w: float, colour: str) -> str:
    parts = []
    for i in range(n):
        a = math.radians(i * 360 / n + 22.5)
        parts.append(
            f'<line x1="{cx + r0 * math.cos(a):.2f}" y1="{cy + r0 * math.sin(a):.2f}" '
            f'x2="{cx + r1 * math.cos(a):.2f}" y2="{cy + r1 * math.sin(a):.2f}" '
            f'stroke="{colour}" stroke-width="{w}" stroke-linecap="round"/>')
    return "".join(parts)


def _field(on_dark: bool = False) -> str:
    """Flat fill, deliberately. A gradient would tie the mark to renderers that
    support one: MuPDF fills `url(#id)` with solid black, and the same applies to
    embroidery, single-colour print and most favicon pipelines. Flat colour also
    keeps the mark honest at 16px, where a gradient contributes nothing.

    On a dark ground the deep navy field would vanish into the background, so the
    reverse variant uses the lighter navy and keeps the shield legible as a shape."""
    return f'<path fill="{NAVY_MID if on_dark else NAVY}" d="{SHIELD}"/>'


def mark_full(on_dark: bool = False) -> str:
    """Primary mark. The vault door reads properly at 64px and above."""
    return (f'{_field(on_dark)}'
            f'<path fill="none" stroke="{CYAN}" stroke-width="3.4" d="{INNER}"/>'
            f'<circle cx="60" cy="66" r="23" fill="none" stroke="{CYAN}" stroke-width="3.4"/>'
            f'{_spokes(60, 66, 11.5, 19.5, 8, 3.2, CYAN)}'
            f'<circle cx="60" cy="66" r="7" fill="{CYAN_LIGHT}"/>')


def mark_compact(on_dark: bool = False) -> str:
    """Small-size mark. The spokes and the inner rule are the first things to
    collapse below about 48px, so they are removed rather than allowed to turn
    into a smudge. Ring and hub are thickened to hold the same silhouette."""
    return (f'{_field(on_dark)}'
            f'<circle cx="60" cy="66" r="24" fill="none" stroke="{CYAN}" stroke-width="6.5"/>'
            f'<circle cx="60" cy="66" r="9.5" fill="{CYAN}"/>')


def mark_mono(colour: str) -> str:
    """One colour, for greyscale print, stamps and embroidery."""
    return (f'<path fill="{colour}" d="{SHIELD}"/>'
            f'<circle cx="60" cy="66" r="23" fill="none" stroke="{PAPER}" stroke-width="3.6"/>'
            f'{_spokes(60, 66, 11.5, 19.5, 8, 3.4, PAPER)}'
            f'<circle cx="60" cy="66" r="7" fill="{PAPER}"/>')


def svg(body: str, w: float, h: float, extra: str = "") -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:g} {h:g}" '
            f'role="img" aria-label="Biira Bank"{extra}>'
            f'<title>Biira Bank</title>{body}</svg>')


FONT = "'Segoe UI', 'Helvetica Neue', Arial, sans-serif"


def lockup(word: str, sub: str | None, on_dark: bool = False) -> str:
    """Horizontal lockup. Text is live rather than outlined, so it depends on the
    rendering system's fonts. The rasterised PNGs are the portable form."""
    wordfill = PAPER if on_dark else NAVY
    subfill = CYAN if on_dark else CYAN_INK
    body = [f'<g transform="translate(0,0) scale(0.72)">{mark_full(on_dark)}</g>']
    y = 56 if sub else 66
    body.append(f'<text x="106" y="{y}" font-family="{FONT}" font-size="34" font-weight="700" '
                f'letter-spacing="3.2" fill="{wordfill}">{word}</text>')
    if sub:
        body.append(f'<text x="108" y="80" font-family="{FONT}" font-size="12.5" font-weight="600" '
                    f'letter-spacing="4.4" fill="{subfill}">{sub}</text>')
    return svg("".join(body), 470, 102)


def lockup_stacked(word: str, sub: str) -> str:
    body = [f'<g transform="translate(95,0) scale(0.86)">{mark_full()}</g>',
            f'<text x="145" y="168" text-anchor="middle" font-family="{FONT}" font-size="31" '
            f'font-weight="700" letter-spacing="3" fill="{NAVY}">{word}</text>',
            f'<text x="146" y="190" text-anchor="middle" font-family="{FONT}" font-size="11.5" '
            f'font-weight="600" letter-spacing="4" fill="{CYAN_INK}">{sub}</text>']
    return svg("".join(body), 290, 205)


def rasterise(svg_path: pathlib.Path, png_path: pathlib.Path, width: int) -> None:
    doc = fitz.open(svg_path)
    page = doc[0]
    zoom = width / page.rect.width
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=True)
    pix.save(png_path)
    doc.close()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    masters = {
        "biira-bank-mark.svg": svg(mark_full(), 120, 140),
        "biira-bank-mark-compact.svg": svg(mark_compact(), 120, 140),
        "biira-bank-mark-reverse.svg": svg(mark_full(on_dark=True), 120, 140),
        "biira-bank-mark-compact-reverse.svg": svg(mark_compact(on_dark=True), 120, 140),
        "biira-bank-mark-mono-navy.svg": svg(mark_mono(NAVY), 120, 140),
        "biira-bank-lockup.svg": lockup("BIIRA BANK", "SECURITY ENGINEERING"),
        "biira-bank-lockup-reverse.svg": lockup("BIIRA BANK", "SECURITY ENGINEERING", on_dark=True),
        "biira-bank-lockup-stacked.svg": lockup_stacked("BIIRA BANK", "SECURITY ENGINEERING"),
    }
    for name, content in masters.items():
        (OUT / name).write_text(content + "\n", encoding="utf-8")
        print(f"  svg  {name}")

    raster = [
        ("biira-bank-mark.svg", "biira-bank-mark-512.png", 512),
        ("biira-bank-mark.svg", "biira-bank-mark-256.png", 256),
        ("biira-bank-mark.svg", "biira-bank-mark-128.png", 128),
        ("biira-bank-mark.svg", "biira-bank-mark-64.png", 64),
        ("biira-bank-mark-reverse.svg", "biira-bank-mark-reverse-256.png", 256),
        ("biira-bank-mark-compact.svg", "biira-bank-mark-compact-48.png", 48),
        ("biira-bank-mark-compact.svg", "biira-bank-mark-compact-32.png", 32),
        ("biira-bank-mark-compact-reverse.svg", "biira-bank-mark-compact-reverse-48.png", 48),
        ("biira-bank-mark-compact-reverse.svg", "biira-bank-mark-compact-reverse-32.png", 32),
        ("biira-bank-lockup.svg", "biira-bank-lockup-960.png", 960),
        ("biira-bank-lockup-reverse.svg", "biira-bank-lockup-reverse-960.png", 960),
        ("biira-bank-lockup-stacked.svg", "biira-bank-lockup-stacked-600.png", 600),
    ]
    for src, dst, w in raster:
        rasterise(OUT / src, OUT / dst, w)
        print(f"  png  {dst}")

    # Favicon: the compact mark at every size a browser or OS asks for.
    ico_src = OUT / "biira-bank-mark-compact.svg"
    tmp = OUT / "_favicon-256.png"
    rasterise(ico_src, tmp, 256)
    base = Image.open(tmp).convert("RGBA")
    base.save(OUT / "favicon.ico",
              sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    tmp.unlink()
    print("  ico  favicon.ico")

    build_web_icons()

def build_web_icons() -> None:
    """Favicons and app icons for a website.

    Three things differ from the plain PNGs and are the usual cause of icons
    that look broken once deployed:

    * iOS ignores transparency on the touch icon and composites it onto black,
      so these are drawn on an opaque navy square.
    * Android maskable icons are cropped to a circle or squircle by the
      launcher. Anything outside the central 80% can be cut, so the mark is
      inset to roughly 60% of the canvas.
    * The compact mark is used below 96px, for the same reason the favicon is.
    """
    web = OUT / "web"
    web.mkdir(exist_ok=True)

    def canvas(size: int, mark_svg: str, scale: float, opaque: bool) -> Image.Image:
        tmp = web / "_tmp.png"
        rasterise(OUT / mark_svg, tmp, max(8, int(size * scale)))
        mark = Image.open(tmp).convert("RGBA")
        tmp.unlink()
        # Fit by height: the shield is taller than it is wide.
        h = max(8, int(size * scale))
        mark = mark.resize((max(1, int(h * mark.width / mark.height)), h), Image.LANCZOS)
        bg = (8, 21, 47, 255) if opaque else (0, 0, 0, 0)
        img = Image.new("RGBA", (size, size), bg)
        img.alpha_composite(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
        return img

    # Transparent favicons, drawn edge to edge.
    for size in (16, 32, 48, 96):
        src = "biira-bank-mark-compact.svg" if size < 96 else "biira-bank-mark.svg"
        canvas(size, src, 1.0, opaque=False).save(web / f"favicon-{size}x{size}.png")

    # SVG favicon: modern browsers prefer it and it stays sharp at any density.
    (web / "favicon.svg").write_text(
        (OUT / "biira-bank-mark-compact.svg").read_text(encoding="utf-8"), encoding="utf-8")

    # The opaque icons use the REVERSE mark. On the navy tile the deep-navy
    # field is invisible and only the cyan outline survives, which reads as a
    # broken icon rather than a logo.
    # iOS: opaque, and Apple applies its own rounding.
    canvas(180, "biira-bank-mark-reverse.svg", 0.74, opaque=True).save(
        web / "apple-touch-icon.png")

    # Android/PWA: maskable, so the mark sits inside the safe area.
    for size in (192, 512):
        canvas(size, "biira-bank-mark-reverse.svg", 0.60, opaque=True).save(
            web / f"web-app-manifest-{size}x{size}.png")

    (OUT / "favicon.ico").replace(web / "favicon.ico")

    (web / "site.webmanifest").write_text("""{
  "name": "Biira Bank Security Lab",
  "short_name": "Biira Bank",
  "icons": [
    { "src": "/web-app-manifest-192x192.png", "sizes": "192x192",
      "type": "image/png", "purpose": "maskable" },
    { "src": "/web-app-manifest-512x512.png", "sizes": "512x512",
      "type": "image/png", "purpose": "maskable" }
  ],
  "theme_color": "#08152F",
  "background_color": "#08152F",
  "display": "standalone"
}
""", encoding="utf-8")

    (web / "head-snippet.html").write_text("""<!-- Paste into <head>. Adjust the paths if the icons are not served from the site root. -->
<link rel="icon" type="image/png" href="/favicon-96x96.png" sizes="96x96">
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<link rel="shortcut icon" href="/favicon.ico">
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<meta name="apple-mobile-web-app-title" content="Biira Bank">
<link rel="manifest" href="/site.webmanifest">
<meta name="theme-color" content="#08152F">
""", encoding="utf-8")

    print("  web  favicon set (10 files) in images/brand/web/")


if __name__ == "__main__":
    main()
