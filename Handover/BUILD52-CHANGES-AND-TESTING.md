# Bull v3.4 Build 52 — changes and testing

Date: 9 September 2026

This is the completed source update for the agreed batch and figure integration. It extends the
Build 51 project produced in this conversation, which itself extends the supplied
Build 50 archive. Build 50 remains the last version the user confirmed running on
their iPhone. No remote push, signing, installation or distribution was performed.

## Integrated artwork and names

The ten approved sources are preserved unchanged in `Approved-Figure-Sources/`.
Their locally extracted transparent cutouts now replace all ten routine assets in
the shared app/widget catalog. The user approved resuming with local background
removal after the built-in image tool returned painted checkerboards. Source RGB
interiors were retained; edge colours were cleaned and images resized to 512 × 768
RGBA canvases. No character redesign was substituted. The failed generator cutout
provided a segmentation hint for the strongest Sorcerer; its recoloured pixels are
not used in the production artwork.

All cutouts share the y=744 foot baseline. Constant scale within each family keeps
the depleted Titan and kneeling Sorcerer visibly shorter. The ten Bull State/Urge
State assets are byte-for-byte unchanged from Build 50. Both app and widgets use
the same shared stage selection. `BUILD52-ARTWORK-MANIFEST.json` records source and
production hashes. `BUILD52-FIGURE-WIDGET-PREVIEW.png` is a composition preview
using the production assets, not an iOS/WidgetKit screenshot.

| Score band | Provider asset / Inferno Titan | Angel asset / Cinder Sorcerer |
| --- | --- | --- |
| 0–<20 | titan-1.png: depleted, revised | sorcerer-1.png: final revised strongest |
| 20–<40 | titan-2.png: spark, revised | sorcerer-2.png |
| 40–<60 | titan-3.png | sorcerer-3.png |
| 60–<80 | titan-4.png | sorcerer-4.png |
| 80–100 | titan-5.png: peak, revised | sorcerer-5.png: ORIGINAL kneeling weakest |

The routine score remains higher-is-better. Titan strength increases across these
bands; Sorcerer strength decreases. No numeric inversion, thresholds or calculations
were changed in Build 52. Visible names now use Bull Fuel and Urge Fuel; the eating
plan is Nutrition. The same names appear in Stats, priorities, therapist views and
widget descriptions. About These Charts briefly explains that higher Urge Fuel
means stronger protective habits and a weaker Sorcerer. Internal score fields,
widget kind identifiers and asset keys remain stable for compatibility.

## Therapist review and changes implemented

- Added a UIWindowSceneDelegate, registered by the app delegate, for invitation
  acceptance while running and from cold-launch connection options. Build 51 only
  supplied the application-delegate acceptance callback despite using SwiftUI scenes.
- Invitation acceptance waits up to 20 seconds for a competing CloudKit operation,
  then claims the queued metadata once. A timed-out invitation remains queued and
  shows a retry message. It does not require a new invitation to be created.
- Validate the CloudKit container, zone and zone-wide share identity before joining.
  Reopening an already accepted invitation no longer resets acceptance history and
  notification-watermark configuration. Once joined, a failed first fetch is retried
  through the dashboard sync path.
- Read the client snapshot before registering the participant push subscription.
  A subscription failure is still reported, but no longer prevents an otherwise
  successful snapshot fetch from appearing.
- Validate inbound envelope schema versions and size limits without changing the
  existing schema. The encrypted payload remains schema version 1.
- Preserve already-sent review decisions when the owner's snapshot is still pending.
  Applied and cancelled owner results take precedence. Match the complete original
  proposal and review timestamp rather than trusting an identifier alone, on both
  the therapist display and owner decision-application path.
- Prevent reviewing a non-pending request or submitting from an ended connection.
- Invalidate in-flight owner work when Apple's sharing controller confirms revocation.
- Guard owner notification routes, local geofence monitoring and owner risk actions
  when this installation is in therapist mode. Stored personal data is retained.
- Added Settings → Therapist Oversight → Preview Therapist View. It uses the narrow
  local projection, disables review actions, and does not accept shares, sync, alter
  roles or leave oversight. It previews display and scope, not remote delivery.
- Display the client's upload time and describe zone occupancy as the last report,
  including the zone-event time. Cached data is not labelled as live presence.
- Added access to all shared daily Urge scores/observations, relapse rows and retained
  warnings instead of silently stopping at 8 or 12 rows.
- Show current and proposed controls before review, plus reviewed/applied/cancelled
  status. Added visible Retry Sync to the empty participant screen.
- Renamed the misleading Invite via Email button to Invite Therapist; Apple's share
  sheet chooses the delivery method. No email or invitation was sent during this work.
- Guard out-of-range weekday and numeric display values to avoid rendering crashes.

## Scope verified in code

The therapist payload is an explicit projection: 90 days of Urge scores and urges,
counted relapses, coordinate-free Risk Zones/activity, monitoring status and control
change reviews. Bull scores, sexual-health records, exact coordinates, workouts,
HealthKit samples and free-form notes are not fields in this projection. Existing
widgets are cleared when switching this installation into therapist mode.

The design currently supports one therapist per share and one client per therapist
installation. It is an iCloud share opened in the Bull app, not a browser portal.
No web dashboard, multi-client practice account or guaranteed real-time alert
service has been added. Old cached information cannot be remotely erased from an
offline device until the app reconnects; the UI now identifies the snapshot time.

Apple documents scene-based invitation acceptance in
[Accepting Share Invitations in a SwiftUI App](https://developer.apple.com/documentation/coredata/accepting-share-invitations-in-a-swiftui-app).
The existing participant leave action deletes the share record from the shared
database, consistent with [Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records),
so this review did not replace that API based on speculation.

## Identity and data

Build number is 52 in all six configurations. App ID `com.ahmed.Bull`, widget ID
`com.ahmed.Bull.BullWidgets`, team `8LT6DKBQL7`, App Group `group.com.ahmed.Bull`,
CloudKit container `iCloud.com.ahmed.Bull`, marketing version 3.4, entitlements and
signing configuration are preserved. All Build 51 data-model files are unchanged.
Main storage remains `bull-data-v15.json`, envelope version 15, score version 10.
Build 51's backwards-compatible changes remain in place; Build 52 adds no
stored fields or score recalculation. Do not delete the installed Bull app or clear
its data. Any eventual installation must update it in place with matching signing.

## Validation completed and limits

- `validate_build52.py`: 74 Swift files parsed without syntax errors; project,
  plist, entitlement and JSON structures parsed; identity, build numbers and widget
  membership checked. All 20 production assets pass the RGBA contract, including
  the ten new cutouts. The new figures were inspected against dark red at larger
  resolution and in a widget-sized composition.
- Three review-regression XCTest methods were added to V33Tests.swift. There are
  218 methods in 14 test files. They were source-parsed, NOT executed.
- No Xcode, Apple SDK, simulator, provisioning profiles or paired iPhones are
  available here. Syntax parsing does not verify Swift type checking, linking,
  WidgetKit layout, runtime scene delivery or CloudKit permissions/schema deployment.

## Deliverables

The full-project ZIP is the complete Build 52 source project. The changed-files ZIP
is cumulative against the supplied Build 50 archive; Build 51 has not been confirmed
installed. Its manifest lists added/modified files and hashes. No files are deleted
from the baseline. Both ZIPs include this handover and the earlier Build 50/51
handover history where applicable. Use the full ZIP for the simplest Xcode workflow.

Build 51's fasting/rest-day behaviour, split state inputs, cleaner Stats and graph
widgets are included. Read `BUILD51-CHANGES-AND-TESTING.md` for those details; its
older figure names are superseded by this document.

On Apple hardware, build and run tests, then test with two different iCloud accounts:
invite a therapist, accept with Bull closed and open, inspect the restricted view,
change share options without losing the access sheet, approve/discuss a request and
sync both ways, refresh before the owner acknowledges a decision, test offline and
subscription failure states, revoke from the owner, and leave from the participant.
Confirm the real therapist view excludes Bull/sexual-health/location-coordinate data.
Do not claim therapist delivery or revocation works end-to-end until those checks run.
