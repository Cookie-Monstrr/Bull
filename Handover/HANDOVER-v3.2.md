# Bull Native v3.2 Handover

## Release Identity

- Marketing version: 3.2
- Build: 33
- Deployment target: iOS 17
- Payload: v14 in `bull-data-v14.json`
- Four-score version: 9

## What Changed

### Shared Apple Health Action

The Apple Health sync action is now a compact shared row beneath the date header on
Today. It is no longer presented as a Bull Routine-only action. It still imports one
14-day batch containing sleep, HRV, resting heart rate and workouts, and it displays
the last completed check from protected device-local preferences.

### Purpose-Specific Sleep

One night now has three compatible representations:

- `sleep`: frozen generic/legacy score;
- `preventionSleepScore`: acute Prevention input;
- `vigourSleepScore`: Vigour input averaged by Bull Routine across seven days.

New Health imports populate all three. Manual editing exposes Prevention and Vigour
separately and writes their mean only as a legacy compatibility value. Old and manual
history is never silently overwritten by Bull or Layla scoring.

The active four-score model and compounded sleep risk read Prevention sleep. Bull
Routine and the Recovery composite read Vigour sleep. Older scoring functions remain
unchanged for historical parity.

### Stats

- The 7D, 30D, 1Y and All selector now drives the State Outcomes title, its points,
  Peak Urge, and all four top-card averages.
- Range cards use finalized recorded v3.1/v3.2 snapshots and never manufacture a
  value for a missing observation.
- Personal Experiment Readiness excludes archived factors.
- Top Associations shows up to three qualifying results, ordered by absolute
  percentage-point difference. It can still show fewer when fewer pass the locked
  coverage and effect thresholds.
- Sexual Health Outcomes shows the selected 30D/90D window.
- Long explanatory captions beneath charts were removed; empty states, legends and
  the methodology sheet remain.
- User-facing “porn urge” wording is now “urge”. Internal persisted identifiers keep
  their old names for backup compatibility.
- Recurring Triggers now says `trigger days`, `later same-day lapses` and
  `x/y without lapse` instead of the ambiguous `0 lapse` display.
- Additional bottom spacing keeps the final Stats content clear of the tab bar.

### Layla-Aware Risk-Zone Foundation

Risk Zones can use either Fixed Hours or Layla Sleep Schedule. A sleep-anchored zone
stores separate post-final-wake and pre-bed allowances (90 minutes by default) plus
an explicit unexpected-wake switch. A planned brief wake does not count as final
wake. Missing, stale or invalid Layla state falls back to the zone's fixed schedule.

Bull now has a versioned schedule snapshot model, protected persistence, validation,
an ingestion endpoint, effective-zone logic, future-boundary calculation and tests.
The actual cross-app transport is deliberately not fabricated; see
`Handover/LAYLA-INTEGRATION-v3.2.md`.

## Migration and Preservation

`migratedBullDataToV14` calls the full v8→v13 chain, initializes
`fourScoreV9StartDayKey`, preserves all old days/events/snapshots and advances only
payloads below v14. New installs also receive the start key even though `BullData()`
already defaults to v14.

The v14 file loader checks current, previous-good and pre-import copies before every
v13→v8 generation. Wipe Everything removes the v14 generation and every retained
legacy/recovery generation.

## Main Files

- `Bull/TodayView.swift` — shared Health action and manual purpose-sleep editor.
- `Bull/PatternsView.swift`, `Bull/PatternAnalyzer.swift` — dynamic Stats windows.
- `Bull/Core/SleepScore.swift` — purpose weights and provenance identifiers.
- `Bull/HealthKitService.swift`, `Bull/BullStore.swift` — import, fallback and Layla
  consistency application.
- `Bull/Core/Models.swift`, `Bull/Core/Events.swift` — v14 fields.
- `Bull/Core/V27Models.swift` — sleep-anchored zone and Layla snapshot contract.
- `Bull/ContentView.swift`, `Bull/HighRiskZonesView.swift` — effective zone behavior.
- `BullTests/V31Tests.swift` — additive v3.2 regression tests.

## Deliberate Boundaries

- Sleep stages are not scored. Source coverage is too inconsistent to treat missing
  REM/Core/Deep estimates as poor sleep.
- Stats associations keep the existing 28/8/8/3 coverage gates and 3-point minimum;
  the UI does not fabricate three associations.
- Full automatic early-wake notification while Bull is suspended requires a jointly
  designed Layla transport/notification owner. Bull-side logic alone cannot bypass iOS
  process-suspension rules.
