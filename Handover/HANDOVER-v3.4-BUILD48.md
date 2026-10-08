# Bull v3.4 build 48 — Cardio zones and active energy

## Outcome

Build 48 replaces workout-label-only cardio intensity whenever Apple Watch heart-rate
coverage is sufficient and displays Apple Health active calories from recognised cardio
workouts. Neither active calories nor the zone source changes any Bull score.

## Cardio intensity

- Bull requests read access to workout heart rate and date of birth in addition to the
  existing workout permission.
- It estimates maximum heart rate from the Health profile using `208 − 0.7 × age`.
- Heart-rate samples are reduced to one mean value per elapsed workout minute so dense
  sampling cannot create duplicate time.
- Zones use percentages of estimated maximum heart rate: Zone 1 below 60%, Zone 2 at
  60–69%, Zone 3 at 70–79%, Zone 4 at 80–89%, and Zone 5 at 90% or above.
- Zones 2–3 count as moderate; Zones 4–5 count as vigorous and therefore receive the
  existing double moderate-equivalent credit. Zone 1 is excluded from scored minutes.
- Heart-rate classification is accepted only when it covers at least half the workout and
  at least five minutes. Otherwise Bull keeps an explicit workout-type estimate.
- The correction screen identifies Heart-Rate Zones, Workout Estimate or Mixed as the
  source. Manual minute corrections continue to replace imported minutes without creating
  duplicate sessions.

## Active calories

- Bull reads the `activeEnergyBurned` statistic attached to each recognised aerobic
  HealthKit workout and sums it into the workout's civil day.
- The Today > Bull Routine breakdown shows the rolling seven-day active-kcal total next to
  moderate-equivalent minutes.
- Exercise Plan shows the same rolling seven-day total.
- Cardio Correction shows the selected day's imported active energy even when the user
  corrects its minutes.
- This is Apple Health's estimated active workout energy, not total daily Move-ring energy,
  resting energy, dietary intake or an exact laboratory calorie measurement.
- Active calories are display-only and deliberately do not affect the 40-point Cardio
  pillar or any other score.

## Files changed

- `Bull/HealthKitService.swift`
- `Bull/Core/Models.swift`
- `Bull/Core/V30Models.swift`
- `Bull/Core/V31Logic.swift`
- `Bull/BullStore.swift`
- `Bull/ExercisePlanView.swift`
- `Bull/TodayView.swift`
- `BullTests/V31Tests.swift`
- `Bull.xcodeproj/project.pbxproj`

## Device gate

1. Install build 48 and accept the expanded Health read request.
2. Record one Apple Watch cardio workout with heart rate and active energy.
3. In Bull, tap Sync, expand Bull Routine and confirm rolling minutes plus active kcal.
4. Open Log Cardio and confirm the selected day shows active energy and its intensity source.
5. Compare the kcal figure with the same workout in Fitness/Health; allow only normal
   rounding differences.
6. Deny heart rate or date-of-birth access in a separate test and confirm Bull labels the
   intensity source Workout Estimate without losing cardio minutes.
7. Run Product > Test and require all tests to pass before distributing the build.

Build 48 adds four regression tests for calorie aggregation/provenance migration and
minute-bucket zone classification. This environment does not include Xcode or the Apple
SDK, so the physical build and complete test suite remain the device-owner release gate.
