# Design preview resources

These resources are bundled locally so the design preview needs no backend or network at runtime.

## Fonts

Source: https://github.com/google/fonts

- IBM Plex Sans KR: `ofl/ibmplexsanskr`, regular / medium / semibold / bold.
- Gowun Batang: `ofl/gowunbatang`, regular / bold.
- IBM Plex Mono: `ofl/ibmplexmono`, medium.
- SIL Open Font License 1.1. Each family's original OFL is preserved under `fonts/`.

## Icons

Source: https://github.com/lucide-icons/lucide/tree/main/icons

Actual Lucide SVG assets, used through flutter_svg. ISC license; the original notice is preserved at `icons/LICENSE`. Line icons consistently serve navigation, book capture, dates and event types.

## Book covers

Source: public Aladin book detail pages, identified by ISBN or product ID. The exact source page, cover URL, book title and ISBN for each local image are recorded in `covers/sources.json`.

The cover artwork remains copyrighted by its respective rights holders. These local copies are design review references, not a newly licensed illustration collection. No image generation was used. Production distribution of cover assets should follow the selected book data provider's terms.

## App-native visual elements

Shelf spines, colored reason bands, card index tab, date stamp, ruled paper and the C hero's stair motif are Flutter layout and painting, keeping them crisp at simulator resolution. Spines do not invent cover-derived spine images. Sample notes and questions are authored preview content.
