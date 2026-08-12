# Minimal pilot metrics specification

> Issue #31 definitions. Metrics are operator-side aggregates over existing business tables, not a
> user dashboard or a compliance claim. Unless stated otherwise, use a half-open UTC reporting window
> `[window_start, window_end)` and scope every query to one pilot `community_id`.

Run the current aggregate template with a read-only/operator database connection after reviewing its
scope: `psql "$OPERATOR_DATABASE_URL" -v community_id='<uuid>' -v window_start='2026-08-01' -v window_end='2026-09-01' -f scripts/pilot-metrics.sql`.
Do not export row-level UUIDs or emails when counts answer the question.

## Metric inventory

Each entry states the product question; exact definition; numerator/denominator; window; source and
current calculation; interpretation limits; and minimum missing data.

### Active members

- **Question:** How large is the community currently able to participate?
- **Definition/calculation:** count distinct `memberships.user_id` whose status is `active` at report
  execution; numerator is that count, denominator none; snapshot at `window_end` (execute then).
  Source: `memberships`. The supplied SQL calculates it today.
- **Limits/missing:** this is authorization status, not observed activity, and membership lacks status
  history. Historical or “used the service” activity would require a minimized status/event definition.

### Listings

- **Question:** How much eligible inventory was added?
- **Definition/calculation:** count `items` created in the window that are published
  (`photo_uploaded`), not archived, and not moderation-hidden at report time; numerator that count,
  denominator none. Source: `items`; supplied SQL calculates it.
- **Limits/missing:** later archive/hide changes historical results and there is no publication-time
  event. This measures current eligible rows created in-window, not inventory-days.

### Searches

- **Question:** How often do members deliberately look for items by name/category?
- **Definition/calculation:** intended numerator is explicit search/filter submissions in the window;
  denominator none. The current UI exposes inventory browsing but has no implemented explicit search
  action or persisted search event, so this is **not calculable today** and the SQL returns `NULL`.
- **Limits/missing:** page views are not a defensible proxy. Minimum future collection, only with a
  dedicated issue/privacy review, is one row or daily aggregate containing community, UTC time, and
  result count—no query text, email, IP, user-agent, fingerprint, or general clickstream.

### Useful-result searches

- **Question:** What share of deliberate searches finds at least one eligible listing?
- **Definition/calculation:** intended numerator is searches in the window whose server-filtered result
  count is greater than zero; denominator is all searches in the same window/community. Report count
  and ratio. It is **not calculable today**; supplied SQL returns `NULL` for both.
- **Limits/missing:** “eligible” must mean the results authorized and visible when search ran, not a
  later inventory snapshot. It requires the same minimal search record/aggregate and result count;
  query text and member identity are unnecessary.

### Booking requests

- **Question:** How much borrowing intent becomes a request?
- **Definition/calculation:** count all `bookings.created_at` in the window for community items,
  regardless of later status; numerator that count, denominator none. Source: `bookings` joined to
  `items`; supplied SQL calculates it today.
- **Limits/missing:** multiple requests by one borrower and refused requests all count; deleted/cascade
  rows disappear, and no immutable event log exists.

### Accepted bookings

- **Question:** What share of requests has reached owner acceptance by reporting time?
- **Definition/calculation:** numerator is in-window booking requests currently in `accepted`,
  `checked_out`, or `returned`; denominator is all booking requests created in the same window. Source:
  `bookings`; supplied SQL reports count and ratio today.
- **Limits/missing:** status is current and there is no acceptance timestamp, so time-to-decision and
  “accepted during window” are unavailable. Refused is terminal; later lifecycle states retain acceptance.

### Completed exchanges

- **Question:** How many requests produced a recorded handover and return?
- **Definition/calculation:** numerator is in-window booking requests whose current status is
  `returned`; denominator is all requests created in that same window. Source: `bookings`; supplied SQL
  reports count and ratio today.
- **Limits/missing:** this cohorts by request creation, so exchanges completed later remain absent until
  a later report; there is no return timestamp. A completion-period metric would minimally need one.

### Repeat owners

- **Question:** Are owners contributing inventory repeatedly?
- **Definition/calculation:** count owners with at least two published, unarchived, non-hidden listings
  created in the window/community; numerator is qualifying distinct owners, denominator is distinct
  owners with at least one such listing. Source: `items`; supplied SQL reports count and share today.
- **Limits/missing:** two listings are not two exchanges, and later row state changes results. No extra
  data is required for this explicit listing-based definition.

### Repeat borrowers

- **Question:** Are borrowers requesting equipment repeatedly?
- **Definition/calculation:** count borrowers with at least two booking requests created in the window;
  numerator qualifying distinct borrowers, denominator distinct borrowers with at least one request.
  Source: `bookings` and `items`; supplied SQL reports count and share today.
- **Limits/missing:** it measures repeated intent, not successful borrowing; no additional data is
  required. For repeated completed exchanges, a return timestamp would be needed for completion windows.

### Incidents

- **Question:** How many product-recorded situations required moderation attention?
- **Definition/calculation:** count `moderation_reports.created_at` in the window (open and handled);
  numerator that count, denominator is booking requests in the same window for an optional
  reports-per-request context ratio. Source: `moderation_reports`; supplied SQL calculates both today.
- **Limits/missing:** a report is an allegation/queue item, not a verified incident. Cancellation and
  dispute/non-return/damage are not structured statuses/reasons today and must not be inferred from
  free-text notes. Adding those categories needs a dedicated product/legal issue, not generic telemetry.

## Privacy and interpretation

Compute aggregates directly from operational tables. Restrict the database connection and output to
authorized operators, apply small-cell handling agreed for the real pilot, and retain only approved
aggregate reports. Do not collect search text or add identity, IP, user-agent, geolocation, cross-session
tracking, or a third-party analytics product for these definitions. Search gaps are explicit rather
than silently replaced with invasive or misleading proxies.
