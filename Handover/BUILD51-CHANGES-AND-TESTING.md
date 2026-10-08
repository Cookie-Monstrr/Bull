# Bull Native v3.4 build 51 — changes and testing

Date: 2026-09-07

Build 51 is based directly on the supplied, installed-and-running Build 50 project.
It has been updated and packaged locally only. It has not been pushed to a remote,
signed, installed or distributed.

Install Build 51 over the existing Bull app with the same signing identity. **Do not
delete the installed Bull app or clear its data.**

## Identity and data compatibility

- App: com.ahmed.Bull
- Widget extension: com.ahmed.Bull.BullWidgets
- Tests: com.ahmed.BullTests
- App Group: group.com.ahmed.Bull
- CloudKit container: iCloud.com.ahmed.Bull
- Development team: 8LT6DKBQL7
- Marketing version: 3.4
- Build number: 51 in all six configurations
- Main data file/envelope: bull-data-v15.json / payload version 15

No record collection was deleted or renamed. Build 51 adds optional fields for the
new Bull State entry type, observed erection duration and the Build 51 score-era start.
Build 50 data decodes without those fields. Existing score-version-9 history stays
frozen; Build 51 begins score version 10 without recomputing prior finalized scores.

## Figure cards and figure widgets

- Urge is now a domain pair: Urge Routine Angel on the left and Urge State Devil on
  the right.
- Bull is now a domain pair: Bull Routine Provider on the left and Bull State Bull on
  the right.
- Today's selector is Urge | Bull and defaults to Urge.
- The two existing widget kind identifiers are unchanged so installed widgets can
  update in place.
- Figure widgets restore the deeper red gradient, subtle background shapes, centre
  divider and separate score footer from the approved earlier design.
- The small rolling/daily descriptions below Today's figures were removed.
- The Today State Trend card was removed; its stored history was not deleted.
- Production figure assets and score-to-stage bands are unchanged. Figure choice
  review remains deliberately deferred.

## Fasting

- Fasting Today is a compact independent control in the Bull Fuel section. Bull Fuel
  adherence remains independently selectable as On Plan, Partly or Off Plan.
- Fasting marks the day as a rest day. Today's Priorities does not request cardio or
  strength on that day.
- A scheduled strength session is excused from the rolling denominator when no
  strength work is completed on the fasting day. If completed sets are logged, the
  workout is included. Cardio performed while fasting continues to count toward the
  unchanged weekly target.
- Fasting adds a capped **+10 Fasting Protection** bonus to Urge Routine.
- The existing durable checks["fasting"] record is reused. Stats shows fasting as a
  personal factor and the old fasting record is not duplicated.
- The UI makes no dopamine or testosterone claim. The bonus reflects the user's
  reported experience and is not presented as a clinical effect.

## Bull State and erection duration

- The previous just-woken combined question is split into:
  - Morning Erection, recorded after waking; and
  - Natural Desire, recorded later in the day with None/Low/Moderate/High/Very High
    choices and wording that separates it from porn-driven urges.
- Bull State is now 70% Morning Erection and 30% Natural Desire.
- Multiple wake entries still produce one daily erection component: the strongest
  informative wake is used once, so extra wakes never add weight.
- If an erection is observed, an optional timer can run across ordinary app
  backgrounding by calculating from its start date. Manual duration in minutes is
  also available.
- Duration is stored but **does not affect Bull State in Build 51**. A self-timed
  after-waking duration is not equivalent to clinical nocturnal monitoring. Revisit
  scoring only after enough consistent personal observations have been collected.
- Existing combined Build 50 Bull State entries remain readable and editable.

## Stats

- The third tab is now Relapses; cards use Sleep & Relapses and HRV & Relapses.
- Overview cards show explicit labels such as Routine Average and 2 Recorded Days;
  /100, Score / 100, Values: period averages and Completed days · through yesterday
  were removed.
- Every chart uses labelled Show/Hide controls rather than unexplained legend dots.
- Tap or drag selects the nearest day and opens a prominent dated value panel.
- Urge Overview has an independent Relapses control. Relapses are red diamonds/rules,
  not a misleading 0–100 line.
- The same card layout, controls and date inspection apply to Bull, routine-breakdown,
  Sleep and HRV charts. Useful units remain visible.
- Shortfall ranking and its reconstructed-component footer were removed.
- About These Charts is now an obvious button with short explanations of interaction,
  gaps, score timing, relapse diamonds and older estimated component points.
- A wider copy/capitalisation pass removed cited jargon and standardised visible titles.
  Essential privacy, deletion and safety warnings remain.

## New graph widgets

- Added two medium widgets:
  - Urge Overview · 30 Days
  - Urge Routine Breakdown · 30 Days
- Both have 0/50/100 y-axis values, start/middle/end date labels, named series and
  period averages.
- Widget taps open the matching Stats page in the 30-day window.
- The first release is intentionally fixed to 30 days; WidgetKit does not provide an
  in-place time-window control here.
- The widget extension receives only a narrow 30-point derived payload. It does not
  receive BullData, raw observations, HealthKit samples, notes, zones or relapse
  dates/markers. The in-app Urge chart still supports relapse markers.

## Today's Priorities

- Removed visible U/B weight badges and the U: protection · B: building · weights
  footer from the widget and priorities page.
- Internal ranking remains intact; only the unexplained display was removed.
- Fasting rest days suppress cardio and strength prompts.

## Therapist Oversight

- Saving participant or permission changes no longer immediately clears the prepared
  share and resets the flow.
- Dismissing Apple's share controller returns to the same Bull access page.
- The page distinguishes Not Invited, Pending and Active.
- Actions are explicitly Invite via Email or Manage Access, with visible preparation,
  saved, waiting, active and failure messages.
- Bull continues to enforce one private read-write therapist participant because the
  therapist must submit protected Risk Control decisions.
- Apple owns the system invitation UI and its available delivery activities. Device
  testing must confirm Mail delivery and the exact iOS presentation.

## Static validation completed

- 74 Swift files parse with no syntax errors.
- The Xcode project, four property lists/entitlements and all JSON files parse.
- All 20 production RGBA figure assets retain the expected dimensions/transparency.
- All six configurations use build 51; five widgets are registered.
- Identity, App Group, CloudKit container and signing team strings are unchanged.
- Payload v15 is unchanged; score version 10 and its new-era gate are present.
- The graph-widget contract contains no relapse field.
- 215 XCTest methods exist across 14 files, including new Build 51 coverage for fasting,
  rest-day priorities, split Bull State, duration non-scoring, Build 50 decoding,
  frozen score history and widget privacy.

Xcode, Apple SDKs, a simulator, a physical device, HealthKit and a live CloudKit account
are unavailable here. Therefore Swift sources were parsed but not type-checked by Xcode,
XCTest was not executed, and widget rendering, background timer behaviour, signing,
email invitation delivery/acceptance and install-over data retention were not observed.

## Device acceptance checklist

1. Back up Bull data. Open the project in Xcode and install Build 51 **over** the current
   app using the existing team, bundle identifiers, App Group and CloudKit container.
   Do not delete Bull.
2. Confirm existing days, logs, plans, zones, Therapist Oversight state and Build 50
   figures remain present. Build and run the app, widget extension and BullTests.
3. On Today, verify Urge defaults to Angel + Devil and Bull shows Provider + Bull.
   Check the restored red widget geometry on the actual iPhone scale.
4. Set Bull Fuel and Fasting Today independently. Confirm fasting adds 10 Urge Routine
   points without exceeding 100 and that Today's Priorities shows no cardio/strength
   demand. Log exercise and confirm it still counts.
5. Log a Morning Erection, start the timer, background/foreground Bull, stop it and
   confirm elapsed duration. Test manual minutes. Confirm duration changes do not alter
   the score. Later, log Natural Desire and confirm the 70/30 result.
6. In Stats, test every time window and chart. Show/hide each series, tap and drag to
   several dates, and toggle relapse diamonds on Urge, Sleep and HRV charts.
7. Add both new medium graph widgets. Confirm axes/date labels/averages are readable,
   no relapse marker is visible, and each opens its matching 30-day Stats page.
8. In Therapist Oversight, invite through Mail, return to the unchanged access page,
   confirm Pending then Active after acceptance, reopen Manage Access, change access
   options, and confirm the page still remains available. Verify actionable errors with
   iCloud/Mail unavailable.
9. Re-run Build 50 regression checks: midnight widget blanking, privacy shielding,
   historical corrections, Health sync, Risk Zones, import/export and oversight
   cancellation/end-access behaviour.

## Changed source files

- Bull.xcodeproj/project.pbxproj
- Bull/BullStore.swift
- Bull/Components.swift
- Bull/ContentView.swift
- Bull/Core/Models.swift
- Bull/Core/V30Models.swift
- Bull/Core/V31Logic.swift
- Bull/ExercisePlanView.swift
- Bull/GuideView.swift
- Bull/ItemInfo.swift
- Bull/ItemManagementView.swift
- Bull/PatternAnalyzer.swift
- Bull/PatternsView.swift
- Bull/PersonalExperimentManagerView.swift
- Bull/SexualCheckInView.swift
- Bull/TherapistCloudService.swift
- Bull/TherapistOversightViews.swift
- Bull/TodayView.swift
- Bull/WidgetSnapshotBridge.swift
- BullTests/Build51Tests.swift
- BullTests/V31Tests.swift
- BullTests/V321Tests.swift
- BullWidgets/BullWidgets.swift
- SharedFigures/BullFigureArtwork.swift

Build 51 documentation adds this handover, BUILD51-STATIC-VALIDATION.txt and
validate_build51.py.
