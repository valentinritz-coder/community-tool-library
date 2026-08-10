# ADR 0004: Keep payments outside the platform for the MVP

- Status: Accepted
- Date: 2026-08-10

## Context

The pilot needs to test whether objects are actually listed, discovered and exchanged. Integrated payments would add financial, operational and legal complexity before that core behaviour is validated.

## Decision

The MVP may display an owner-defined price per day, including zero, but will not collect, hold, transfer or refund money.

Any agreed payment is settled directly between owner and borrower outside the platform.

## Consequences

### Positive

- materially smaller legal/technical surface for the first pilot;
- faster validation of the core marketplace behaviour;
- no payment credentials or transaction money flows handled by the service.

### Negative

- weaker transaction guarantees;
- less convenient settlement;
- limited ability to enforce deposits/refunds;
- revenue model is not validated by integrated transaction fees.

## Revisit when

Completed exchanges show sustained demand and integrated payment clearly improves trust, conversion or operations enough to justify dedicated legal and payment-provider design.
