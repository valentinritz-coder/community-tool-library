# ADR 0001: Start as a responsive web application

- Status: Accepted
- Date: 2026-08-10

## Context

The pilot must be easy to open from a link or QR code, work well on phones, and avoid app-store installation friction. The target audience may include older or less digitally confident residents.

## Decision

Build the MVP as a responsive web application rather than separate native iOS/Android applications.

## Consequences

### Positive

- one deployable client surface;
- immediate access from a URL/QR code;
- faster iteration during a municipal pilot;
- simpler accessibility testing and release process.

### Negative

- less native device integration initially;
- offline behaviour and push notifications may be more limited;
- native applications may still become appropriate later.

## Revisit when

A validated product requirement cannot be served acceptably by the web platform, or sustained usage justifies native clients.
