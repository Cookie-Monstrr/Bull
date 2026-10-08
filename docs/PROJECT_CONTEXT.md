# Bull project context

Repository audit as of 8 October 2026. This document describes the checked-in source on `Test`, then separates product requirements and proposals from implemented behavior. Historical handovers are useful background, but the current Swift and Xcode project are the authority for what exists now.

## Status key

- **Existing:** Present in the checked-in implementation. This does not certify a successful device run.
- **Agreed direction:** A requirement stated for future product work, not an implemented feature.
- **Provisional:** A design or scoring choice needing explicit approval and validation before implementation.
- **Not implemented:** No corresponding feature was found in this iOS source.

## Existing product and architecture

- **Project:** `Bull.xcodeproj` contains the Bull iOS app, `BullWidgetsExtension`, and `BullTests` targets. The project declares iOS 17+, Swift 5, marketing version 3.4, and build 54. `Bull/BullApp.swift` creates the app's shared observable services and injects them into SwiftUI views.
- **Navigation:** `Bull/ContentView.swift` presents Today, Stats, and Settings tabs for the owner. A therapist-role installation shows a separate therapist dashboard instead. A privacy shield/device-unlock gate covers sensitive content when enabled.
- **Today and logging:** `Bull/TodayView.swift` presents paired Urge and Bull figures, a current next step, score breakdown, active risk zones, personal experiments, events, health refresh, dated logging, and Urge Support. The logging routes include urge and Bull-state observations, stress and stress relief, nutrition/fasting, sleep, exercise, sexual observations, and lapses. Support screens include lapse recovery, risk actions, trigger/response libraries, implementation plans, and calendar/history.
- **Stats:** `Bull/PatternsView.swift` and `Bull/PatternAnalyzer.swift` provide score histories and charts, sleep/HRV views, relapse markers, fasting summaries, and observational associations. Associations are descriptive, not causal proof or a relapse forecast.
- **Settings:** Health access and 90-day sync, Layla connection status, daily-input reminders, post-lapse plan, therapist oversight, privacy lock, backup import/export, redacted trends export, and reset are present in `Bull/SettingsView.swift`.
- **Persistence:** `Bull/BullStore.swift` owns a version-15 `BullData` model (`Bull/Core/Events.swift`). It stores `bull-data-v15.json` in Application Support with atomic writes, complete file protection, a previous-good copy, pre-import safety copy, and recovery from older versions. The data model retains dated records, event histories, plans, scores, risk zones, exercise logs, and therapist audit state. Some device-local preferences live in `AppPreferences`/`UserDefaults`. Full backup exports are plaintext JSON and sensitive; the redacted trends export is narrower.
- **Privacy and therapist sharing:** `PrivacyManager` uses device-owner authentication when the lock is enabled. `TherapistCloudService` implements a scoped CloudKit share/projection and role gating, not a general backup sync or emergency service. Real account, entitlement, schema, delivery, and revocation behavior still require two-device verification.

## Existing scoring and health behavior

- **Four current scores:** `BullStore.fourScoreState` computes Urge Fuel (`urgeRoutine`), Urge State, Bull Fuel (`bullRoutine`), and Bull State, then stores versioned daily snapshots (`currentFourScoreVersion = 10`). Urge Fuel uses sleep protection, stress regulation, environment protection, and recorded fasting; Urge State comes from urge observations. Bull Fuel uses a seven-day view of cardio, sleep, nutrition, and strength; Bull State comes from its observations. The exact algorithms live in `Bull/Core/V31Logic.swift` and related versioned core files. These are not Self-Control Readiness.
- **Fasting today:** Fasting is recorded separately from nutrition. The current model can award protection for a recorded fasting day and suppress planned exercise prompts for that day. This is existing behavior; it is not yet the future no-penalty bonus contract for the proposed headline KPI.
- **Apple Health:** `HealthKitService` requests read access to sleep analysis, HRV, resting heart rate, heart rate, workouts, active energy, and date of birth. It imports completed sleep, HRV, resting heart rate, workout minutes/strength, and cardio calories. Sleep-window HRV is preferred, with a 24-hour fallback. Cardio may use heart-rate-zone coverage or workout-type fallback. Active calories are displayed, not scored.
- **Sleep:** `BullSleepScore` derives Bull's own duration, bedtime-consistency, and interruption components from HealthKit sleep samples; it is not Apple's private Sleep Score. A heuristic allows one plausible planned Fajr wake. Layla's App Group file supplies *planned wake/bedtime timing* for risk-zone/reminder scheduling, while Apple Health supplies completed sleep. Bull can fall back when Layla's snapshot is missing or stale. No independent 7-day sleep-debt model with extra weight on the latest three days was found.
- **Physical recovery:** A personal HRV baseline already exists. `BullStore.hrvBaseline` uses the median of up to 30 prior recorded values and requires at least seven; `BullRecoveryScore` defines an HRV-relative score. `v29RecoveryComposite` also combines sleep, HRV, resting-heart-rate baseline, and recent training load, omitting unavailable inputs. This is existing context, not a validated WHOOP-equivalent recovery measure or the proposed final readiness formula.

## Existing alerts, risk zones, and widgets

- **Risk zones:** `HighRiskZoneService` uses Core Location circular-region monitoring, authorization checks, and region reconciliation. `HighRiskZonesView` supports configuration and diagnostics. `BullStore` persists zone changes with readback/rollback protection, and `ContentView` evaluates active windows and safeguard state. Geofence arrival and background execution are controlled by iOS and can be delayed.
- **Notifications:** `NotificationService` handles private zone/safeguard actions, a device-local queue for unfinished daily inputs, tests, and therapist alerts. `ContentView` explicitly retires older fixed stress reminders and general risk alerts. Notification delivery, Time Sensitive status, and CloudKit silent pushes are best effort.
- **Widgets:** `BullWidgets/BullWidgets.swift` registers five read-only system-medium widgets: Urge paired figures, Bull paired figures, Today's Priorities, 30-day Urge Overview, and 30-day Urge Fuel Breakdown. The app publishes score, generic priority, and bounded chart projections through the App Group in `WidgetSnapshotBridge`; the extension does not read the full `BullData` file. Widget content uses `privacySensitive()`. WidgetKit decides when timelines actually refresh.

## Known issues and limits

- The current source is not, by itself, proof of an Xcode build, passing XCTest suite, signed archive, or physical-device behavior. Historical build-54 notes report static validation and leave Xcode/device checks outstanding; this audit did not run them.
- Plaintext full backup export exposes sensitive data if mishandled. The existing local file is protected, but export encryption is not implemented.
- Whole-model pretty-printed JSON persistence runs on the main actor; multi-year performance needs measurement.
- CloudKit therapist sharing needs real two-account Development and TestFlight checks, including schema, payload limit, notifications, and revocation. It supports one therapist per owner and one client per therapist installation; it is not emergency monitoring.
- Geofence precision, notification delivery, App Group updates while Bull is suspended, and widget refresh timing are iOS-controlled. Layla must publish a valid shared snapshot for its planned timing to be available.
- The v3.3 audit recorded pending privacy-report/App Store disclosure work and physical accessibility checks. Later handovers do not establish that these gates passed.
- Existing sexual-vigour and character/figure progression surfaces remain in source. Removing them will need an explicit migration and UI plan so historical data and widgets are not silently broken.

## Agreed product direction; not yet the current app

- Make Bull a **widget-first relapse-prevention** companion centered on discipline and personal resilience. The widget should make the next useful action easy to see while keeping private details off the Home Screen.
- Use **Self-Control Readiness** as the single headline KPI. It should reflect both observable behaviour and psychological complacency/vigilance. The four current scores remain the implemented model until a separate scoring change is approved.
- Treat **fasting as an optional positive bonus**. Not fasting must not reduce the future KPI or create a missing-data penalty.
- Plan to remove sexual-vigour features and character progression from the future experience. Retain existing records and compatibility until an approved removal/migration specifies otherwise.
- Track completed sleep **independently from Layla** through Apple Health. The proposed sleep-debt view spans seven days and gives the latest three days greater influence. Its target, decay, treatment of missing nights, and exact weights are undecided.
- Evolve physical recovery in a **WHOOP-inspired** direction, prioritising HRV against a personal baseline. The final mix of HRV, sleep, resting heart rate, and training load is undecided; avoid presenting it as a clinical measure or as WHOOP's proprietary algorithm.

### Eleven resilience factors — provisional working taxonomy

The repository does not contain an authoritative agreed list of eleven factors. The following is a **proposal for discussion**, drawn from existing capabilities and the direction above; it is not a scoring specification or permission to implement. Fasting is a bonus, not a required eleventh input.

| # | Candidate factor | Existing evidence / gap |
| --- | --- | --- |
| 1 | Sleep sufficiency and recent debt | HealthKit sleep exists; weighted seven-day debt is proposed. |
| 2 | Physical recovery | HRV/RHR personal baselines and a composite exist; final readiness weighting is open. |
| 3 | Exercise and training balance | Workout import, exercise plans, and manual logging exist. |
| 4 | Nutrition consistency | Bull Fuel logging exists; future role in readiness is open. |
| 5 | Stress regulation | Check-ins and stress-relief logs exist. |
| 6 | Urge intensity and response | Urge observations, support actions, and lapse logs exist. |
| 7 | Risk exposure and environment | Zones, safeguards, and exposure events exist. |
| 8 | Daily discipline and plan follow-through | Routines, priorities, goals, and implementation plans exist. |
| 9 | Psychological vigilance versus complacency | Explicit behavioural/psychological complacency measure is not implemented. |
| 10 | Protective response and recovery after setbacks | Lapse-recovery and damage-control flows exist; final KPI semantics are open. |
| 11 | Accountability and support | Accountability/therapist structures exist; participation and privacy rules need definition. |

Optional fasting would be evaluated outside the required factor set as a non-negative bonus. No missing optional factor should become a disguised penalty. The exact eleven names, measures, data sufficiency rules, scaling, weights, safeguards against double counting, and evaluation criteria require approval before code changes.

## Outstanding work; not implemented as the proposed solution

- **Exercise:** Decide how training consistency, overload, and recovery should affect a single readiness score; current exercise planning/logging does not settle that design.
- **Opal alternatives:** Research feasible, privacy-preserving iOS approaches to distraction/content friction within Apple's APIs. No Opal replacement or system-wide blocking entitlement is present here.
- **Financial integration:** Define whether finances belong in Bull, what data would be collected, and consent/privacy boundaries. No bank or finance integration was found.
- **Rejuvenation programme:** Define its scope, evidence, and relationship to exercise/recovery after sexual-vigour removal. Existing exercise plans are not the proposed programme.

## Source pointers

Start with `Bull/BullApp.swift`, `Bull/ContentView.swift`, `Bull/TodayView.swift`, `Bull/PatternsView.swift`, `Bull/SettingsView.swift`, `Bull/BullStore.swift`, `Bull/Core/Events.swift`, `Bull/Core/V31Logic.swift`, `Bull/HealthKitService.swift`, `Bull/HighRiskZoneService.swift`, `Bull/NotificationService.swift`, `Bull/WidgetSnapshotBridge.swift`, and `BullWidgets/BullWidgets.swift`. For unresolved operational gates, see `Handover/BUILD54-CHANGES-AND-TESTING.md` and `Bull-v3.3-audit-report-2026-08-31.md`; some older handover claims are superseded by the current source.
