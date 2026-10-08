# Bull Native v3.4 build 48 — Complete Fresh-Chat Handover

## Purpose and source of truth

This archive is the complete current Bull source tree as of 6 September 2026. It is intended
to be uploaded into a fresh ChatGPT conversation before discussing the next improvements.
Open `Bull.xcodeproj`; do not reconstruct the project from individual Swift files.

Treat this document and the source in this archive as authoritative. Older handovers are kept
for design history and migration context, not as the current build state.

Suggested first message in the next chat:

> Read `Handover/START-HERE-FRESH-CHAT-v3.4-BUILD48.md` and inspect the full project before
> changing anything. This is Bull v3.4 build 48. I will now share the improvements I want.

## Release identity

- Product: Bull, native SwiftUI iOS app
- Marketing version: 3.4
- Build number: 48
- Minimum deployment: iOS 17.0
- App bundle ID: `com.ahmed.Bull`
- Widget bundle ID: `com.ahmed.Bull.BullWidgets`
- Unit-test bundle ID: `com.ahmed.BullTests`
- App Group: `group.com.ahmed.Bull`
- CloudKit container: `iCloud.com.ahmed.Bull`
- Main stored payload: `bull-data-v15.json`
- Active four-score version: 9
- Project inventory at handover: 69 Swift files and 178 XCTest methods across 11 test files

## Current product model

Bull helps the owner reduce explicit-content/relapse behaviour while separately tracking
sexual health and physical vigour. The Today screen is organised around four scores:

1. **Urge Routine** — recent protective behaviours and routine inputs.
2. **Urge State** — live/current relapse-risk state.
3. **Bull Routine** — rolling inputs supporting sexual health and physical vigour.
4. **Bull State** — current sexual-health outcomes.

Keep these domains distinct. Therapist Oversight receives only the narrow Urge/Risk projection;
it must never receive Bull Routine, Bull State, sexual-health details, workouts or raw HealthKit
data.

## Latest completed work

### Build 48 — cardio heart-rate zones and active calories

- Bull requests HealthKit read access to Workouts, Heart Rate, Date of Birth and Active Energy.
- Recognised cardio workouts use Apple Watch heart-rate samples when coverage is sufficient.
- Estimated maximum heart rate is `208 − 0.7 × age`.
- Samples are reduced to one mean heart-rate value per elapsed workout minute.
- Zones are classified as:
  - Zone 1: below 60% of estimated maximum; excluded from scored cardio minutes.
  - Zone 2: 60–69%; moderate.
  - Zone 3: 70–79%; moderate.
  - Zone 4: 80–89%; vigorous.
  - Zone 5: 90% or higher; vigorous.
- Heart-rate classification requires coverage of at least half the workout and at least five
  minutes. Otherwise Bull visibly falls back to its workout-type estimate.
- Zones 4–5 retain the existing double moderate-equivalent credit.
- Active calories come from each recognised aerobic workout's HealthKit
  `activeEnergyBurned` statistic, not from the whole-day Move ring.
- Today and Exercise Plan show rolling seven-day active kcal. Log Cardio shows the selected
  day's active kcal and the classification source.
- Active calories are display-only: they do not alter Cardio's 40 points or any Bull score.
- Manual cardio-minute corrections still replace imported minutes without creating duplicate
  sessions; imported calorie provenance remains visible.

Build-48 files changed:

- `Bull/HealthKitService.swift`
- `Bull/Core/Models.swift`
- `Bull/Core/V30Models.swift`
- `Bull/Core/V31Logic.swift`
- `Bull/BullStore.swift`
- `Bull/ExercisePlanView.swift`
- `Bull/TodayView.swift`
- `BullTests/V31Tests.swift`
- `Bull.xcodeproj/project.pbxproj`

See `Handover/HANDOVER-v3.4-BUILD48.md` for the focused implementation and device gate.

### Build 47 — Layla sleep-schedule bridge

- Bull consumes one atomic, versioned schedule file from `group.com.ahmed.Bull`.
- The bridge validates freshness, source identity, time zone, source sequence and replay order.
- Accepted Layla data can anchor Risk Zone windows to actual wake, planned final wake, next
  bedtime and observed sleep state.
- The default Home rule remains inactive during intended sleep, starts after the configured
  post-wake allowance, and ends before the configured bedtime allowance.
- An unexpected or confirmed final wake re-anchors the wake allowance to the actual wake.
- Missing, invalid or stale Layla data fails safely to Bull's existing fixed schedule.
- `Handover/LaylaBullSchedulePublisher.swift` is the drop-in publisher that belongs in the
  Layla app target. It has already been added to the user's Layla project, and App Groups were
  reported enabled for both apps; verify this again during device testing.
- App Group writes cannot launch a fully suspended Bull process. Bull reads on launch,
  foreground and resident opportunities. A future design must make Layla or a server the alert
  owner if a brand-new unexpected-wake event must warn while Bull is fully suspended.

See `Handover/LAYLA-INTEGRATION-v3.4.md` for the wire contract, state mapping and tests.

### v3.4 medium Face Off widget

- Only the approved system-medium `Face Off` widget is registered.
- The Bull figure is left, Devil right, with private label-free scores below them.
- The figures retain the approved large size and share one foot-to-score-line clearance, so the
  smaller Devil does not appear to hover beside the Bull.
- Numbers are horizontally centred in their respective halves.
- Figure stages update from the same Bull State and Urge State scores used by the Today screen:
  below 20 → stage 1, 20–39 → 2, 40–59 → 3, 60–79 → 4, 80–100 → 5.
- Missing scores show an em dash and a faded stage-one figure.
- The widget payload contains only two optional scores and a timestamp. It does not receive the
  main Bull data file, observations, relapse history, HealthKit samples, locations or therapist
  data.
- Widget content is privacy-sensitive. There are no visible labels; private VoiceOver text is
  retained for accessibility.
- WidgetKit may coalesce refreshes. Bull requests reloads after persistence and provides a
  fallback timeline, but cannot guarantee an immediate system refresh.

See `Handover/HANDOVER-v3.4-WIDGETS.md`, `Handover/WIDGET-SETUP-v3.4.md` and
`Handover/VALIDATION-v3.4-WIDGETS.md`.

### Therapist Oversight retained from v3.3/v3.3.1

- Private CloudKit sharing sends only Urge Routine/State, urge observations, counted relapses
  without narrative details, coordinate-free Risk Zone state/settings, monitoring health and
  protected-control proposals.
- Bull Routine/State, vigour, sexual-health data, workout data, raw HealthKit data, exact
  coordinates and free-form sensitive notes are forbidden from the projection.
- Risk Control changes that weaken protection wait for therapist approval; clearly stronger
  changes can apply immediately.
- `No Safeguard Possible` is an exit-only zone and cannot receive false safeguard-completion
  credit.
- Owner Risk Zone warnings use: **“Take action before you regret it!”**
- CloudKit saves and silent pushes are best effort. They are not delivery receipts, emergency
  monitoring or proof that a therapist saw an alert.
- Setup-recovery fixes are present, but real Therapist Oversight use is still gated on Mac build,
  CloudKit schema activation and a genuine two-account/two-device test.

See `Handover/HANDOVER-v3.3.md`, `Handover/CLOUDKIT-ACTIVATION-v3.3.md` and
`Handover/TWO-DEVICE-TEST-v3.3.md`.

### Earlier retained improvements

- Previous days can be selected and ejaculatory-control events can be added, edited and deleted
  while preserving identity, modification time and retrospective provenance.
- Today cards, rolling windows, events, stress logging, experiments, exercise planning, recovery,
  history, patterns, backup/import and high-risk-zone features remain in the project.
- Historical handovers and the v3.3 audit are deliberately included for traceability.

## Important source map

| Area | Main files |
| --- | --- |
| App entry/navigation | `Bull/BullApp.swift`, `Bull/ContentView.swift`, `Bull/TodayView.swift` |
| Central state/persistence | `Bull/BullStore.swift`, `Bull/Core/Models.swift` |
| Scoring and routines | `Bull/Core/Scoring.swift`, `Bull/Core/V27Scoring.swift`, `Bull/Core/V31Logic.swift`, `Bull/Core/Weights.swift` |
| HealthKit/cardio | `Bull/HealthKitService.swift`, `Bull/ExercisePlanView.swift` |
| Layla transport | `Bull/LaylaScheduleBridge.swift`, `Handover/LaylaBullSchedulePublisher.swift` |
| Risk Zones | `Bull/HighRiskZoneService.swift`, `Bull/HighRiskZonesView.swift`, `Bull/RiskZoneMapPicker.swift` |
| Notifications | `Bull/NotificationService.swift`, `Bull/RiskActionDestinationView.swift` |
| Therapist Oversight | `Bull/TherapistCloudService.swift`, `Bull/TherapistOversightViews.swift`, `Bull/Core/V33Models.swift`, `Bull/Core/V33Logic.swift` |
| Widget bridge/view | `Bull/WidgetSnapshotBridge.swift`, `BullWidgets/BullWidgets.swift` |
| Widget/app artwork | `Bull/Assets.xcassets`, `BullWidgets/Assets.xcassets` |
| Tests | `BullTests/` |
| Signing/configuration | `Bull.xcodeproj/project.pbxproj`, `Bull/Bull.entitlements`, `BullWidgets/BullWidgets.entitlements` |

## Data and scoring invariants

- Preserve backward-compatible decoding. Existing users may have older v8–v14 recovery files
  before migration to v15.
- Never silently turn missing HealthKit/Layla data into zero; show unavailable/fallback semantics.
- Active calories are informational and must not affect scores unless the owner explicitly agrees
  to a future scoring redesign.
- Manual corrections must not double-count imported HealthKit workouts.
- The widget must continue publishing the same provisional four-score snapshot used by Today;
  it must not reimplement scoring.
- Do not expand the Therapist Oversight payload without explicit approval and new privacy tests.
- Do not weaken protected Risk Controls through imports, reset, UI shortcuts or migrations.
- Location, sleep, stress and sexual-health relationships should be described as associations,
  not causation.

## Data safety before installing a new build

- Build/install over the existing app with the same bundle ID and signing identity.
- **Do not delete Bull from the iPhone.** Deleting the app previously erased its local data.
- Before risky schema or migration work, make a full Bull backup and store it securely. The full
  backup is plaintext JSON and contains highly sensitive data.
- Keep the same App Group and CloudKit identifiers. Renaming them disconnects widgets, Layla or
  therapist data.
- Do not reset Bull while protected Therapist Oversight is active unless the intended revocation
  succeeds.

## Xcode setup and release gate

1. Open `Bull.xcodeproj` in a current Xcode version.
2. Select the user's Apple Developer team for Bull, BullWidgetsExtension and tests as required.
3. Under Signing & Capabilities, confirm `group.com.ahmed.Bull` is selected for both **Bull** and
   **BullWidgetsExtension**.
4. Confirm Bull has HealthKit, Location, Notifications and iCloud/CloudKit capabilities required
   by the existing project.
5. Confirm the CloudKit container remains `iCloud.com.ahmed.Bull`.
6. Run **Product → Clean Build Folder**, then **Product → Test**. All 178 tests should pass.
7. Resolve warnings/errors without deleting existing user changes or removing the privacy gates.
8. Install over the existing iPhone app. Accept Health access for Workouts, Heart Rate, Date of
   Birth and Active Energy.
9. Open Bull once so it publishes the initial widget snapshot, then add/refresh Face Off.
10. Run the build-48 cardio device checks, the Layla device checks and the widget visual checks.
11. Before real therapist use, complete the CloudKit Development and TestFlight Production
    two-device gates.

## Validation already completed in the handover environment

- Full archive structure and compressed bytes were checked.
- Asset-catalog `Contents.json` files parsed successfully.
- Changed Swift files passed static delimiter/comment/string balance checks.
- The project contains build number 48 for all configurations.
- Build 48 adds regression coverage for active-calorie aggregation, backward-compatible decoding,
  score independence and heart-rate minute-bucket classification.

This environment did not contain Xcode, Swift's Apple SDKs, a simulator, signing or a physical
iPhone. Therefore no claim is made that build 48 compiled or passed XCTest here. The Mac/device
gate above is mandatory.

## Known boundaries and open risks

- Suspended Bull cannot be awakened merely because Layla wrote a new App Group file.
- HealthKit calorie and zone values depend on Apple Watch/Health data quality and are estimates.
- The widget cannot guarantee instant refresh because WidgetKit controls execution budgets.
- Therapist silent pushes can be delayed or suppressed; there is no acknowledged delivery receipt.
- Therapist Oversight is one therapist per owner and one client per therapist installation, not a
  clinic dashboard.
- iOS circular geofences are building-scale and cannot prove room-level presence.
- Full recovery backups remain unencrypted plaintext.
- Whole-model pretty-JSON persistence remains on the main actor and needs a representative
  multi-year performance benchmark.
- Accessibility, Dynamic Type, dark appearance and all notification paths still need physical UI
  validation after significant UI work.

## Deferred roadmap, not yet implemented

- Location-aware stress activities with entry/exit prompts.
- Stressful-event coaching and schedule-aware stress reminders.
- Deeper sleep/urge analysis after enough observed data.
- Strength progression statistics for load, reps, sets and volume.
- Possible post-lapse recovery streak-freeze concept, with anti-gaming rules and no erasure of the
  underlying lapse.
- Encryption for full recovery exports.
- A robust suspended-app owner for unexpected-wake alerts.
- Multi-client therapist support or acknowledged alert delivery.

These are candidates only. The owner plans to provide a new set of desired improvements in the
next chat; inspect those requirements before choosing roadmap work.

## Instructions for the next coding chat

1. Read this document first, then inspect the relevant source before proposing changes.
2. Ask the owner to share the improvements; do not assume the deferred roadmap is approved.
3. Restate the requested scope and identify any conflicts with privacy, scoring or data migration.
4. Preserve unrelated files and all existing data migrations.
5. Make changes in the full project, increment the build number, add focused tests and update this
   handover family.
6. Return either the explicitly requested replacement files or a new complete archive. Do not make
   the owner reconstruct Xcode project changes by hand.
7. Be transparent about what was statically checked versus what was actually compiled or tested in
   Xcode.

## Handover status

Build 48 is source-complete and packaged for continuation. The immediate next activity is not a
preselected feature: it is to receive and assess the owner's improvement list in the fresh chat.
