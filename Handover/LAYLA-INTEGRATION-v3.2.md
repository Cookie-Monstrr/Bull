# Layla ↔ Bull v3.2 Integration Contract

> Historical v3.2 contract. The App Group transport is implemented in v3.4 build 47;
> use `LAYLA-INTEGRATION-v3.4.md` and `LaylaBullSchedulePublisher.swift` for setup.

## Status

Bull's consumer model and behavior are implemented. Cross-app transport is not, because
the Layla project and a real shared App Group identifier were not included. Do not add a
guessed entitlement: that can break signing while still failing to wake a suspended app.

## Snapshot Shape

All timestamps are milliseconds since Unix epoch. `dayKey` is the civil date of final
wake in `YYYY-MM-DD` form.

```json
{
  "id": "stable-or-unique-record-id",
  "dayKey": "2026-08-30",
  "plannedFinalWakeTs": 1788069600000,
  "plannedBedtimeTs": 1788129000000,
  "actualFinalWakeTs": 1788069600000,
  "expectedReturnToSleepByTs": null,
  "sleepConsistencyDeviationMinutes": 25,
  "state": "upForDay",
  "updatedTs": 1788069600000,
  "sourceIdentifier": "layla",
  "sourceVersion": 1
}
```

Allowed `state` values:

| State | Bull behavior |
| --- | --- |
| `sleeping` | Zone inactive; no wake allowance starts |
| `plannedBriefWake` | Zone inactive until Layla confirms final wake; an expired return deadline fails safe to unexpected-awake behavior |
| `upForDay` | Actual final wake, or planned wake fallback, starts the post-wake allowance |
| `unexpectedlyAwake` | Same allowance starts when the zone enables unexpected-wake activation; otherwise fixed hours apply |

## Validation

Bull accepts a snapshot only when:

- `sourceIdentifier` is exactly `layla`;
- `sourceVersion >= 1`;
- `dayKey` parses as a Bull civil date;
- planned bedtime is later than planned final wake.

For live zone decisions it must also have been updated no more than 36 hours ago and
cover the interval from 12 hours before planned final wake through six hours after planned
bedtime. Otherwise Bull uses the zone's fixed schedule.

The latest 30 accepted snapshots are retained. A newer same-day Layla record replaces an
older one. If raw Health sleep components exist, a supplied consistency deviation updates
the timing component and both purpose scores. Manual sleep scores remain authoritative.

## Zone Semantics

For a sleep-anchored Home zone with the default 90/90 settings:

- final wake at 06:00 makes Home allowed until, but not including, 07:30;
- Home is active from 07:30 until the pre-bed window;
- planned bed at 22:30 makes Home allowed from 21:00 until bedtime;
- a planned Dawn wake with intended return to sleep does not start the 90-minute clock.

Bull can schedule the 07:30 boundary once it has received the actual final-wake snapshot
while running. It cancels an anchored pending/repeating alert when a current Layla state
makes the zone inactive with no upcoming active boundary.

## Transport Work Still Required

With both projects available:

1. Choose a real App Group identifier and add it to both signed targets/profiles.
2. Put this JSON in the shared container using an atomic replace and complete file
   protection compatible with both apps.
3. Add a Bull bridge that reads, decodes and calls
   `BullStore.applyLaylaSleepSchedule(_:)` on launch, foreground and every legitimate
   background wake.
4. Add monotonic-version/update checks and integration tests for partial writes, stale
   data, timezone changes and clock corrections.
5. Decide which process owns an early-wake notification when Bull is already suspended
   inside Home. An App Group write does not wake Bull. The reliable options are:
   - Layla schedules the wake-relative local notification itself and Bull consumes the
     shared state when opened;
   - a user-approved Shortcuts/App Intent handoff opens/runs Bull;
   - a separately approved server push design;
   - combine the authority and alert scheduler in one process.

Do not claim the unexpected-wake scenario is fully automatic until item 5 is resolved and
tested on a locked physical iPhone.
