# Public pilot legal-readiness checklist

> Issue #29 readiness inventory, not legal advice. A checked engineering item does not establish
> legal compliance. Every **BLOCKER — REQUIRES LEGAL REVIEW** must be resolved by an appropriately
> authorized human/reviewer before a public pilot.

## Product-owned factual copy

- [x] Explain that community inventory is visible only to active community members.
- [x] Explain that borrower and owner see each other’s email only for an accepted booking while both
      remain eligible; administrators do not receive it merely because they are administrators.
- [x] Explain that participant/admin access to condition evidence is limited by product role and that
      images use private Storage with temporary links.
- [x] State factually that the service displays free/price-per-day terms but does not collect, hold,
      transfer, refund, or guarantee payment; settlement is outside the platform.
- [x] State that identity/residence verification, exact address/phone collection, deposits, insurance,
      and dangerous-equipment support are not implemented.
- [x] Remove “Safe category” from the item form: choosing a supported category is not a safety
      assessment or guarantee.
- [ ] Add reviewed launch copy linking the final privacy notice and applicable terms once supplied.

Product copy must describe mechanics only. It must not claim that an item is safe, that a municipality
endorses or guarantees a transaction, that users are insured, that payment is protected, or that the
service eliminates liability.

## Public-launch blockers — requires external legal review

- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** final privacy notice, controller/processor roles and contact,
      purposes/lawful bases, rights, recipients, transfers, and approved retention periods.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** applicable terms/community rules, eligibility, prohibited
      items, enforceability and acceptance/version-recording approach.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** liability, item safety, damage, disputes, non-return and
      remedies. Do not invent waivers or guarantees.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** insurance position and accurate user wording. The product
      currently supplies no insurance workflow or representation of coverage.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** municipality and operator roles/responsibilities, branding,
      endorsement expectations, support, escalation and incident ownership.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** statutory/contractual recordkeeping and deletion exceptions,
      especially booking and condition evidence.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** GDPR/data-protection analysis where applicable; do not claim
      a lawful basis or “GDPR compliant” status from these engineering notes.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** Supabase and any hosting/email providers as processors or
      subprocessors, including contracts, locations/transfers and hosted configuration.
- [ ] **BLOCKER — REQUIRES LEGAL REVIEW:** accessible method for recording acceptance of final legal
      text and handling material revisions.

## Operational/privacy launch blockers

- [ ] Assign named operator contacts for privacy requests and security incidents; document response
      and escalation procedures.
- [ ] Convert the unresolved schedule in `PRIVACY-DESIGN.md` into approved periods/triggers without
      describing them as statutory unless counsel confirms that.
- [ ] Create and rehearse a manual account access/correction/closure/deletion procedure using only
      synthetic staging data, covering `RESTRICT` condition evidence and both Storage buckets.
- [ ] Decide and document community closure, membership removal, orphan photo, backup/log, and dispute
      hold handling.
- [ ] Inventory the actual hosted providers and environment-specific logs/backups; the repository
      alone cannot describe their retention.
- [ ] Confirm the deployed application has no analytics/advertising tracker. If that changes, reassess
      cookies/local storage before collection; do not add a consent manager when no tracker exists.
- [ ] Complete issue #30’s separate moderation/reporting readiness; it is not implemented here.
- [ ] Establish the incident response contact/process already identified by the privacy notes.

## Deliberately not implemented by #29

- automated DSAR/GDPR workflows or a claim of compliance;
- automatic account deletion, retention workers, cron jobs, or a generic lifecycle framework;
- cookie consent tooling without an actual tracker;
- identity/residence verification or collection of supporting documents;
- payments, deposits, insurance, liability adjudication, or municipal guarantees;
- moderation work owned by issue #30 or deployment/metrics work owned by issue #31.

These omissions keep the MVP honest and small. They do not make unresolved public-launch blockers
optional.
