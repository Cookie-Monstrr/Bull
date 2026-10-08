# Layla → Bull Sleep-Schedule Bridge (v3.4 build 47)

## Outcome

Bull now has a real consumer transport for Layla's current sleep plan and observed sleep
state. It reads one atomic, versioned file from the already-configured App Group
`group.com.ahmed.Bull`, validates it, rejects stale/replayed/conflicting updates, persists
accepted snapshots, and immediately re-evaluates any occupied sleep-anchored Risk Zone.

The Layla-to-Bull file contains only schedule semantics. Raw HealthKit samples, Risk Zone
coordinates, notes, relapse data, scores and therapist data are not part of this payload.
Bull also refuses to read the schedule file when the installation is in therapist role.

## Files

- `Bull/LaylaScheduleBridge.swift` — Bull reader, wire validation, freshness and diagnostics.
- `Bull/Core/V27Models.swift` — snapshot time zone, observed-state timestamp and source sequence.
- `Bull/Core/V31Logic.swift` — global monotonic ordering and replay protection.
- `Bull/BullStore.swift` — ingestion, persistence, safe fallback and boundary calculation.
- `Bull/BullApp.swift` and `Bull/ContentView.swift` — launch, foreground and resident refreshes.
- `Bull/HighRiskZonesView.swift` — current/stale/error connection status and diagnostics.
- `Handover/LaylaBullSchedulePublisher.swift` — self-contained publisher to copy into Layla.

## One-time Layla setup

1. In Xcode, add `Handover/LaylaBullSchedulePublisher.swift` to the Layla app target.
2. In the Layla target's **Signing & Capabilities**, add **App Groups**.
3. Select the existing registered group `group.com.ahmed.Bull`.
4. Confirm Bull's target still has the same group selected.
5. Call `BullSleepSchedulePublisher.publish(...)` after every plan change and every
   observed sleep-state transition.

Both apps must be signed by the same Apple Developer team. Do not rename the group,
payload file or state raw values in one app without versioning both sides.

## Layla state mapping

| Layla event | Shared state | Required timing |
| --- | --- | --- |
| Intended sleep begins or resumes | `sleeping` | Next planned final wake and next bedtime |
| Planned Dawn/Fajr wake with intended return | `plannedBriefWake` | State-observed time and return-to-sleep deadline before final wake |
| Layla confirms the person is up for the day | `upForDay` | Actual final-wake time |
| Layla concludes an unplanned wake became final | `unexpectedlyAwake` | Actual wake time |

Example from Layla's state reducer:

```swift
do {
    try BullSleepSchedulePublisher.publish(
        plannedFinalWake: plan.finalWake,
        plannedBedtime: plan.nextBedtime,
        actualFinalWake: state.actualFinalWake,
        expectedReturnToSleepBy: state.returnToSleepDeadline,
        sleepConsistencyDeviationMinutes: metrics?.scheduleDeviationMinutes,
        state: .upForDay,
        stateObservedAt: state.changedAt,
        timeZone: plan.timeZone,
        sourceVersion: 1
    )
} catch {
    // Show or log the local sharing error in Layla; never fabricate fallback timestamps.
}
```

The publisher derives `dayKey`, Unix-millisecond timestamps, source identity and a global
monotonic sequence. It writes the complete envelope atomically and uses file protection
that remains accessible to legitimate post-first-unlock background work.
Bull pins the first accepted Layla bundle identifier; a later payload claiming the same
source from a different bundle is rejected rather than silently changing authority.

## Risk-Zone behavior

With the default 90/90 Home settings:

- `sleeping` keeps the zone inactive;
- `plannedBriefWake` stays inactive until Layla reports sleep/final wake, but Bull
  pre-schedules the return-deadline boundary so an overdue brief wake fails safe;
- `upForDay` and `unexpectedlyAwake` use the actual wake as the start of the 90-minute
  getting-ready allowance;
- Home is active after that allowance until 90 minutes before the next planned bedtime;
- invalid, missing or older-than-current transport data never overwrites a valid record;
- once the accepted record is no longer current, the zone's existing fixed schedule is
  used automatically.

The Risk Zone editor and **Check Device Status** sheet show whether Bull is using a current,
cached, stale, missing or rejected Layla update, plus the source version, sequence and time
zone when available.

## Important iOS boundary

An App Group file write does not launch or wake a suspended Bull process. Bull reads on
launch, foreground, while resident, and on any legitimate process launch; notifications
that Bull scheduled before suspension still fire. A brand-new unexpected-wake update that
arrives while Bull is fully suspended cannot by itself cause Bull to schedule a new alert.

For that last physical-device scenario, choose and test one explicit owner later: Layla
schedules a generic wake-relative local notification, or an approved server sends a push.
Do not claim fully automatic suspended-app unexpected-wake alerts until that owner is
implemented and tested on a locked iPhone.

## Device acceptance checks

1. Publish a sleeping record in Layla; foreground Bull and confirm **current** status.
2. While inside Home, publish `upForDay` with an actual wake and confirm the active boundary
   is actual wake + the configured allowance.
3. Publish `plannedBriefWake`, confirm no immediate alert, then confirm an uncancelled return
   deadline becomes the active boundary.
4. Publish a higher sequence with a corrected time; confirm Bull adopts it.
5. Restore/replay an older sequence; confirm Bull keeps the newer schedule.
6. Test a malformed/partial file, a stale update, travel time zones and a DST transition;
   confirm fixed-hour fallback and no crash.
7. Repeat the boundary checks on a locked physical iPhone, including terminating Bull.
