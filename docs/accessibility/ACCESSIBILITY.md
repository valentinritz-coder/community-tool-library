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

## Manual keyboard and screen-reader gate

Issue #28 is not completely validated until a human tester runs this checklist with keyboard-only
navigation and a real screen reader in the browser/assistive-technology combinations supported for
the pilot. Record the environment, scenarios, findings, and fixes when that review is performed.

- [ ] Sign in and create an account: reach every field/action, perceive validation and async results.
- [ ] Create and join a community: perceive progress/results and approve a membership without duplicate actions.
- [ ] Browse and search inventory: follow heading/result reading order and perceive result-count changes.
- [ ] List, edit, and archive an item: operate all controls and perceive field-specific errors and progress.
- [ ] Add/remove availability: operate dates/actions and perceive date errors, progress, and results.
- [ ] Request a booking: operate dates/action and perceive validation, progress, and resulting status.
- [ ] Accept/refuse a request: identify each contextual action and perceive progress and resulting status.
- [ ] Record handover/return: identify each contextual action and perceive progress and resulting status.
- [ ] Upload/review condition evidence: operate file controls and perceive errors, upload progress, and image alternatives.

For every scenario, also check logical focus order, visible focus, absence of traps, focus after DOM
updates, accessible names/states, and mobile zoom/reflow. Automated DOM tests complement but do not
replace this gate.

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
substitute for testing with disabled pilot users. This environment did not provide a real screen
reader, so no manual screen-reader result is claimed. Before considering issue #28 completely
validated, complete and record the checklist above, including file selection and native date controls,
and verify zoom/reflow on representative mobile devices.
