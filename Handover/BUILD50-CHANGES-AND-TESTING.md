# Bull Native v3.4 build 50 — changes and testing

Date: 2026-09-07

Build 50 is a complete source handover. It has not been pushed, signed or
installed. Install over the existing Bull app with the same signing identity;
do not delete the app or clear its data.

## What changed

- Added twenty true-transparency character assets: Bull State, Bull Routine's
  Provider, Urge State's Devil, and Urge Routine's Angel, with five stages each.
- One shared score-to-stage implementation now drives both the app and widgets:
  0–19.999 = 1, 20–39.999 = 2, 40–59.999 = 3, 60–79.999 = 4,
  and 80–100 = 5. Values are clamped to 0–100; missing or non-finite scores show
  no stage rather than falsely showing the weakest figure.
- Today's figure card now has States and Routines modes. States show Bull and
  Devil; Routines show Provider and Angel. Historical dates use the selected
  day's four-score snapshot consistently.
- The existing Face Off medium widget now uses the new Bull and Devil figures.
  A new Build & Protect medium widget shows Provider and Angel. Today's
  Priorities remains the third medium widget.
- The widget payload remains deliberately narrow: four scores and a timestamp.
  Older two-score payloads remain decodable. Yesterday's scores blank at the
  next civil midnight, and routine-only score changes trigger widget refreshes.
- Figure scores have an explicit footer whose text is centred horizontally and
  vertically between its separator and the widget's lower edge.
- `ContentView` is divided into small opaque view layers for the app shell,
  lifecycle observers, monitoring observers, CloudKit events and presentation.
  This resolves Xcode's "unable to type-check this expression in reasonable
  time" error without changing the view hierarchy or event behaviour.
- Added an explicit WidgetKit `Info.plist` containing the required nested
  `NSExtension` dictionary. The synchronized group excludes this plist from
  copied resources and both widget configurations use it as their processed
  plist. This fixes the device installer error
  `AppexBundleMissingNSExtensionDict`.

Build 49's six minimalist Stats charts, priorities widget, Face Off alignment
work and Cancel Oversight / End Access repair are preserved unchanged.

## Artwork

The approved sheets are preserved under `Approved-Figures`. Production images
live in `SharedFigures/Figures.xcassets` and are available to both the app and
WidgetKit extension. Every image is a 512×768 RGBA PNG with transparent space,
a common torso centre and boot baseline, and original rendering intent.

The Angel's pale feathers and narrow spears were reviewed against ivory and
oxblood backgrounds during extraction. The mock-up in
`BUILD50-FIGURE-WIDGET-PREVIEW.png` uses the production assets and mirrors the
SwiftUI widget geometry; it is not a WidgetKit or simulator screenshot.

## Automated/static checks completed

- All 20 expected asset names exist exactly once and pass the installer checks
  for dimensions, RGBA mode, transparent space, opaque artwork and safe edges.
- SharedFigures is attached to the app and widget targets.
- All six Xcode build configurations use build number 50.
- Swift sources parse with no syntax errors; the Xcode project and property
  lists parse, including the WidgetKit extension point; asset-catalog JSON
  parses.
- 209 XCTest methods exist across 13 test files, including seven build-50 figure
  regression tests. The tests were source-checked but not executed here.
- App identity, App Group, data payload version 15 and score version 9 are
  unchanged.

Xcode, the Apple SDK, a simulator and a physical device are unavailable in this
environment. A real Xcode compile, XCTest run and widget rendering check remain
required before distribution.

## Device test checklist

1. Back up Bull data. Install build 50 over the existing app; never delete it.
2. Build the app, widget extension and BullTests in Xcode; resolve signing using
   the existing team and `group.com.ahmed.Bull` App Group.
3. Open Today and switch States/Routines. Check stages around 0, 20, 40, 60, 80
   and 100, a historical day, and missing scores.
4. Add Face Off, Build & Protect and Today's Priorities as medium widgets, then
   stack the two figure widgets. Confirm feet, figures and scores remain centred
   and clear of every border at the actual device's display scale.
5. Change only Bull Routine and only Urge Routine. Confirm Build & Protect
   refreshes. Cross midnight and confirm stale scores disappear.
6. Enable privacy shielding/biometric lock and confirm widget redaction and deep
   links still respect the existing privacy gate.
7. Re-test the build 49 acceptance cases: six Stats charts and filters,
   priorities ordering/weights, Cancel Oversight followed by End Access, and no
   regression to existing Bull data.

If artwork needs optical adjustment after the device test, edit only the source
assets or layout; do not change the score bands or data schema without a new
explicit decision.
