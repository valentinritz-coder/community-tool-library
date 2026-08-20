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
- a system sans-serif stack and a deliberately small type hierarchy: `display` for the hero,
  `section-heading`, `subheading`, `lead`, `body`, and `small`;
- fluid `clamp()` sizing for display, section heading, subheading, lead, and body roles, plus a
  five-step spacing rhythm, readable line lengths, and section/content widths in relative units.

The intended text/control pairs exceed WCAG 2.2 AA: ink on surface is 16.4:1, muted ink on surface
is 7.5:1, blue on surface is 13.7:1, white on blue is 14.6:1, and white on blue-hover is 16.5:1.
Red is an illustrative accent; it is not approved here for normal-size text on the light surface.
The future page should use `.landing-button-primary`, `.landing-link-secondary`, `.landing-section`,
and `.landing-copy`, rather than changing existing global button/link rules.

## Illustration assets

The production asset strategy deliberately combines three raster WebP scenes with seven lightweight
SVG objects. The WebP scenes preserve the validated paper texture, shadows, and detailed rendering;
SVG remains appropriate for the smaller, simpler objects. Consumers must supply each asset's
intrinsic `width` and `height` to preserve its real ratio and prevent layout shift.

| Asset                 | Intended section                                    | Accessibility default                                                                                                                                                     |
| --------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hero-exchange.webp`  | Hero: two hands exchange a drill in a local setting | Meaningful only if adjacent HTML does not already explain sharing; otherwise decorative                                                                                   |
| `handshake.webp`      | Invitation/community trust                          | Decorative when the adjacent heading and copy explain the idea                                                                                                            |
| `council-ballot.webp` | Council election                                    | Meaningful only if the adjacent HTML does not mention members electing a council; otherwise decorative                                                                    |
| `objects/*.svg`       | Breadth of useful shared objects                    | The group may be decorative when adjacent HTML states that varied objects are shared; otherwise give the group one concise description, not seven repetitive alternatives |

For decorative use, render an empty alternative (`alt=""`). For meaningful use, describe the
idea in context (for example, “Deux personnes se transmettent une perceuse”), not colours, texture,
or every decorative detail. Do not use file names as alternatives. The joining steps and
project-holder card remain semantic HTML/CSS; producing images for them would bake content into an
asset and reduce reflow flexibility.

## Responsive and performance strategy

- Hero, handshake, and ballot are visually validated WebP compositions. They may stack before or
  after their related HTML while DOM reading order remains text-first.
- The seven object files are independent so #73 can wrap, reorder visually, or omit purely
  decorative items at narrow widths without cropping a single desktop strip.
- The object SVGs keep edges sharp at zoom and use a compact procedural paper filter without
  external resources or embedded text.
- Images remain responsive with `max-width: 100%` and `height: auto`; consumers must preserve SVG
  `viewBox` values and avoid fixed-height sections or unintended cropping.
- Illustrations remain decorative when adjacent HTML already carries their meaning.
- Essential headings, descriptions, CTA labels, invitation rules, and governance information must
  remain in HTML and must never be conveyed only by an image. No information depends on colour.

This WebP + SVG combination is a deliberate production decision: detailed scenes retain their
paper-cut finish, while simple object artwork stays compact and scalable without adding an image
processing dependency.
