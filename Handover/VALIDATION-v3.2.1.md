# v3.2.1 Validation Status

## Completed Statically

- Compared the v3.2.1 tree with the supplied v3.2 authority.
- Confirmed one Xcode project, app target and unit-test target.
- Confirmed marketing version 3.2.1, build 34, payload v14 and score version 9.
- Added `BullTests/V321Tests.swift`; total inventory is 153 XCTest methods.
- Added tests for legacy correction metadata, revised snapshot round trips, deterministic
  equal timestamps, monotonic Layla input, Risk Zone copy/privacy, bounded follow-ups,
  import size/skips and redacted-export exclusions.
- Confirmed JSON fixtures parse and the entitlement plist is well formed.
- Checked changed Swift files for conflict markers and balanced delimiters.
- Checked the project for remaining slash-separated SwiftUI control titles.
- Checked the final ZIP structure and archive integrity after packaging.

## Not Executed Here

This environment has no Swift compiler, Apple SDK, simulator, Xcode or `xcodebuild`.
Therefore no claim is made that the project compiled, that XCTest passed, or that iOS
delivered a notification/location/Health result. These checks require a Mac and iPhone.

## Required Mac Gate

1. Open `Bull.xcodeproj` and select the shared `Bull` scheme.
2. Run Product > Clean Build Folder, then Product > Build (`Command-B`).
3. Run Product > Test (`Command-U`) and confirm all 153 tests pass.
4. Run Product > Analyze and resolve any new warning.
5. Archive Release once; verify the signed app contains HealthKit and Time Sensitive
   Notifications capabilities and review Xcode's privacy report.

## Required Physical-iPhone Gate

Use `TONIGHT-CHECKLIST-v3.2.1.md`. At minimum cover:

- upgrade without loss and successful full/redacted export;
- previous-day ejaculatory control add, edit and delete;
- past Urge/Bull State corrections and revision display;
- past Stress Relief date;
- authentication success, cancellation and background shield;
- Risk Zone private/detailed copy, snooze and bounded repeats;
- When In Use foreground zone refresh and Always background monitoring;
- Health request, empty/denied state and 90-day sync;
- dark appearance, large text and VoiceOver labels.

## Stop Conditions

Do not distribute if the build or any test fails, data moves to the wrong day, a private
notification exposes Bull/place/safeguard details, authentication opens after failure, or
Snooze produces duplicate alerts. Preserve the v3.2 archive and exported device backup for
rollback.
