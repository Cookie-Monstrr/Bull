# v3.1.1 Validation Status

## Completed in This Handover Environment

- Parsed the shared Xcode scheme as valid XML.
- Verified every project object reference resolves and all object identifiers are
  unique.
- Parsed all property lists and JSON assets/fixtures.
- Checked Swift source delimiters and string/comment termination.
- Checked for trailing whitespace and patch-conflict markers.
- Confirmed the app target owns `Bull/Core` directly.
- Confirmed the `BullTests` target and testable reference are in the shared `Bull`
  scheme.
- Confirmed iOS 17 deployment, app version 3.1.1 and build 32.
- Confirmed launch and foreground paths both re-query monitored Risk Zones,
  reconcile occupancy from a current location fix and then evaluate active alert
  windows.
- Confirmed Risk Zone alert behaviour and the local notification test now live in
  Risk Zones rather than the general Settings screen.
- Confirmed Events reads the timestamped Live Urge observation stream, is
  collapsible and contains What Counts as a Lapse.
- Confirmed Add New Trigger and Add New Response appear only in the post-sigh
  reflection phase, with newly created entries selected for the active log.
- Confirmed the visible Settings form contains only Apple Health, Lapse Support,
  Privacy, Data & Backup and About; retired fixed-time Stress reminders are
  cancelled on launch.
- Added a Bull Fuel regression test for the observed 4/20 On Plan and 2/20 Partly
  rolling-window contributions. No score arithmetic changed.
- Confirmed there is no `BullCorePackage`, `BullSplashView`, `import BullCore`,
  `Bundle.module` or local Swift-package reference in the delivered tree.
- Corrected the post-consolidation `riskBreakdown` name collision reported by
  Xcode by renaming BullStore's unused compatibility wrapper to
  `legacyRiskBreakdown`; a static global/instance-name scan now reports no
  remaining collisions.

## Required on a Mac

Apple's Swift compiler, iOS SDK, simulator and `xcodebuild` are not installed in
the handover environment. Open `Bull.xcodeproj` in Xcode and run:

1. `Product > Build` (`Command-B`).
2. `Product > Test` (`Command-U`).
3. Launch on an iOS 17+ simulator and verify the Health, notification and location
   permission prompts appropriate to that simulator/device.

The v3.1.1 test suite covers migration idempotence and history preservation, latest
Live Urge, atomic Bull State, the locked Stress Regulation table, logging-order
independence, prospective-evidence priority, partial Bull Fuel and per-set Strength
credit. Existing import, parity and v2.7–v3.0 regression suites remain in the same
test target.
