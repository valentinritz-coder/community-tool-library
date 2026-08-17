# Landing visual foundations

This document is the production hand-off for issue #72. It deliberately does not define the
landing structure, copy, routes, or application behaviour; issue #73 owns page implementation.

## Styling contract

`src/app/landing-foundations.css` is scoped behind `.landing` so authenticated screens retain their
current styles. It provides only the primitives needed by the public page:

- off-white `surface` (`#fffdf8`) and warm paper (`#f6f0e6`);
- near-black `ink` (`#171b26`) and muted ink (`#4d5361`);
- deep functional blue (`#092a67`) with a darker hover state (`#061f4e`);
- restrained brand red (`#c83737`), not an error/success/status colour;
- amber focus (`#f2b705`) with a dark keyline so focus remains a shape, not colour alone;
- a system sans-serif stack, fluid body/lead/heading sizes, a five-step spacing rhythm, readable
  line lengths, and section/content widths expressed in relative units.

The intended text/control pairs exceed WCAG 2.2 AA: ink on surface is 16.4:1, muted ink on surface
is 7.5:1, blue on surface is 13.7:1, white on blue is 14.6:1, and white on blue-hover is 16.5:1.
Red is an illustrative accent; it is not approved here for normal-size text on the light surface.
The future page should use `.landing-button-primary`, `.landing-link-secondary`, `.landing-section`,
and `.landing-copy`, rather than changing existing global button/link rules.

## Illustration assets

All files in `public/illustrations/landing/` are lightweight, responsive SVGs with a `viewBox` and
no embedded text, scripts, external resources, or interaction. Flat layered shapes, a very subtle
SVG noise texture, and one shared shadow treatment form the cut-paper language. They can be loaded
through `next/image` or an ordinary `img`; intrinsic `width`/`height` should be supplied by the
consumer to prevent layout shift.

| Asset                | Intended section                                    | Accessibility default                                                                                                                                                     |
| -------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hero-exchange.svg`  | Hero: two hands exchange a drill in a local setting | Meaningful only if adjacent HTML does not already explain sharing; otherwise decorative                                                                                   |
| `handshake.svg`      | Invitation/community trust                          | Decorative when the adjacent heading and copy explain the idea                                                                                                            |
| `council-ballot.svg` | Council election                                    | Meaningful only if the adjacent HTML does not mention members electing a council; otherwise decorative                                                                    |
| `objects/*.svg`      | Breadth of useful shared objects                    | The group may be decorative when adjacent HTML states that varied objects are shared; otherwise give the group one concise description, not seven repetitive alternatives |

For decorative use, render an empty alternative (`alt=""`). For meaningful use, describe the
idea in context (for example, “Deux personnes se transmettent une perceuse”), not colours, texture,
or every decorative detail. Do not use file names as alternatives. The joining steps and
project-holder card remain semantic HTML/CSS; producing images for them would bake content into an
asset and reduce reflow flexibility.

## Responsive and performance strategy

- Hero, handshake, and ballot scenes are independent compositions and may stack before or after
  their related HTML while DOM reading order remains text-first.
- The seven object files are independent so #73 can wrap, reorder visually, or omit purely
  decorative items at narrow widths without cropping a single desktop strip.
- SVG keeps edges sharp at zoom and avoids desktop/mobile raster variants. Decorative texture is
  generated in the file rather than shipped as another bitmap request.
- Consumers must preserve each `viewBox`, use `height: auto`, and avoid fixed-height sections.
- Essential headings, descriptions, CTA labels, invitation rules, and governance meaning remain
  HTML. No information depends on blue/red or on an illustration.

These vectors are the maintainable in-repository interpretation of the approved paper-cut
direction, not copies of the raster mockups. If future art direction requires the mockups' highly
realistic fibrous paper, the recommended production path is an illustrator-authored vector master
with an optimized WebP/AVIF texture fallback, reviewed for visual consistency and payload before
replacement. Issue #72 does not add a large raster texture or a new image dependency.
