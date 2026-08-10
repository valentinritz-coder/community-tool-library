# Privacy by Design Notes

> Engineering/product notes only. These are not legal advice and must be reviewed before a public pilot.

## Principles

- Collect the minimum personal data necessary for the pilot.
- Do not expose exact home addresses in browse/search experiences.
- Reveal contact/pickup information only when the transaction state requires it.
- Keep verification evidence separate from public/community profile information.
- Define retention before collecting sensitive supporting documents.
- Prefer storing a verification result over storing the verification document indefinitely.
- Never use production personal data in development/test fixtures.

## Initial data categories

| Data | Purpose | Default visibility | Initial retention idea |
|---|---|---|---|
| Account identifier/email | authentication/contact | user + service | while account active, then defined deletion window |
| Display name | community interaction | community | while membership/account active |
| Community membership | access control | relevant community/admin | membership lifecycle + audit window |
| Approximate area | local discovery | community | while account/member active |
| Exact pickup/contact data | complete accepted exchange | transaction participants only | minimize and define short operational retention where possible |
| Item photos/details | listing | eligible community | listing lifecycle |
| Booking history | operate service/disputes/metrics | participants/admin as required | define before pilot |
| Condition photos | handover/return evidence | participants/admin as required | define before pilot |
| Residence/identity verification evidence | trust/eligibility if implemented | verification process only | avoid permanent raw-document storage; dedicated review required |

## Before implementing residence/identity verification

Create a dedicated issue/ADR covering:

- lawful purpose and exact data required;
- who performs verification;
- whether raw documents ever reach our systems;
- deletion/retention;
- user access/correction/deletion workflows;
- breach impact;
- municipal role/responsibilities in the pilot.

## Required pilot work

Before public launch, produce/review at minimum:

- privacy notice;
- terms/rules of service;
- data inventory and retention schedule;
- processor/subprocessor inventory;
- incident response contact/process;
- user data access/deletion process;
- cookie/tracker assessment;
- moderation/reporting process.
