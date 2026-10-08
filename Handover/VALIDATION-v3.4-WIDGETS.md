# Bull v3.4 Widget Validation Record

## Completed in this environment

- Read the v3.3.1 handover, audit, score UI and persistence path before changing source.
- Confirmed Today uses `bullState` for the Bull figure and `urgeState` for the Devil figure.
- Reused the exact ten existing figure assets and the exact five score-band thresholds.
- Added a dedicated WidgetKit extension and embedded it in the Bull app target.
- Added the same App Group identifier to both entitlements and target capabilities.
- Limited the shared payload to two optional scores and one timestamp.
- Published only after a successful Bull data write and cleared the payload in therapist role.
- Added the final system-medium Face Off widget registration with no visible labels.
- Removed the three small candidates after owner review.
- Removed Night Stage and Light Gallery after Face Off received owner approval.
- Kept Face Off's fixed, separate figure and score zones with no negative spacing.
- Restored the owner-supplied approved reference design after the alternate aura treatment was
  rejected.
- Verified all ten 512×512 artwork assets share a visible bottom edge at pixel 444 or 445.
- Kept the shared artwork zoom at 1.20 and applied one ten-point vertical offset so every Bull and
  Devil stage has the same foot-to-score-line clearance.
- Preserved the restrained oxblood gradient, broad background circles, fine centre divider and
  slim full-width score footer from the approved reference.
- Added `privacySensitive()` and consolidated VoiceOver descriptions.
- Replaced shorthand switch-result expressions with explicit returns after Xcode reported five
  unused integer literals and a missing return in `scoreBand`.
- Added the Bull-side Layla App Group reader and the self-contained Layla publisher using one
  atomic, versioned schedule envelope in `group.com.ahmed.Bull`.
- Added strict source, sequence, timestamp, time-zone, day-key, state and 64 KiB payload checks;
  invalid/stale/replayed updates preserve the last accepted schedule or fixed-hour fallback.
- Corrected pre-final-wake brief-wake validation and pre-scheduled its return deadline so an
  overdue planned wake fails safe even after Bull is suspended.
- Added connection state, source version, sequence and schedule time-zone diagnostics to Risk
  Zone setup.
- Added five XCTest methods for global monotonic ordering, valid envelope decoding, invalid
  time-zone/day rejection, brief-wake deadline behavior and required actual-wake timing.
- Bumped the app, test and extension targets to version 3.4 build 47.
- Parsed every asset-catalog `Contents.json`, both entitlement plists and the shared scheme.
- Checked project-object references, build phases, target dependency and extension embedding
  structurally.

## Still required on the Mac

1. Resolve automatic signing for the new App Group and widget bundle identifier.
2. Build Bull and BullWidgetsExtension with the Apple SDK.
3. Run all 174 XCTest methods and Xcode Analyze.
4. Render the Face Off preview at the real system-medium size. Confirm both figures have visible
   edge clearance, the full-width score footer has clear bottom spacing, the fine dividers remain
   subtle and no score intersects a figure at any supported content scale.
5. Install on iPhone, open Bull once, and verify real scores replace the em dashes.
6. Change Live Urge and Bull State independently and confirm only the intended number and
   figure update.
7. Enter therapist role on a dedicated test installation and confirm widgets clear.
8. Test locked-device redaction, VoiceOver, Larger Text, light/dark wallpaper and StandBy.
9. Archive and inspect that `BullWidgetsExtension.appex` is embedded and signed with the same
   App Group entitlement as Bull.
10. Add `LaylaBullSchedulePublisher.swift` to Layla, enable `group.com.ahmed.Bull`, then complete
    every device check in `LAYLA-INTEGRATION-v3.4.md`, including stale/replay/DST and locked-phone
    cases.

This environment has no Apple SDK, Swift compiler, simulator, signing identity or physical
iPhone, so it cannot claim an Xcode compile or runtime pass.
