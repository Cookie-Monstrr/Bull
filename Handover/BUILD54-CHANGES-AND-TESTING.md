# Bull v3.4 · Build 54

## Scope

Build 54 is the authorized update over the installed Build 50 baseline, carried through
the Build 53 UI correction. It covers the agreed appearance, flow, notification, Risk
Zone persistence and therapist-readiness work. The relapse-risk forecasting model remains
parked for a later feasibility discussion; this build does not predict relapse or send
forecast alerts.

## What changed

- Today and the paired widgets show the provider and state figure together for the chosen
  domain: Bull Fuel + Bull State, or Urge Fuel + Urge State. The Urge Defence label is now
  Urge Fuel throughout user-facing app, Stats and widget surfaces.
- The dark Sorcerer progression is corrected so a low Urge Fuel score uses the weakest
  appearance and a high score uses the strongest appearance. Figure thresholds are now
  deliberately steep: 0–39, 40–59, 60–74, 75–89 and 90–100.
- The red-gradient figure cards remain figure-first, with the redundant “In Progress”
  status removed. The Today Urge/Bull selector is a fully tappable two-button control;
  tapping either side switches domains without requiring a drag.
- The Bull Fuel editor keeps food-plan adherence and Fasting as independent choices.
  Fasting records the existing rest-day bonus and suppresses planned cardio/strength
  prompts in Today and in the daily-input queue. Existing fasting data and scoring fields
  remain intact.
- Strength logging adds Complete All Planned Sets / Clear Planned Sets. It changes only
  planned-set completion and preserves recorded weights, repetitions and extra sets.
- The Stats cards keep the clearer axis labels, day selection and explicit Show/Hide
  controls for each line. Urge Overview and the sleep/HRV cards expose relapse markers
  where relevant; the relapse series is toggled separately. The old front-page state trend
  graph and the confusing shortfall/reconstructed-component footers are not used.
- Medium 30-day Urge Overview and Urge Fuel Breakdown widgets were added. They include
  readable Date and Score axes, compact values in the legend, the red-gradient treatment,
  privacy-sensitive rendering and deep links back to the corresponding Stats page.
- A device-local Daily Input Queue can send one unfinished-input reminder at a time. A
  notification opens the dated editor for that item; after save, the next reconciliation
  advances the queue. Settings expose enable/disable, 15/30/60/120-minute cadence, active
  hours, pause-for-today and input categories. Notification delivery is disabled for the
  therapist role. Trusted Layla wake/bedtime snapshots anchor sleep-related timing, with
  the existing safe fallback when Layla is unavailable.
- Morning Erection and Natural Desire remain visible as separate rows after either one is
  saved. The morning erection editor has the requested optional duration timer, while the
  duration remains observational and does not alter the existing score model.
- Risk Zone add/edit writes now verify the saved JSON and roll back the in-memory edit if
  persistence cannot be confirmed. Startup/foreground reconciliation removes orphaned
  iOS notifications and rechecks configured monitored regions. A stale notification opens
  a concise inactive-alert screen with paths to Risk Zones or Urge Support instead of
  implying that the current zone was deleted.
- Therapist Oversight and Layla status surfaces were reviewed. The existing private share
  flow, role gating, redacted projection and CloudKit audit/outbox behaviour are preserved;
  the new status/repair affordances make stale monitoring and Layla schedule state visible.

## Compatibility and identity

- App bundle ID: `com.ahmed.Bull`.
- Widget bundle ID: `com.ahmed.Bull.BullWidgets`.
- App Group: `group.com.ahmed.Bull`.
- Development team/signing configuration, entitlements, CloudKit container, data filenames,
  serialized `BullData` schema (v15), existing user-data fields and widget privacy contract
  are preserved. New reminder settings are device-local preferences, not BullData fields.
- Marketing version remains 3.4; project build number is 54 in all six configurations.
- This is an in-place update for the installed Bull app. Do not delete the installed app.

## Source-level validation performed

- Ran `Handover/validate_build54.py`. It checks all property lists/entitlements and JSON,
  six Build 54 configurations, identity/signing values, synchronized `SharedFigures`
  membership, five widget registrations, the v15/four-score contracts, the 20 shared
  figure assets and the no-relapse widget payload contract.
- Added `BullTests/Build54Tests.swift` for steep figure bands, Sorcerer asset reversal and
  daily-input route parsing. Existing Build 49–53 regression tests remain in the project.
- Reviewed changed strings in Today, Stats, widgets, therapist surfaces and Risk Zones;
  generic “In Progress”, stale “Archived zone” and old “Urge Defence” labels are absent
  from Swift source.

## Validation limits

This environment has no Xcode, Apple SDK, iOS Simulator, Swift compiler, WidgetKit
timeline renderer, HealthKit runtime, Core Location runtime, signing environment or
CloudKit account. The Build 54 validator is dependency-light and checks source contracts;
it does not type-check SwiftUI/Charts/UserNotifications/CoreLocation, run XCTest, install
on an iPhone, render a widget on-device, exercise Layla's App Group publisher, verify a
real geofence transition, or complete a two-account therapist share. Those checks must be
performed in Xcode on the existing installed app with the same signing and App Group
configuration before distribution.

## Suggested smoke test in Xcode

1. Build and install over the existing Bull app without deleting it. Confirm the bundle ID,
   team and App Group match the installed target.
2. On Today, tap Urge and Bull (including the right half of the control), tap each paired
   figure, and confirm the selected breakdown follows the pair. Confirm no status text
   appears below the figures.
3. Open Nutrition & Fasting, save both choices, verify the Fasting rest-day indicator and
   that planned cardio/strength prompts are suppressed. Open Strength and try the complete/
   clear planned-set control without changing weights or extra sets.
4. Enable Daily Input Reminders, grant notifications, send the test notification, tap it,
   save the opened editor, then confirm the next unfinished input is scheduled. Test pause,
   active hours and a fasting day.
5. Open Stats, switch Overview/Breakdown/Relapses, tap and drag a chart, use every Show/Hide
   control, and check the relapse toggle only appears on the relevant cards. Add the two
   medium widgets and verify axes, values, paired figures, privacy and deep links.
6. Create, edit, disable and re-enable a Risk Zone; restart Bull and run Device Check.
   Confirm the zone remains, monitoring matches configuration and an old delivered alert
   cannot claim that a current zone was deleted.
7. In Therapist Oversight, preview the therapist view, open/close the sharing sheet and
   confirm the access page remains available. Test with a real second account/CloudKit
   environment before relying on therapist delivery.
