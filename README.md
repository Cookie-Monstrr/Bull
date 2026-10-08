# Bull 3.4 · build 50 source package

Build 50 installs the approved 20-stage figure library, adds the routine-figure
widget and brings the same four figures into Today. Start with
`Handover/BUILD50-CHANGES-AND-TESTING.md` and inspect
`Handover/BUILD50-FIGURE-WIDGET-PREVIEW.png`.

## Inherited build49 baseline

Open `Bull.xcodeproj` and read `Handover/BUILD49-CHANGES-AND-TESTING.md`.

Implemented: six charts across Overview, Breakdown and Sleep / HRV; weighted
Today's Priorities medium widget; Face Off score placement; End Access repair.
Build 50 retains every build 49 change, including the Stats redesign, priority
widget and End Access repair.

Source/static checks only in this environment. Xcode compilation, XCTest and
physical-device verification are still required before distribution. Build 50
has not been pushed, signed or installed remotely.

Keep the same app identity and install over the existing Bull app. Export a
backup first; do not delete the app. Data payload v15 and score version 9 are
unchanged. Historical handovers are retained for context.
