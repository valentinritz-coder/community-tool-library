# Accessibility Baseline

Accessibility is a first-class MVP requirement because the service may be used by older residents and people with limited digital confidence.

## Product principles

- Prefer simple, familiar interaction patterns.
- Mobile-first does not mean tiny controls.
- Avoid requiring installation: the core service must work from a browser link/QR code.
- Use plain French in the product UI; avoid technical marketplace jargon.
- Do not hide essential actions behind gestures or icon-only controls.

## UI baseline

- body text should be comfortably readable and scalable;
- large touch targets with sufficient spacing;
- visible keyboard focus states;
- full keyboard access for core flows;
- accessible names for interactive controls;
- explicit form labels;
- errors associated with the relevant field and explained in plain language;
- do not rely on colour alone for status;
- sufficient contrast;
- zoom/reflow must not break core workflows;
- dates and reservation states must be understandable without interpreting a dense calendar grid.

## Core flows to test manually

At minimum, test these flows using keyboard-only navigation and a screen reader before pilot release:

1. sign in / join a community;
2. browse/search items;
3. open item details;
4. request a reservation;
5. accept/refuse a request;
6. add an item;
7. mark handover/return.

## Older / low-confidence user testing

The pilot should include real users who are not technically confident. Observe completion rather than asking only whether the interface "looks easy".

Measure:

- whether they can complete a task without coaching;
- where they hesitate;
- terminology they misunderstand;
- accidental taps/navigation;
- whether date selection is usable;
- whether account/login steps become a barrier.

## Engineering

Automated accessibility checks are useful but insufficient. Add automated checks to CI/browser tests after the initial app skeleton exists, then pair them with manual testing.

## Issue #28 focused review

The core-flow DOM and interaction structure was reviewed for authentication and community access,
inventory discovery, listing and availability, reservation decisions, handover/return, and condition
evidence. The review found that validation failures were announced only as generic status updates,
client-side errors were not associated with their fields, repeated transaction actions did not include
the item name, search updates could announce the entire result list, and item images preceded their
identifying heading in reading order.

The implementation now uses assertive alerts for failures, associates client validation errors with
invalid fields, gives repeated actions contextual names, announces a concise search-result count, and
puts each item heading before its informative image. Native controls, landmarks, headings, labels,
required attributes, disclosure widgets, and visible focus treatment remain the basis of keyboard and
screen-reader operation rather than custom ARIA widgets.

This was a focused code/DOM review and automated regression pass, not WCAG certification and not a
substitute for testing with disabled pilot users. Before pilot release, complete the keyboard and
screen-reader scenarios above in supported browser/assistive-technology combinations, including file
selection and native date controls, and verify zoom/reflow on representative mobile devices.
