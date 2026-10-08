# Bull v3.3 Full Audit Report

**Audit date:** 31 August 2026  
**Reviewed package:** Bull Native v3.3, build 35  
**Baseline preserved:** Bull Native v3.2.1, build 34  
**Decision:** source-complete and conditionally ready for the Mac/device gates; **not yet
cleared** for real therapist reliance, Layla integration or broad external testing.

## Executive assessment

v3.3 now implements the therapist scope discussed with the owner: Urge Routine, Urge
State, individual urge observations, counted relapses, and Risk Zone activity/settings.
It intentionally excludes Vigour, Bull Routine/State, sexual health, workouts, raw
HealthKit data, exact coordinates and unrelated/free-form notes.

The Risk Control design is appropriately fail-safe at source level. A protected setting
cannot be silently weakened through the normal UI, backup import, undo-import or Reset.
The therapist can review a sanitized proposal, while Bull retains and applies the exact
owner-local version only after approval. Stale approval cannot overwrite a later stronger
setting. The owner can still explicitly revoke access; a failed revocation leaves controls
protected and prevents local wipe.

The requested exit-only state is implemented as `No Safeguard Possible`. It exposes no
completion action and only an exit resolves the visit. Its prompt mode is persisted so it
cannot receive false safeguard credit in historical Urge Routine input or weekly goals.

The main remaining risks are operational, not hidden source claims: this environment
could not compile or run the app; CloudKit capabilities/schema have not been activated and
tested on two signed devices; silent pushes are not delivery receipts; full backup remains
plaintext; and Layla still has no real cross-app transport.

## Audit method and evidence boundary

The review covered the supplied v3.2 package, the preserved v3.2.1 remediation tree and
the new v3.3 source. It included data migration, storage, import/export, Risk Zone state,
notification copy, scoring side effects, therapist projection, approval integrity,
CloudKit lifecycle, revocation, privacy scope, accessibility labels, project settings and
test inventory.

Static checks completed:

- 66 Swift source/test files reviewed structurally;
- 169 XCTest methods inventoried across 11 test files;
- JSON fixtures parsed;
- entitlement XML checked structurally;
- Swift delimiters, comments and strings checked for balance;
- merge markers, old notification copy, obvious secrets and slash-separated SwiftUI
  control titles scanned;
- v3.3 scope-leak regression tests added.

This was a Linux environment without Swift, Apple SDKs, Xcode, simulator, signing or
physical devices. “Implemented” below means present in source and static regression
coverage. It does not mean compiled or device-verified.

## User requirements disposition

| Requirement | Audit result |
| --- | --- |
| Therapist sees only Urge-related data and relapses | Implemented with an explicit narrow projection |
| Risk Zone presence counts as Urge data | Implemented; physical entry is shared even outside active hours |
| Therapist warned when owner is in a zone | Implemented as durable event + CloudKit snapshot + local therapist notification; delivery remains best effort |
| Therapist oversees anti-workaround settings | Implemented for zone/risk-alert weakening changes |
| Owner can transparently end access | Implemented; owner audit persists and therapist detects removed share on next successful sync |
| High-risk place can have no possible safeguard | Implemented as exit-only `No Safeguard Possible` |
| No fake completion for exit-only zone | Implemented in UI, notification actions, store validation and scoring credit |
| Replace old Risk Zone warning sentence | Implemented: **“Take action before you regret it!”** |
| Shorter alert-setting wording | Implemented: `Alerts`, `Time Sensitive`, `Repeat: N min` |
| Remove slash-separated duplicate button wording | Implemented for app controls; remaining slashes are ratios, URLs, exercise notation or hidden legacy aliases |
| Edit prior days, including yesterday's ejaculatory log | Missing in original v3.2 audit; implemented in v3.2.1 and retained in v3.3 |

## Therapist data contract

### Shared

- 90 days of Urge Routine and Urge State scores, including final/revision state;
- Urge observations with intensity, context, source and time;
- counted relapse date/time and components, without trigger or narrative fields;
- Risk Zone name, radius, caution, enabled state, schedule, time zone, exit-only state and
  safeguard instruction when a safeguard exists;
- coordinate-free zone entry/exit transitions, current presence and Risk-Zone-only alert
  outcomes;
- alert repeat, Time Sensitive setting and monitoring health;
- sanitized pending Risk Control proposals and structured decisions.

### Explicitly excluded

- Bull Routine, Bull State and Vigour;
- daily/wake sexual observations and ejaculatory-control logs;
- workouts, exercise logs and raw HealthKit samples;
- exact latitude/longitude and room-level/private-context state;
- therapy note, relapse next action, notes and triggers;
- general compounded-risk alerts or their legacy base-risk value.

The projection uses dedicated sanitized types rather than serializing `BullData`. The
CloudKit sender scans encoded keys for forbidden categories before saving. Exact current
and proposed zones remain only in the owner's local approval record. A geofence move is
shared as a distance, so the therapist should use `Discuss` whenever the destination
cannot be assessed from the name and distance.

## Protection and integrity review

### Normal weakening attempts

Pause, delete, shrink, move, rename, schedule reduction, lower caution, relaxed sleep
allowance, disabled unexpected-wake activation, safeguard changes, exit-only-to-safeguard,
longer repeats and Time Sensitive off are held pending. The current setting remains live.

Clearly stronger changes—new zones, larger radius, broader days, higher caution, shorter
allowances/repeats, Time Sensitive on and safeguard-to-exit-only—can apply immediately.
Ambiguous changes are conservatively reviewed.

### Approval tampering and races

The shared decision contains no coordinates and cannot supply a replacement zone to the
owner. Bull accepts only a known local pending ID plus approved/rejected status. The exact
local proposal is applied. If current protection no longer equals the version reviewed,
the proposal is cancelled as superseded. Duplicate pending requests for one control are
not created.

The therapist decision record is encrypted, scope-validated, bounded to 300 decisions and
serialized to prevent concurrent in-app reviews from overwriting one another.

### Restore, reset and revocation

- Full import and undo-import are blocked while owner protection is active.
- Imported backup transport/cache is cleared and any pending proposal is cancelled; a real
  CloudKit share must be rediscovered.
- Direct `resetAll()` also refuses active protection, not only the Settings button.
- Settings Reset first asks CloudKit to revoke. Failure leaves data and protection intact.
- Once a share is confirmed, share deletion or confirmed absence is required before the
  local owner end state. An unconfirmed failed setup can be cancelled locally.
- The therapist treats only a missing shared zone as revocation. Missing/malformed snapshot
  data is a retryable error, not a false `Oversight Ended` result.

### Limits Bull cannot enforce

An iOS app cannot prevent uninstall, device wipe, iCloud sign-out, notification changes,
Location Services changes, force quit or OS suspension. Bull reports detectable monitoring
degradation on its next execution opportunity. It cannot promise continuous or emergency
supervision.

## Risk Zone and exit-only review

The owner receives the requested sentence in private and detailed Risk Zone notifications.
The therapist receives the same sentence with a sanitized zone-status message. Entry is
shared outside active hours because physical presence is part of the agreed Urge scope;
the active window still controls the owner's intervention sequence.

Exit-only mode is enforced in four layers:

1. editor hides safeguard fields and explains that leaving is required;
2. in-app destinations and notification categories omit `Safeguard Done`;
3. store methods reject completed/corrected/reversed events for that zone;
4. historical and weekly scoring requires a genuine safeguard-mode prompt and resolution.

Circular regions are deliberately clamped to a minimum practical radius and are
building-scale. A Risk Zone cannot prove that the owner is in a particular room. Exact
room oversight would need an explicit user action or different hardware signal.

## CloudKit architecture review

Bull uses custom-zone CloudKit sharing with separate records for the owner snapshot and
therapist decisions. Sensitive bodies use `CKRecord.encryptedValues`; ordinary metadata is
limited to schema and update values. The owner and therapist subscribe for content-available
database changes. Background completion waits for sync with a bounded fail-safe.

Positive properties:

- no custom server or embedded secret;
- no full-backup upload;
- participant access is private and explicit;
- owner and therapist writes use separate records;
- only one therapist and one client share are accepted by this release;
- current warning is prioritized over backlog;
- first therapist sync shows history without flooding old lock-screen warnings;
- queued/failed events are deduplicated and retryable.

Important boundary: `published` means the CloudKit record save succeeded. It does not mean
the therapist device fetched it, scheduled a local notification, displayed it or that a
human saw it. Silent pushes can be delayed or suppressed. The product must say
`last sync`/`warning queued`, not `therapist notified`, unless a future acknowledged-receipt
protocol is added.

Apple references used to verify the implemented API direction:

- [CKContainer and share acceptance](https://developer.apple.com/documentation/cloudkit/ckcontainer)
- [CKRecord encrypted values](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues)
- [CloudKit environment entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-environment)
- [Participant removed status](https://developer.apple.com/documentation/cloudkit/ckshare/participantacceptancestatus/removed)

## Original v3.2 missing feature

The audit record expressly includes the requested finding:

> **Original v3.2 finding:** previous days could not be edited. In the reported example,
> yesterday's ejaculatory-control log could not be edited.

That was remediated in v3.2.1 and remains in v3.3. The Today date navigator passes the
selected date into `EjaculatoryControlView`; the screen lists entries for that day and
supports add, edit and delete. Editing preserves the event ID and original timestamp,
adds `modifiedTs`, and preserves live/retrospective provenance. Ejaculatory control is
event-only and does not rewrite a four-score snapshot.

## Findings register

| ID | Severity | Status | Finding / required action |
| --- | --- | --- | --- |
| B33-01 | Blocker | Open | Compile, run 169 tests, Analyze and inspect a signed archive on a Mac |
| B33-02 | Blocker | Open | Run two-account CloudKit Development flow, deploy schema, then repeat through TestFlight Production |
| B33-03 | Blocker for Layla | Open | Layla has consumer validation only; no App Group/transport or suspended-app alert owner exists |
| H33-01 | High | Accepted limit | Silent CloudKit/APNs delivery has no receipt and is not emergency monitoring |
| H33-02 | High | Open | Full recovery backup is readable plaintext JSON; keep warning/redacted export and add encryption before broad sensitive-data testing |
| H33-03 | High | Test required | Shared history is one record capped at 900 KB; representative 90-day load must remain below the stop limit |
| H33-04 | High | Open | Generate the archive privacy report and reconcile App Store disclosures before distribution |
| H33-05 | High for clinic scale | Designed limit | One therapist per owner and one client per therapist install; not a multi-client portal |
| M33-01 | Medium | Open | Whole-model pretty JSON persistence remains on the main actor; benchmark multi-year data |
| M33-02 | Medium | Open | Relapse edits update the projection, but therapist-visible edit/delete provenance is not a distinct audit stream |
| M33-03 | Medium | Accepted limit | iOS geofences are building-scale and can be delayed by the OS |
| M33-04 | Medium | Test required | Dynamic Type, VoiceOver, dark appearance and all new alerts need physical UI validation |
| M33-05 | Medium | Operational | Use a fresh/dedicated therapist install; accepting a client role is not designed to preserve a separate personal Bull workspace |

## Readiness by use case

| Use case | Decision |
| --- | --- |
| Continue private owner use | After the v3.3 Mac build/test and one-device upgrade smoke test |
| Small owner-only internal test | After B33-01 and privacy/crash review |
| Therapist Development trial | After B33-01 plus complete Development two-device checklist |
| Therapist TestFlight trial | After Production schema deployment and the TestFlight two-device checklist |
| Layla integration | Not ready; B33-03 remains |
| Broad external testers | Hold until blockers, privacy report, 900 KB load, accessibility and backup handling are cleared |

## Final recommendation

Do not spend study time manually exploring this build now. The next useful owner action is
the exact Mac/two-device gate in `Handover/TWO-DEVICE-TEST-v3.3.md`. If that gate passes in
Development and TestFlight, the implemented therapist scope is suitable for a limited,
consensual pilot with explicit wording that alerts are best effort and not emergency care.

Do not connect Layla or advertise clinical/compliance guarantees. Before wider testing,
encrypt recovery exports, produce the archive privacy report, benchmark large history and
decide whether relapse-change audit and multi-client therapist support belong in v3.4.
