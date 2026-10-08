# Bull Native v3.4 Final Face Off Widget Handover

## Outcome

v3.4 adds a WidgetKit extension with one approved system-medium widget: **Face Off**. It is the
only Bull entry registered by the extension.

`WIDGET-FINAL-PREVIEW-v3.4.png` is a quick final mock-up made from the exact shipped artwork and
palette. It is a layout reference, not an Apple-rendered SwiftUI screenshot;
the Xcode Canvas and iPhone remain authoritative for final spacing and system treatment.

### Final design

**Face Off** places the Bull on the left and Devil on the right, with both scores in a slim,
full-width footer beneath the figures. Build 46 restores the owner-supplied approved reference
design: restrained oxblood gradient, broad low-opacity background circles, cream score type and
fine centre/footer dividers. There are no visible labels.

The common artwork zoom remains 1.20. The ten 512×512 source assets have a visible bottom edge at
pixel 444 or 445, despite their different heights and transparent space above. A shared ten-point
vertical offset therefore gives every stage the same visual foot-to-score-line clearance, with a
maximum source variation of one pixel. The Bull position remains unchanged; the Devil is lowered to
the same visual floor.

Night Stage, Light Gallery and the earlier small candidates were removed after owner approval.

## Privacy behavior

- The widget does not render `Bull State`, `Urge State`, `Bull`, `Devil`, `urge`, `porn`, `relapse`
  or any other explanatory label on the Home Screen.
- Widget content is marked `privacySensitive()` so iOS can redact it in privacy-sensitive
  locked contexts.
- VoiceOver still receives meaningful private accessibility text; removing that would make
  the widget inaccessible without improving ordinary shoulder-surfing privacy.
- Only two optional `Double` values and an update timestamp cross the App Group boundary.
- The widget never decodes the main `BullData` file.
- A therapist-role installation clears the score projection so a device repurposed for the
  therapist cannot keep showing an owner's old scores.

## Score fidelity

The app publishes the same provisional `FourScoreSnapshot` used by the Today screen after
every successful model persistence. The figures use the same five bands as the app:

- below 20 → artwork 1;
- 20–39 → artwork 2;
- 40–59 → artwork 3;
- 60–79 → artwork 4;
- 80–100 → artwork 5.

The Bull figure uses `bullState`; the Devil figure uses `urgeState`. Missing values show an
em dash and a faded first-stage figure, matching the existing Today-screen convention.

## Main files

- `Bull/WidgetSnapshotBridge.swift` — narrow app-to-widget publisher and timeline reloads.
- `BullWidgets/BullWidgets.swift` — provider, final Face Off view, registration and preview.
- `BullWidgets/Assets.xcassets` — widget-target copies of the ten existing state figures.
- `Bull/Bull.entitlements` and `BullWidgets/BullWidgets.entitlements` — shared App Group.
- `Bull.xcodeproj/project.pbxproj` — extension target, embedding, signing and current build wiring.

## Deliberate boundaries

- Widgets are read-only. Tapping one opens Bull normally; no lock-screen action or urge-log
  button was added.
- WidgetKit controls the exact refresh time. Bull requests an immediate reload when either
  score changes and supplies a 30-minute fallback timeline, but iOS may coalesce refreshes.
- The widget does not compute scores independently. Bull must be opened after upgrading at
  least once to publish the initial projection.
- No widget preference is needed because only the approved design is registered.
- Removing rejected views did not change the data bridge, scores or stored Bull data.
- Every score is constrained below its figure. No negative spacing or figure-overlay score
  treatment remains.
- Both figures use the same 1.20 artwork zoom and ten-point vertical offset. Since all artwork stages
  share the same visible bottom edge within one source pixel, this establishes one consistent floor
  line while their clipped figure zones and seven-point outer inset protect the rounded border.
- The approved full-width score footer and fine divider treatment are preserved from the supplied
  reference; the scores remain entirely below the artwork.
- The decorative background circles are visual only and never change the underlying score
  semantics.

## Final device gate

Render Face Off in Xcode Canvas and on the target iPhone. Confirm the real system-medium widget
matches the approved hierarchy, then keep the shared bridge and App Group unchanged.
