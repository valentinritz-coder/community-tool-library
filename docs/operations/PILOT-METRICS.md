# Minimal pilot metrics specification

> Issue #31 definitions. Metrics are operator-side aggregates over existing business tables, not a
> user dashboard or a compliance claim. Unless stated otherwise, use a half-open UTC reporting window
> `[window_start, window_end)` and scope every query to one pilot `community_id`.

Run the current aggregate template with the PostgreSQL `psql` client and a read-only/operator database
connection after reviewing its scope:
`psql "$OPERATOR_DATABASE_URL" -v community_id='<uuid>' -v window_start='2026-08-01T00:00:00Z' -v window_end='2026-09-01T00:00:00Z' -f scripts/pilot-metrics.sql`.
`OPERATOR_DATABASE_URL` is a secret, server/operator-only connection string supplied temporarily to the
authorized operator shell or approved secret mechanism; never store it in the repository, expose it to
the frontend, or configure it as `NEXT_PUBLIC_*`.
Do not export row-level UUIDs or emails when counts answer the question.

## Metric inventory

Each entry states the product question; exact definition; numerator/denominator; window; source and
current calculation; interpretation limits; and minimum missing data.

### Active members

- **Question:** How large is the community currently able to participate?
- **Definition/calculation:** count distinct `memberships.user_id` whose status is `active` at report
  execution; numerator is that count and denominator none. This is strictly a current snapshot when the
  query runs; the reporting window does not alter it.
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

- **Question:** Are owners participating repeatedly in actual completed circulation?
- **Definition/calculation:** among the cohort of community bookings created in the UTC window and
  currently `returned`, count owners attached through `bookings.item_id -> items.owner_id` who have at
  least two such completed exchanges. The numerator is qualifying distinct owners; the denominator is
  distinct owners with at least one returned booking in that same creation cohort. Source: `bookings`
  joined to `items`; supplied SQL reports the count and share today.
- **Limits/missing:** `bookings` has no `returned_at`, so this does **not** mean “returned during the
  window.” It is a request-created-in-window cohort evaluated using current status; results can change
  when a cohort booking is later returned. A completion-period metric requires a future return timestamp,
  which #31 does not add.

### Repeat borrowers

- **Question:** Are borrowers participating repeatedly in actual completed circulation?
- **Definition/calculation:** among community bookings created in the UTC window and currently
  `returned`, count borrowers with at least two such completed exchanges. The numerator is qualifying
  distinct borrowers; the denominator is distinct borrowers with at least one returned booking in that
  creation cohort. Source: `bookings` joined to `items`; supplied SQL reports count and share today.
- **Limits/missing:** there is no `returned_at`, so this is not a count of returns occurring in the
  window. It is a request-created-in-window cohort evaluated at query time and can change later. A true
  completion-period definition needs a future return timestamp; no new tracking is added by #31.

### Incidents

- **Question:** How many cancellations, disputes, non-returns, or damage incidents occurred?
- **Definition/calculation:** numerator and denominator are **not currently calculable**. The current
  model does not persist all required categories as structured incident facts, so the supplied SQL
  returns `NULL`.
- **Limits/missing:** moderation notes must not be interpreted as verified incidents. Minimal missing
  data would be reviewed, structured lifecycle/incident categories and occurrence times, but adding a
  taxonomy or workflow is outside #31.

### Moderation reports (additional operational metric)

- **Question:** How many allegations entered the community moderation queue?
- **Definition/calculation:** count reports whose `moderation_reports.created_at` is in the UTC window;
  numerator is that count and denominator none. Source: `moderation_reports`; supplied SQL calculates it.
- **Limits/missing:** this is queue workload, not verified incident prevalence. One underlying situation
  may produce multiple reports, and the count includes both open and subsequently handled rows.

## Privacy and interpretation

Compute aggregates directly from operational tables. Restrict the database connection and output to
authorized operators, apply small-cell handling agreed for the real pilot, and retain only approved
aggregate reports. Do not collect search text or add identity, IP, user-agent, geolocation, cross-session
tracking, or a third-party analytics product for these definitions. Search gaps are explicit rather
than silently replaced with invasive or misleading proxies.
