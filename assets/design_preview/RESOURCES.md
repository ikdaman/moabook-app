# Design preview resources

These resources are bundled locally so the design preview needs no backend or network at runtime.

## Fonts

Source: https://github.com/google/fonts

- IBM Plex Sans KR: `ofl/ibmplexsanskr`, regular / medium / semibold / bold.
- Gowun Batang: `ofl/gowunbatang`, regular / bold.
- IBM Plex Mono: `ofl/ibmplexmono`, medium.
- SIL Open Font License 1.1. Each family's original OFL is preserved under `fonts/`.

## Icons

Source: https://github.com/phosphor-icons/core

Phosphor bold SVGs replace the former Lucide set. Navigation uses `books` for the basic shelf and `squares-four` for collections, with filled variants for active tabs. Book reading uses `book-open-text`, notes use `pencil-simple-line`, gallery uses `images-square`, and capture uses `barcode`. All 32 icon slots keep their existing actions and labels. Two active-tab assets bring the set to 34 SVGs.

The exact upstream revision, icon-name mappings and source URLs are recorded in `icons/sources.json`. MIT license; the original notice is preserved at `icons/LICENSE`. Assets are bundled locally and retain vector rendering.

## Book covers

Source: public Aladin book detail pages, identified by ISBN or product ID. The exact source page, cover URL, book title and ISBN for each local image are recorded in `covers/sources.json`.

The cover artwork remains copyrighted by its respective rights holders. These local copies are design review references, not a newly licensed illustration collection. No image generation was used. Production distribution of cover assets should follow the selected book data provider's terms.

## Reference SVG assets

Source: https://claude.ai/artifact/VSoiFpSiJDf4JayX2CBpLa (모아북 무드 비교, inspected 2026-10-12).

The 12 authored SVGs are preserved under `reference/`: A stamp, ruled paper, index tab, reason bands, cover/shadow and spines; C stairs, dots, reason bands, chips, record button and spines. `a-stamp-outline.svg` is derived from the original with SVG text removed and the card-colored background restored so Flutter can overlay bundled-font text. C stairs use the original polygon directly. Dynamic reason bands, vertical titles, repeated paper rules, tabs, shadows and labels use Flutter layout/painting with the reference colors and dimensions. No generated bitmap substitutes are used.

The HTML design guide retains the original specifications and SVG previews while its ten phone examples come from the latest simulator capture manifest. Its fonts are bundled locally with their OFL notices.
