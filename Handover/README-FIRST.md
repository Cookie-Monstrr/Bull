# Bull Native v3.4 build 50 — Start Here

Build 50 adds all twenty approved figure stages to the app and widgets. It keeps
build 49's three-tab/six-chart Stats redesign, Today's Priorities widget, score
alignment changes and End Access repair. Read
`Handover/BUILD50-CHANGES-AND-TESTING.md` first. There are now three medium widget
choices: Face Off, Build & Protect, and Today's Priorities.

This is source for Xcode/device testing, not a compiled or signed release. Install
over the existing app with the same identity; do not delete Bull or clear its data.
The remainder below records the inherited build-48 baseline, not build-50 validation.

## Inherited build-48 handover

Open `Bull.xcodeproj`. The package contains one Xcode project, one app target, one
WidgetKit extension and one unit-test target. It keeps the v3.3.1 and earlier handovers
as historical records.

Read these files first:

1. `Handover/START-HERE-FRESH-CHAT-v3.4-BUILD48.md`
2. `Handover/HANDOVER-v3.4-BUILD48.md`
3. `Handover/HANDOVER-v3.4-WIDGETS.md`
4. `Handover/LAYLA-INTEGRATION-v3.4.md`
5. `Handover/WIDGET-SETUP-v3.4.md`
6. `Handover/VALIDATION-v3.4-WIDGETS.md`
7. `Bull-v3.3-audit-report-2026-08-31.md` at the package root
8. `Handover/HANDOVER-v3.3.md`
9. `Handover/CLOUDKIT-ACTIVATION-v3.3.md`
10. `Handover/TWO-DEVICE-TEST-v3.3.md`

## Release identity

- Marketing version: 3.4
- Build: 48
- Deployment target: iOS 17+
- Data payload: v15 in `bull-data-v15.json`
- Active four-score version: 9 (unchanged)
- Test inventory: 178 XCTest methods across 11 Swift test files

## Current decision

The v3.4 source implementation and static review are complete. Owner review selected `Face Off`
as the sole system-medium widget; the two rejected medium alternatives and all earlier small
candidates have been removed. Build 46 restored the approved restrained reference, unchanged in
build 47: large Bull and Devil artwork above a slim full-width score footer, an oxblood gradient,
subtle background circles
and fine divider rails. The supplied figures retain their size and share one foot-to-score-line
clearance, making them appear grounded on the same floor across all ten artwork stages. It remains
private and label-free. Complete the Xcode, signing, preview and physical-device gates before
distributing it.

The v3.3.1 Therapist Oversight setup-recovery patch remains present. Therapist Oversight is
still not cleared for real use or external testers until the existing Mac and two-device gates
pass.

Build 47 adds the real Bull-side Layla App Group transport and a drop-in publisher for the
Layla target. Layla must add the supplied publisher and join `group.com.ahmed.Bull` before
live schedules arrive. An App Group write still cannot wake a fully suspended Bull process;
the final unexpected-wake alert-owner decision remains a physical-device gate.

Build 48 adds heart-rate-zone cardio classification when Apple Watch coverage is sufficient,
an explicit workout-type fallback when it is not, and Apple Health active calories from
recognised cardio workouts. Calories are shown for the selected day and rolling seven days;
they are display-only and do not change any Bull score.

## Data safety

Opening v3.3 migrates v14 data additively to v15 and keeps v14 through v8 recovery files.
Full backup import and undo-import are locked while owner Risk Controls are protected.
Reset first confirms CloudKit revocation; if revocation fails, Bull keeps local data and
protection in place.

Full backup JSON remains unencrypted and highly sensitive. The redacted trends export is
safer for manual review but is not the Therapist Oversight transport.

The widget transport is deliberately narrow: it contains only today's Bull State and Urge
State scores plus an update timestamp. It contains no visible labels, observations, HealthKit
samples, sexual-health details, relapse data, notes, locations or therapist data. A therapist-
role installation clears any previous owner widget payload.
