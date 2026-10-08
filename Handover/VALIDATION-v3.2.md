# v3.2 Validation Status

## Completed in This Environment

- Confirmed the project remains a single `Bull.xcodeproj` with no new file references.
- Confirmed app version 3.2, build 33 and payload v14 paths.
- Compared the complete v3.2 tree with the supplied v3.1.1 authority and checked the
  patch for whitespace errors and conflict markers.
- Checked delimiter totals on all changed Swift sources; only two unchanged fixture/regex
  files trigger the deliberately simple raw-character check.
- Confirmed no user-facing `porn urge` or `porn-urge` string remains.
- Confirmed Stats titles, data ranges and four-card averages share the selected window.
- Confirmed Top Associations remains sorted by absolute delta and renders `prefix(3)`.
- Confirmed archived experiments are filtered before readiness calculation.
- Confirmed Apple Health sync is absent from the Bull Routine action row and present in
  the shared Today header area.
- Confirmed v14 loader, import, restore, reset and wipe paths use the additive migration.
- Added regression tests for v14 idempotence/history preservation, purpose-sleep weights,
  Vigour fallback, sleep-anchored wake/bed boundaries, planned brief wake, fixed fallback,
  mixed v3.1/v3.2 Stats ranges and archived experiments.

## Required on a Mac

The current environment has no Swift compiler, Apple SDK, simulator or `xcodebuild`, so
the new tests were inspected but could not be executed. In Xcode:

1. Open `Bull.xcodeproj` and select the shared `Bull` scheme.
2. Run Product > Build (`Command-B`).
3. Run Product > Test (`Command-U`).
4. Test upgrade from a real v13 backup and confirm `bull-data-v14.json` plus the preserved
   v13 generation.
5. On an iOS 17+ device, sync Health and verify both purpose scores update while the shared
   status row reports the check.
6. Verify 7D/30D/1Y/All Stats titles, points and top-card values; verify 30D/90D Sexual
   Health labels and bottom scrolling above the tab bar.
7. Inject trusted Layla fixtures for sleeping, planned brief wake, unexpected final wake,
   post-wake allowance, active daytime and pre-bed allowance. Verify pending repeats are
   cancelled when the effective zone becomes inactive.
8. Re-test Health, notification and Always Location permissions on a physical iPhone.

The full automatic already-inside-Home unexpected-wake scenario is not release-validated
until the transport/notification-owner decision in `LAYLA-INTEGRATION-v3.2.md` is built.
