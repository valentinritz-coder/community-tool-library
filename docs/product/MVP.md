# MVP Scope

## Goal

Validate that residents of a trusted local community will list, discover and reserve small, low-risk equipment through a simple digital service.

The MVP is successful if it demonstrates real circulation of objects, not merely account creation.

## Actors

### Community owner and appointed administrator

The community owner holds the ownership designation and, while governance is managed, administers
the community and may appoint or remove operational administrators. Appointed administration is a
delegated role and is not ownership.

### Elected council member

When a community completes its optional democratic transition, elected council members exercise
ordinary community administration. Ownership, appointed administration and an electoral mandate
remain distinct roles; the governance constitution is defined in ADR 0005.

### Member / owner

Can list an eligible item, define its basic availability and free/paid-per-day terms, and accept or refuse booking requests.

### Member / borrower

Can browse eligible items, request a reservation, complete handover and confirm return.

A member can be both owner and borrower.

## Core flows

### Join community

1. User creates/signs into an account.
2. User joins an existing community through an invitation/join mechanism.
3. Membership becomes active according to the community's configured validation rule.

### List an item

1. Member adds photo, name, category and short description.
2. Member indicates whether the loan is free or defines a simple price per day.
3. Member defines availability.
4. Item becomes visible to eligible community members.

### Reserve an item

1. Borrower selects an available date range.
2. System rejects conflicting/invalid ranges.
3. Owner receives a booking request.
4. Owner accepts or refuses.
5. On acceptance, the booking becomes confirmed.

### Handover and return

1. Participants mark the item as handed over.
2. Before-condition photo(s) may be attached.
3. Participants mark the item as returned.
4. After-condition photo(s) may be attached.
5. Transaction becomes historical/read-only except for moderation metadata.

## Required MVP capabilities

- authentication;
- community membership and roles;
- managed ownership/appointed administration and optional democratic council governance;
- item CRUD with photos;
- basic search/filtering by name/category;
- availability representation;
- booking request lifecycle;
- conflict prevention;
- owner approval/refusal;
- handover/return lifecycle;
- condition photos;
- basic moderation/removal;
- basic transaction history;
- mobile-first responsive UI;
- privacy/accessibility baseline.

## MVP product rules

- Items must belong to a single owner account for the MVP.
- Items are visible only within communities where sharing is authorized.
- A confirmed booking blocks overlapping confirmed bookings for the same item.
- The platform displays agreed terms but does not collect or transfer money.
- Exact pickup contact/location information should only be exposed when needed for an accepted transaction.
- High-risk/dangerous items are excluded until explicitly designed and legally reviewed.

## Success signals for a pilot

Measure at least:

- active members;
- number of listed items;
- searches performed;
- searches with at least one useful result;
- booking requests;
- accepted bookings;
- completed handovers/returns;
- repeat owners and repeat borrowers;
- cancellations, disputes, non-returns and damage reports.

The primary outcome is repeated completed exchanges, not registrations.
