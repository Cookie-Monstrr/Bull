# v3.2 Audit Remediation Record

This record maps the 30 August 2026 full v3.2 audit to the v3.2.1 source. “Implemented”
means code and regression coverage are present; it does not replace the pending Xcode and
physical-device gate.

| Audit item | v3.2.1 status | Result |
| --- | --- | --- |
| BLK-01 Build/tests unverified | Pending user test | 153 tests supplied; Xcode unavailable here |
| BLK-02 Previous-day editing missing | Implemented | Includes yesterday's ejaculatory-control add/edit/delete flow |
| BLK-03 Therapist oversight absent | Blocked | Requires a separate scoped-access product and threat model |
| BLK-04 Layla transport absent | Blocked | Consumer hardened; transport and suspended alert owner remain |
| HIGH-01 Past Stress Relief saved to today | Implemented | Selected day is passed and past logging is retrospective |
| HIGH-02 Corrections leave stale scores | Implemented | Current-era snapshots recompute with revision metadata |
| HIGH-03 Stale Layla overwrite | Implemented | Stale/conflicting rejected; replay idempotent; newer accepted |
| HIGH-04 Plaintext full export | Partly implemented | Warning and redacted trends added; encryption still open |
| HIGH-05 Biometric fail-open | Implemented | Authentication now fails closed and gates preference enablement |
| HIGH-06 Snooze leaves repeats active | Implemented | Existing zone series is cancelled before one snooze is created |
| HIGH-07 Future boundary has no repeats | Implemented | Finite follow-ups are pre-scheduled through the active window |
| HIGH-08 Time-sensitive not provisioned | Awaiting signed build | Entitlement and setting checks added; profile/device must verify |
| HIGH-09 Import claims missing rollback | Implemented | Verified safety copy is now a commit prerequisite |
| HIGH-10 New import collections unreported | Partly implemented | All collections counted; field-level repair detail/preview remains |
| HIGH-11 Sensitive lock-screen copy | Implemented | Context-neutral requested prompt; private mode hides app/place/safeguard |
| HIGH-12 Health disclosure/status inaccurate | Implemented | All categories named; request-completed semantics used |
| MED-01 Retrospective ordering | Implemented | Civil-day clock timestamp plus durable ingestion-order tie break |
| MED-02 Import permissive/unbounded | Partly implemented | 25 MB cap added; richer schema preview remains |
| MED-03 Main-thread whole-model persistence | Open | Needs representative multi-year benchmark before redesign |
| MED-04 Foreground fix requires Always | Implemented | When In Use now permits foreground reconciliation |
| MED-05 Sleep boundaries/Fajr inference | Partly implemented | Boundary overlap/clipping fixed; personal/device validation remains |
| MED-06 Accessibility unvalidated | Partly implemented | Forced Light Mode removed; device accessibility matrix remains |
| MED-07 Live Urge omitted from experiments | Implemented | Live 7+ observations now join legacy high-urge outcomes |
| MED-08 All Time capped at ten years | Implemented | Cap removed |
| MED-09 Coupled architecture | Open | Refactor before backend/transport expansion |
| MED-10 Distribution privacy artifacts | Pending archive | Generate privacy report and reconcile disclosures |
| MED-11 Inactive retained alert surfaces | Documented | Only Risk Zone alerts are active in this release |
| MED-12 Historical copy says Today | Implemented for corrected flows | Selected date shown in Urge, Bull State, Stress and relief editors |

## Readiness Decision

- Current owner's private use: suitable only after tonight's build/test/smoke gate passes.
- Therapist viewing on the owner's phone: possible after that gate, under the owner's
  control, using corrected provenance and preferably the redacted trends export.
- Remote therapist access: not available and must not be simulated by sending a full backup.
- Layla integration: not available until the joint transport is built and device-tested.
- External testers: hold until the Xcode/device gate passes and the intended test scope no
  longer depends on the blocked therapist/Layla surfaces.
