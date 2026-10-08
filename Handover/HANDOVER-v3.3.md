# Bull Native v3.3 Handover

## What v3.3 adds

v3.3 adds a deliberately narrow Therapist Oversight role over private CloudKit sharing.
The therapist projection contains only:

- Urge Routine and Urge State scores;
- individual Urge observations;
- counted relapse records without notes or triggers;
- coordinate-free Risk Zone settings, entry and exit state, zone-alert history and
  monitoring health;
- pending Risk Control proposals and their structured approval state.

It has no fields for Bull Routine, Bull State, Vigour, sexual-health observations,
workouts, raw HealthKit samples, exact coordinates, free-form therapy notes, relapse notes
or next actions. A runtime forbidden-key scan blocks owner upload if a future code change
tries to add one of those categories.

## Protected Risk Controls

Owner controls are protected as soon as setup begins. Changes that clearly strengthen
protection apply immediately. Changes that can weaken or obscure it remain unapplied until
the therapist approves them:

- pause, delete, shrink, move or rename a zone;
- reduce a zone's caution level or monitoring schedule;
- relax wake or bedtime allowances;
- change a safeguard or switch an exit-only zone back to a safeguard;
- lengthen the alert repeat interval;
- turn off Time Sensitive delivery after it has been enabled.

The therapist receives only the sanitized proposal. The owner's exact proposed geofence
centre remains local; a centre move is summarized by distance. Bull applies the exact
local proposal only after a matching decision ID is received. A proposal is cancelled if
a later stronger setting means it is no longer the exact version the therapist reviewed.

Full backup import, undo-import and direct reset cannot bypass active protection. The
owner may explicitly end access. CloudKit revocation is fail-safe: if deletion cannot be
confirmed, controls remain protected and Reset does not wipe the local audit.

## Risk Zone behavior

- Every owner Risk Zone warning uses **“Take action before you regret it!”**
- Therapist Risk Zone warnings use the same phrase and contain no coordinates.
- A physical entry is shared even outside the zone's intervention schedule. The schedule
  still controls owner intervention prompts and repeats.
- Current presence is retained even if the original entry predates the 90-day history.
- Still-inside warnings are throttled by the protected repeat interval.
- Permission, notification and region-registration changes update the therapist dashboard
  live; degraded monitoring creates a warning when at least one zone is enabled.

`No Safeguard Possible` marks an exit-only zone. It has no completion action and cannot
be marked completed, corrected or reversed. Only a geofence exit resolves the visit.
Prompt events persist the resolution mode, so an exit-only exposure can never receive
false safeguard credit in historical scoring or weekly safeguard goals.

iPhone circular geofences are building-scale. They cannot prove room-level presence.

## CloudKit lifecycle

- Container: `iCloud.com.ahmed.Bull`
- Owner: private custom zone `BullTherapistOversight`
- Share: private, zone-wide, read-write `CKShare`
- Payload and decision bodies: `CKRecord.encryptedValues`
- Updates: private/shared database subscriptions with content-available pushes
- Limits enforced by Bull: one therapist participant per owner share; one client share per
  therapist installation; 900 KB payload safety limit; 300 retained decisions

The therapist app detects removal of the shared zone and replaces the stale dashboard
with an explicit `Oversight Ended` screen. A transient snapshot read/decode error does not
masquerade as revocation.

CloudKit publication is not a delivery receipt. Silent pushes can be delayed by network,
iCloud state, Low Power Mode, OS scheduling or force-quit behavior. This is supportive
oversight, not emergency monitoring.

## v3.2 finding carried into this audit

The original v3.2 audit found that previous days could not be edited, including yesterday's
ejaculatory-control log. v3.2.1 implemented selected-day add, edit and delete with stable
event identity, modification time and retrospective provenance. That remediation remains
present in v3.3.

## Main v3.3 files

- `Bull/Core/V33Models.swift` — narrow shared contract and approval/audit models
- `Bull/Core/V33Logic.swift` — projection sanitization, protection policy and v15 migration
- `Bull/TherapistCloudService.swift` — share lifecycle, subscriptions, sync and revocation
- `Bull/TherapistOversightViews.swift` — owner setup and therapist dashboard
- `Bull/BullStore.swift` — durable outbox, protected mutations and monitoring state
- `Bull/HighRiskZonesView.swift` — exit-only mode and concise alert settings
- `BullTests/V33Tests.swift` — v3.3 regression and scope-leak tests

## Known boundaries

- No Mac build, XCTest, Analyze, signed archive or device UI test was possible here.
- Layla cross-app transport remains absent.
- The shared history is a single bounded encrypted record, not paginated storage; run the
  supplied large-history stop condition before broad testing.
- Full recovery export remains plaintext JSON.
- Whole-model JSON encoding still runs on the main actor and needs a representative
  multi-year performance benchmark.
- Relapse edits are reflected in the current projection, but edit/delete provenance is not
  a separate therapist event stream.
- Use a fresh or dedicated Bull install for the therapist role; one install is not a
  multi-client practice dashboard.

See `VALIDATION-v3.3.md` and `CLOUDKIT-ACTIVATION-v3.3.md` for the release gate.
