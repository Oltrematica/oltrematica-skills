# EAA / WCAG 2.1 AA Checklist (web products)

Basis for the W4 accessibility module. The EAA (Directive (EU) 2019/882, in
force since 2025-06-28) points to EN 301 549, which for web content maps to
WCAG 2.1 AA. Automated scanning (axe-core) covers ONLY PART of these
criteria — the dossier must always state this explicitly and list the manual
items as open until a human completes them.

## Automated — covered by axe-core (a11y_scan.sh)

| Criterion | What axe checks |
|-----------|-----------------|
| 1.1.1 Non-text content | images/inputs missing alternative text |
| 1.3.1 Info and relationships | form labels, table headers, ARIA roles/attributes validity |
| 1.4.3 Contrast (minimum) | text contrast ratios |
| 2.4.2 Page titled | missing/empty `<title>` |
| 3.1.1 Language of page | missing/invalid `lang` attribute |
| 3.1.2 Language of parts | invalid `lang` on elements |
| 4.1.2 Name, role, value | ARIA name/role/value on UI components |

Passing axe = no violations *detected*; it is NOT WCAG conformance.

## Manual verification required (never claimed automatically)

| Criterion | What a human must check |
|-----------|--------------------------|
| 1.2.x Time-based media | captions, audio description on video/audio |
| 1.3.2 Meaningful sequence | reading order with CSS off / screen reader |
| 1.4.5 Images of text | text rendered as images without need |
| 1.4.10 Reflow | usable at 320px width / 400% zoom |
| 1.4.11 Non-text contrast | UI component and graphic contrast |
| 2.1.1 / 2.1.2 Keyboard | full operation by keyboard, no traps |
| 2.4.3 Focus order | logical tab order |
| 2.4.6 Headings and labels | descriptive, not just present |
| 2.4.7 Focus visible | visible focus indicator throughout |
| 2.5.x Input modalities | pointer gestures, target size behaviour |
| 3.2.1 / 3.2.2 On focus / on input | no unexpected context changes |
| 3.3.1–3.3.4 Input assistance | error identification, suggestions, prevention |

## Output rule for W4

For each scanned route the dossier gets: axe violation count + top findings
(criterion, element, suggested fix) AND the manual table above with per-item
status `not yet verified` until a named human marks otherwise.
