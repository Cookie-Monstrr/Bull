# Bull v3.4 · Build 53

## Build 53 compile correction

The follow-up patch adds the missing explicit `import Combine` to `Bull/BullUX.swift`. `BullFeedbackCenter` uses Combine's `ObservableObject` and `@Published`; the missing import caused the compiler errors shown in the supplied screenshot, including downstream diagnostics in dependent views.

Apply `Bull-build53-Combine-fix-updated-files.zip` to the previously supplied Build 53 project, replacing files at their matching paths. It contains only the corrected Swift file and this updated handover. Keep the build number and signing settings as supplied. This patch changes no behaviour, artwork, data fields or app identity.

Validation for this correction: inspected the compiler diagnostics and the affected declarations, parsed the corrected Swift file, and verified the patch contents against the original Build 53 ZIP. An Xcode build remains unverified because this environment has no Apple SDK or Xcode.

## Scope

Build 53 implements the approved appearance, flow and user-experience batch only. It does not change the scoring algorithms, serialized schema, CloudKit model, widgets' privacy payload, artwork, or therapist-sharing scope.

## What changed

- Today now uses one Urge/Bull selector. The chosen pair stays together, and either figure opens the corresponding state/fuel breakdown.
- The four independent score tiles were replaced by a compact figure-first view, a single expandable breakdown, and a domain-aware “Next Step” using the existing priority builder.
- A bottom Log entry point opens a dated logging hub for urge, stress, stress relief, morning erection, Natural Desire, nutrition/fasting, sleep, cardio, strength and lapses.
- Latest urge and Bull State entries can be edited directly from the logging hub. Health can be refreshed from the same place.
- Nutrition and fasting share one editor, preserving the existing fasting behaviour and rest-day exercise suppression. Nutrition changes offer field-scoped Undo.
- Main editors preserve form state and ask before discarding edits. Save confirmation is shown only after the store reports a successful disk write; failed writes expose Retry Save.
- Common card spacing, control heights, corner radii, button treatment, privacy shielding and confirmation feedback were standardised.
- Today, logging and therapist-access rows have larger, visibly tappable targets and stable dated routing.
- User-facing labels were tightened and capitalised consistently. Urge Fuel is presented as Urge Defence; internal storage keys remain unchanged.
- Therapist Oversight now presents access actions separately from a collapsed Sharing Details section, with a shorter explanation and confirmation after sharing options are saved.
- Stats/About wording was shortened and made more direct; chart labels use Defence for Urge and Fuel for Bull.

## Compatibility and identity

- Bundle IDs, App Group `group.com.ahmed.Bull`, CloudKit container, signing/team settings, entitlements, data filenames, schema version and existing user-data fields are preserved.
- This is an update over the installed Bull app. Do not delete the installed app.
- Build number is 53; marketing version remains 3.4.
- Build 52 artwork and all existing widget kinds are unchanged. No relapse data is included in widget payloads.

## Validation performed

- Swift syntax parsed successfully for all 77 Swift source files using tree-sitter Swift.
- Added `BullTests/Build53UXTests.swift` covering paired-domain selection, priority filtering, fasting exercise suppression, recording status, date status, nutrition Undo isolation, combined nutrition/fasting persistence and failed-write retry/no-duplication behaviour.
- Verified the project identity/build settings and that the new source files are covered by the Xcode synchronized groups.
- Reviewed changed user-facing strings for remaining Build-52 terminology in the primary Today, Stats, widgets and therapist-access surfaces.

## Validation limits

This Linux environment has no Xcode, Apple SDK, iOS Simulator, HealthKit runtime, WidgetKit timeline renderer, signing environment or CloudKit account. I could not compile/type-check SwiftUI against Apple frameworks, run XCTest, install on an iPhone, render widgets, exercise HealthKit, or verify a real therapist share. Please build in Xcode and test on the existing installed app with the same signing and App Group configuration before distributing.

## Suggested smoke test

1. Build and install over the existing Bull app without deleting it.
2. Open Today, switch Urge/Bull and tap each figure; confirm the breakdown follows the selected domain/state.
3. Tap Log, edit a previous date, save an urge or Bull State entry, and verify the hub/date remain correct.
4. Open Nutrition & Fasting, save both fields together, confirm fasting removes exercise prompts, then test Undo.
5. Make an edit, attempt to dismiss, and confirm the discard prompt. Temporarily test a failed save path if practical.
6. Open Stats and Therapist Oversight; verify the shortened wording, Preview Therapist View, sharing sheet return path and saved-options confirmation.
