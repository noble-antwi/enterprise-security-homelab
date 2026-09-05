# Biira Bank brand

The identity shared by both lab repositories: `enterprise-security-homelab` (infrastructure and network security) and `enterprise-iam-lab` (identity and access). One organisation, one mark, so a reader moving between them knows they are looking at the same environment.

Every asset in this directory is **generated**. Do not edit the SVGs by hand. Change the source and rebuild:

```bash
python scripts/brand/build_brand.py
```

---

## The mark

A vault door inside a shield. The shield is the protected boundary; the vault door is the controlled way through it. That reads for network segmentation in this repository and for authentication and authorisation in the IAM repository, which is why one mark serves both.

![Biira Bank lockup](biira-bank-lockup-960.png)

---

## Colours

| Token | Hex | Use |
|-------|-----|-----|
| Navy | `#08152F` | Shield field, headings, table header fill, bold text |
| Navy mid | `#1B2F5E` | Subheadings, the shield field on dark backgrounds |
| Cyan | `#2DD4E8` | Accent only: rules, the vault ring, bars, masthead |
| Cyan light | `#7FE9F5` | The hub, and highlights on dark grounds |
| Cyan ink | `#0E7490` | Cyan-toned text that must be read on white |
| Tint | `#ECF6F9` | Code backgrounds, alternating table rows |

**Cyan is never body text on white.** At `#2DD4E8` it scores about 1.7:1 against white, where 4.5:1 is the minimum for readable text. Anything cyan-toned that has to be read on a light ground uses **Cyan ink** `#0E7490` instead, which clears WCAG AA at 4.9:1. Cyan is free to be as bright as it likes when it is a rule, a ring or a bar, because nobody has to read it.

Every text and background pair in the documents clears AA at body size. That also keeps them legible printed in greyscale, which is how audit evidence tends to get read.

---

## Which file to use

| Situation | Asset |
|-----------|-------|
| Anywhere vector works | `biira-bank-mark.svg` |
| 64px and above, raster | `biira-bank-mark-{512,256,128,64}.png` |
| **48px and below** | `biira-bank-mark-compact-{48,32}.png` |
| Browser tab, OS icon | `favicon.ico` (16 to 256px) |
| Beside the name, horizontal | `biira-bank-lockup.svg` |
| Stacked, for square spaces | `biira-bank-lockup-stacked.svg` |
| On a dark background | any `*-reverse` variant |
| One colour, print or stamp | `biira-bank-mark-mono-navy.svg` |

### Why there are two versions of the mark

The vault's eight spokes and the inner shield rule are the first details to collapse as the mark shrinks. Below roughly 48px they stop reading as spokes and become a grey smudge, which looks like a rendering fault rather than a logo.

The **compact** variant removes them and thickens the ring and hub, holding the same silhouette with fewer parts. This is ordinary practice, not a compromise: it is why the favicon is built from the compact mark rather than by shrinking the full one.

Use the full mark at 64px and above. Use compact at 48px and below.

### Why there are reverse variants

On a dark ground the deep navy field disappears into the background and the mark reads as a floating cyan ring. The reverse variants use the lighter navy `#1B2F5E` for the field so the shield stays legible as a shape.

---

## Clear space and minimum size

Leave clear space around the mark equal to **half the shield's width** on every side. Nothing else sits inside that.

Minimum sizes: **16px** for the compact mark, **20mm** wide for the lockup in print. Below that the wordmark's letterspacing closes up and the sub-line becomes unreadable.

---

## Do not

- Recolour the mark outside the palette above
- Stretch it, or set it at an angle
- Add a drop shadow, glow or bevel, all of which fail in print and at small sizes
- Put the light mark on a dark ground, or the reverse mark on a light one
- Shrink the full mark below 48px instead of switching to compact
- Use cyan for text on white

---

## A note on the lockups

The wordmark in the lockup SVGs is **live text**, not outlined paths, so it renders with whatever font the viewing system resolves from `Segoe UI, Helvetica Neue, Arial, sans-serif`. On another machine it may set slightly differently.

The rasterised PNGs are the portable form. Use those anywhere the exact letterforms matter, and use the SVG where the environment is known. Outlining the text would fix this properly and is worth doing if the identity is ever used outside these repositories.
