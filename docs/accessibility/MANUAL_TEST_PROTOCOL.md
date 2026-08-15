# Manual Accessibility Test Protocol

## Purpose

This protocol is the human validation gate for issue #28, `[M4] Harden accessibility for core pilot flows`.

Automated tests, lint, typecheck, build and DOM-level accessibility assertions do not replace this protocol. Issue #28 is not completely validated until the mandatory scenarios below have been executed with:

1. keyboard only, without using a mouse or pointing device; and
2. keyboard plus a real screen reader.

For the initial pilot baseline, use NVDA on Windows with a supported Chromium browser unless the pilot defines another supported combination.

## Completion rule

Use one of these results for every scenario:

- `PASS` — the scenario can be completed and the expected accessibility behaviour is present;
- `FAIL` — a material accessibility defect was found;
- `BLOCKED` — the scenario could not be exercised because required data/environment/setup was unavailable;
- `NOT RUN` — the scenario has not yet been executed.

Issue #28 may be considered manually validated only when:

- every mandatory keyboard-only scenario is `PASS`;
- every mandatory NVDA scenario is `PASS`;
- the zoom/reflow checks are `PASS`;
- every material defect found during the run is either fixed and re-tested or explicitly accepted as a documented pilot limitation by the reviewer/product owner.

A green CI run alone is not sufficient to close issue #28.

## Test record

Record the following before starting:

- Date:
- Tester:
- Commit / deployment tested:
- Operating system and version:
- Browser and version:
- NVDA version:
- Viewport/device used for mobile-width checks:
- Notes about environment limitations:

Do not claim a screen-reader pass if NVDA was not actually used.

## Test data and accounts

Use synthetic test data only.

Prepare enough state to exercise the whole lifecycle. The easiest setup is three synthetic users:

- **Admin** — active admin in community `Riverside`;
- **Owner** — active member who owns at least one eligible item, for example `Drill`;
- **Borrower** — active member who does not own that item.

Also prepare or be able to create:

- one pending membership that the Admin can approve;
- one active item with a valid photo;
- at least one availability range covering future dates;
- one second item or search term so both matching and no-result search states can be tested;
- JPEG/PNG/WebP condition photos smaller than 5 MB;
- one deliberately invalid image file such as GIF, or an oversized file if practical;
- a booking lifecycle that can progress through `requested`, `accepted`, `checked_out`, and `returned`.

It is acceptable to sign in and out between roles. If multiple browser profiles are available, they may make the owner/borrower flow easier to exercise, but they are not required.

---

# Pass A — Keyboard only

## Rules for this pass

- Do not use the mouse, trackpad, touchscreen, or another pointing device.
- Use `Tab` to move forward and `Shift+Tab` to move backward.
- Use normal keyboard activation for native controls: `Enter`, `Space`, arrow keys, and browser/native date or file controls as appropriate.
- At every step verify that the currently focused control has a visible focus indication.
- If focus disappears, jumps somewhere illogical, becomes trapped, or a required action cannot be reached, mark the scenario `FAIL`.

### K01 — Sign in and account creation

**Steps**

1. Load the application from a signed-out state.
2. Press `Tab` from the top of the page.
3. Verify the skip link can receive focus and activate it.
4. Return to the sign-in form using normal keyboard navigation.
5. Reach Email address, Password, Sign in, and Create account in logical order.
6. Submit invalid credentials and observe the resulting feedback.
7. Submit valid credentials.
8. If practical, exercise Create account with synthetic credentials or at least verify the control and native validation path are keyboard operable.

**Expected result**

- Skip link is visible when focused and moves focus/navigation to the main content.
- All fields and actions are reachable in a logical order.
- Focus is visibly indicated.
- Native required-field validation is operable from the keyboard.
- Sign-in processing cannot be triggered repeatedly while the same action is pending.
- Success/error feedback is visible without requiring a mouse.

Result: `NOT RUN`

Notes:

### K02 — Create, join and approve community membership

**Steps**

1. As an authenticated user, keyboard-navigate to Create a community.
2. Create a synthetic community or exercise the existing community flow.
3. Keyboard-navigate to Request to join and submit a join code.
4. As an Admin with a pending member available, reach the relevant Approve membership action.
5. Activate it once, then attempt rapid repeated activation while the request is pending.

**Expected result**

- All relevant controls are reachable and focus remains visible.
- The create/join/approve actions cannot accidentally be submitted repeatedly while their own request is pending.
- The interface remains navigable while an unrelated action is pending.
- Resulting status/error feedback is visible.

Result: `NOT RUN`

Notes:

### K03 — Browse and search inventory

**Steps**

1. Navigate to Community inventory.
2. Reach the community selector and search input.
3. Search for a term with at least one matching item.
4. Search for a term with no matches.
5. Clear the search.
6. Continue tabbing through the item cards and their booking controls.

**Expected result**

- Search and community selection are fully keyboard operable.
- The result/no-result states are understandable.
- Tab order follows the visual/semantic order of the controls.
- No item card creates a keyboard trap.

Result: `NOT RUN`

Notes:

### K04 — List, edit and archive an item

**Steps**

1. Navigate through every field of List and manage your items.
2. Switch between Free loan and Price per day with the keyboard.
3. Select Price per day and enter an invalid price.
4. Submit and verify the error state.
5. Correct the price.
6. Exercise the item photo file input and submit a valid item.
7. Open Edit item using the keyboard.
8. Enter an invalid edit price and submit.
9. Exercise an invalid replacement-photo path if practical.
10. Save valid changes.
11. Reach and activate Archive item.

**Expected result**

- Every control is reachable and visibly focused.
- Radio controls are keyboard operable.
- Validation does not force use of the mouse.
- Error recovery is possible without losing the user's place in the workflow.
- Edit disclosure and archive action are keyboard operable.
- Pending actions cannot be duplicated accidentally.

Result: `NOT RUN`

Notes:

### K05 — Availability

**Steps**

1. Navigate to an owned item's Availability section.
2. Enter a start date after the end date and submit.
3. Correct the date range and submit a valid availability.
4. Navigate to an existing range's Remove action and remove it.

**Expected result**

- Native date fields are keyboard operable in the tested browser.
- Invalid ranges produce visible feedback.
- Add and Remove actions are keyboard operable and protected from duplicate activation while pending.

Result: `NOT RUN`

Notes:

### K06 — Booking request

**Steps**

1. As Borrower, navigate to an item that Borrower does not own.
2. Reach the Start date and End date fields.
3. Submit an invalid range.
4. Submit dates outside the configured availability if practical.
5. Submit a valid available range.

**Expected result**

- The complete request can be performed without a pointing device.
- Date errors and unavailable-date feedback are visible.
- The submit action cannot be duplicated while pending.
- The resulting Requested state is visible and understandable.

Result: `NOT RUN`

Notes:

### K07 — Accept / refuse a booking

**Steps**

1. As Owner or eligible Admin, navigate to Reservation decisions.
2. Reach the Accept and Refuse actions for a requested booking.
3. Activate one decision.
4. Verify the controls are not repeatedly activatable while the decision is pending.
5. Repeat with another booking if both Accept and Refuse paths need to be exercised.

**Expected result**

- Decision controls are reachable and visibly focused.
- The item/request context is understandable from the surrounding UI.
- Only the relevant action is disabled while pending.
- Resulting status/error feedback is visible.

Result: `NOT RUN`

Notes:

### K08 — Handover and return

**Steps**

1. Open an accepted booking as Owner or Borrower.
2. Navigate to Mark as handed over and activate it.
3. After authoritative refresh, navigate to Mark as returned and activate it.
4. Navigate to Returned transaction history.

**Expected result**

- Handover and return controls are keyboard operable.
- Duplicate activation is prevented while pending.
- Status transitions are visible.
- The returned transaction remains keyboard-navigable in history.

Result: `NOT RUN`

Notes:

### K09 — Condition evidence

**Steps**

1. On an accepted booking, navigate to the Before condition photo input.
2. Submit without a file or with an invalid file when possible.
3. Correct the error and upload a valid image.
4. After handover, repeat for After condition photo when available.
5. Navigate through the rendered condition evidence.

**Expected result**

- File controls are reachable and operable from the keyboard.
- Validation recovery does not require a mouse.
- Upload cannot be duplicated while pending.
- Before/after evidence is reachable in a logical reading order.

Result: `NOT RUN`

Notes:

---

# Pass B — Keyboard plus NVDA

## Rules for this pass

- Start NVDA before beginning the pass.
- Keep the mouse/trackpad unused.
- Use `Tab` / `Shift+Tab` for the primary interaction flow so the test reflects normal keyboard operation.
- Use NVDA browse/navigation shortcuts only to inspect page structure when useful.
- Do not mark a scenario `PASS` merely because controls are visible. The required labels, names, states and feedback must be perceivable through NVDA.

Useful NVDA checks during the pass include:

- `H` / `Shift+H` to inspect heading structure;
- `F` / `Shift+F` to move through form fields;
- `B` / `Shift+B` to move through buttons;
- `NVDA+F7` to inspect Elements List when useful;
- normal `Tab` navigation to verify actual interaction/focus order.

### N01 — Sign in and account creation

**Steps**

Repeat K01 with NVDA enabled.

**Expected NVDA output/behaviour**

- Email and Password are announced with meaningful labels and control types.
- Required state is perceivable through native semantics.
- Sign in and Create account have clear accessible names.
- Authentication errors are announced as urgent/error feedback rather than silently appearing visually.
- Normal success feedback is announced without masquerading as an error.
- Busy/disabled state is perceivable sufficiently to understand that the current action is being processed.

Result: `NOT RUN`

Notes:

### N02 — Community creation, join and membership approval

**Steps**

Repeat K02 with NVDA enabled.

**Expected NVDA output/behaviour**

- Form fields and action buttons have clear accessible names.
- Processing/result feedback is announced.
- Approval controls are distinguishable from surrounding membership information.
- No status change relies on colour alone.

Result: `NOT RUN`

Notes:

### N03 — Browse and search inventory

**Steps**

1. Navigate through Community inventory with NVDA.
2. Inspect heading order around at least one result card.
3. Perform a search with one or more matches.
4. Perform a search with no matches.

**Expected NVDA output/behaviour**

- Item heading is encountered before its informative image in reading order.
- Item image has meaningful alternative text.
- Search result count changes are announced concisely.
- Updating search does not cause the entire result list to be redundantly re-announced.
- No-result feedback is perceivable.

Result: `NOT RUN`

Notes:

### N04 — List, edit and archive an item

**Steps**

Repeat K04 with NVDA enabled, deliberately triggering price and photo errors.

**Expected NVDA output/behaviour**

- Every input has a meaningful label.
- Free loan / Price per day are announced as related radio controls within Loan terms.
- Invalid price and photo fields are announced as invalid after validation.
- The relevant error message is associated with the invalid field, not only announced as a generic page-level alert.
- Edit item disclosure state is understandable.
- Archive action includes enough context to identify the item when encountered out of surrounding visual context.

Result: `NOT RUN`

Notes:

### N05 — Availability

**Steps**

Repeat K05 with NVDA enabled.

**Expected NVDA output/behaviour**

- Start and End date fields have explicit names.
- Invalid date-range feedback is announced.
- Relevant date fields expose invalid/error association after validation.
- Existing availability and Remove controls are understandable without relying on visual proximity alone.

Result: `NOT RUN`

Notes:

### N06 — Booking request

**Steps**

Repeat K06 with NVDA enabled.

**Expected NVDA output/behaviour**

- Booking Start date and End date are announced correctly.
- Invalid/unavailable ranges produce perceivable error feedback.
- The error relationship to the date fields is perceivable where applicable.
- Successful request/status feedback is announced.

Result: `NOT RUN`

Notes:

### N07 — Accept / refuse

**Steps**

Repeat K07 with NVDA enabled.

**Expected NVDA output/behaviour**

- Repeated decision controls include item context in their accessible names, for example `Accept reservation for Drill` and `Refuse reservation for Drill`.
- Decision processing and resulting state/error are announced.
- A terminal booking no longer presents misleading Accept/Refuse actions.

Result: `NOT RUN`

Notes:

### N08 — Handover and return

**Steps**

Repeat K08 with NVDA enabled.

**Expected NVDA output/behaviour**

- Handover/return buttons include the item name in their accessible name, for example `Mark Drill as handed over`.
- Checked out / Returned status changes are perceivable.
- Returned history is understandable through headings/list structure.

Result: `NOT RUN`

Notes:

### N09 — Condition evidence

**Steps**

Repeat K09 with NVDA enabled.

**Expected NVDA output/behaviour**

- Condition file input identifies Before/After phase and item context through its surrounding labelled form.
- File validation errors are announced and associated with the relevant input.
- Upload progress/result is perceivable.
- Condition images have meaningful alternative text containing phase and item context.
- Before and After evidence remain distinguishable when navigating non-visually.

Result: `NOT RUN`

Notes:

---

# Pass C — Zoom and responsive reflow

These checks do not replace the keyboard/NVDA passes.

### R01 — 200% browser zoom

**Steps**

1. Set browser zoom to 200% on a normal desktop viewport.
2. Visit the sign-in/community flow, inventory/search, item management, booking decisions, and handover/condition areas.
3. Keyboard-navigate representative controls at 200% zoom.

**Expected result**

- No essential control or content becomes unreachable or obscured.
- Text does not overlap in a way that prevents reading or operation.
- Required horizontal scrolling is not introduced for ordinary text/content except where a native control intrinsically requires it.
- Visible focus remains visible.

Result: `NOT RUN`

Notes:

### R02 — Representative narrow/mobile viewport

**Steps**

1. Use a representative narrow viewport or real mobile-sized browser window.
2. Exercise at least sign-in, search, item creation, booking request and one transaction action.
3. Confirm touch-sized controls remain visually usable, then repeat representative navigation with a hardware keyboard if available or desktop responsive mode for focus/reflow inspection.

**Expected result**

- Core workflows remain readable and operable.
- Controls do not overlap or leave the viewport in a way that prevents completion.
- The mobile-first layout remains intact.

Result: `NOT RUN`

Notes:

---

# Findings log

Record every material defect discovered during the protocol.

| ID  | Scenario | Severity | Finding | Fix / decision | Re-test result |
| --- | -------- | -------- | ------- | -------------- | -------------- |
|     |          |          |         |                |                |

Suggested severity:

- **Blocking** — prevents completing a core flow with keyboard/screen reader, creates a keyboard trap, hides essential state/error information, or makes the action ambiguous/unusable non-visually;
- **Major** — flow can technically complete but with substantial accessibility difficulty or misleading feedback;
- **Minor** — accessibility defect with limited impact that does not materially obstruct the pilot flow.

# Final manual gate

Complete after all mandatory scenarios have been executed.

- Keyboard-only pass: `NOT RUN`
- NVDA pass: `NOT RUN`
- Zoom/reflow pass: `NOT RUN`
- Blocking findings remaining: `UNKNOWN`
- Major findings remaining: `UNKNOWN`

Final manual accessibility gate: `PENDING`

Do not change the final gate to `PASS` until the completion rule at the top of this document is satisfied.

---

# Governance-focused protocol (issue #58)

Run this matrix against a freshly reset local Supabase demo using keyboard-only, then Windows NVDA
with Firefox or Chrome. Repeat representative rows at 200% browser zoom and at a 320 CSS-pixel
viewport. For every row record focus order, visible focus, control name/state, status/error
announcement, reflow, and whether the task can be completed without a pointer. Never infer an NVDA
result from an automated semantic test.

|   # | Required state / task          | Expected accessible evidence                                                                                        | Keyboard | NVDA    | 200% / mobile | Notes |
| --: | ------------------------------ | ------------------------------------------------------------------------------------------------------------------- | -------- | ------- | ------------- | ----- |
|   1 | Managed governance             | State, owner and appointed admins are named; owner controls follow logical order.                                   | NOT RUN  | NOT RUN | NOT RUN       |       |
|   2 | Democratic preparation         | Reversible status and 3/5 target are announced without colour dependence.                                           | NOT RUN  | NOT RUN | NOT RUN       |       |
|   3 | Zero candidates                | Candidate minimum and managed authority are perceivable.                                                            | NOT RUN  | NOT RUN | NOT RUN       |       |
|   4 | One candidate                  | Count and two-more-needed blocker are perceivable.                                                                  | NOT RUN  | NOT RUN | NOT RUN       |       |
|   5 | Two candidates                 | Count and one-more-needed blocker are perceivable.                                                                  | NOT RUN  | NOT RUN | NOT RUN       |       |
|   6 | Three or more candidates       | Each identity and readiness status are navigable; no slate language is used.                                        | NOT RUN  | NOT RUN | NOT RUN       |       |
|   7 | Blocked commitment             | Disabled/failed action has a useful programmatic explanation.                                                       | NOT RUN  | NOT RUN | NOT RUN       |       |
|   8 | Irreversible confirmation      | Cancel receives safe initial focus; Tab is contained; Escape cancels; pending state retains focus and is announced. | NOT RUN  | NOT RUN | NOT RUN       |       |
|   9 | Stand / withdraw candidacy     | Buttons have explicit names and resulting status is announced.                                                      | NOT RUN  | NOT RUN | NOT RUN       |       |
|  10 | Voting                         | Candidate choices form one named group and expose checked state.                                                    | NOT RUN  | NOT RUN | NOT RUN       |       |
|  11 | Approval limit                 | Seats/limit instructions and over-selection error identify the candidate group.                                     | NOT RUN  | NOT RUN | NOT RUN       |       |
|  12 | Ballot submitted               | Only “ballot recorded” is announced; selected choices are not replayed.                                             | NOT RUN  | NOT RUN | NOT RUN       |       |
|  13 | Failed quorum                  | Result says transition remains committed and does not imply managed rollback.                                       | NOT RUN  | NOT RUN | NOT RUN       |       |
|  14 | Insufficient winners           | Result explains no council was installed and transition remains committed.                                          | NOT RUN  | NOT RUN | NOT RUN       |       |
|  15 | Runoff                         | Runoff and its limited candidate set/seat count are announced.                                                      | NOT RUN  | NOT RUN | NOT RUN       |       |
|  16 | Operational democratic council | Council members, 3/5 target, vacancies and ordinary authority are understandable.                                   | NOT RUN  | NOT RUN | NOT RUN       |       |
|  17 | Councillor resignation         | Safe initial focus and immediate/vacancy/reconstitution consequences are announced.                                 | NOT RUN  | NOT RUN | NOT RUN       |       |
|  18 | Under-strength council         | “Reconstitution required” and caretaker-only authority are explicit.                                                | NOT RUN  | NOT RUN | NOT RUN       |       |
|  19 | Vacant council                 | Democratic continuity, lack of former-owner fallback and member path are explicit.                                  | NOT RUN  | NOT RUN | NOT RUN       |       |
|  20 | Reconstitution / by-election   | Member can open, stand and vote; exact vacancies/approval limit and restoration status are announced.               | NOT RUN  | NOT RUN | NOT RUN       |       |

## Governance evidence status for issue #58

- Automated component coverage verifies labels/group semantics, status and error live regions,
  safe confirmation focus, Tab containment, pending focus, pending announcement and restoration.
- This environment has no Windows desktop or NVDA installation. Consequently **no manual NVDA,
  keyboard, 200% zoom, or mobile evidence was performed for issue #58**, and every cell above
  intentionally remains `NOT RUN`.
- A human tester on Windows/NVDA must execute and record the matrix before representing the manual
  accessibility gate as passed. Material findings require fixes and a recorded re-test.
