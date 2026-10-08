# Bull v3.4 Face Off Widget Setup

## One-time Xcode signing check

1. Open `Bull.xcodeproj`.
2. Select the **Bull** target, then **Signing & Capabilities**.
3. Confirm the App Groups capability contains `group.com.ahmed.Bull` and is checked.
4. Select the **BullWidgetsExtension** target and confirm the same App Group is checked.
5. Keep automatic signing on team `8LT6DKBQL7`, or select the correct replacement team for
   both targets if this project is moved to another developer account.
6. If Xcode reports that the App Group does not exist, register exactly
   `group.com.ahmed.Bull` in the Apple Developer account and enable it for both bundle IDs:
   `com.ahmed.Bull` and `com.ahmed.Bull.BullWidgets`.

Do not invent a second App Group name for the extension. The suite name must match both
entitlements and both Swift files exactly.

## Preview the approved widget without installing

1. Open `BullWidgets/BullWidgets.swift`.
2. Choose **Editor → Canvas** and press **Resume**.
3. The file contains one named system-medium Face Off preview using sample scores 78 and 34.

## Test with real scores on iPhone

1. Build and run the **Bull** app on the iPhone once.
2. Change or add a Bull State or Live Urge observation so the current score is persisted.
3. Return to the Home Screen, long-press an empty area, choose **Add Widget**, and search for
   Bull.
4. Add Face Off. It is the only Bull widget entry.
5. Compare its figures and numbers with the Today-screen figures and scores.

## Final widget test

Test Face Off through at least these states:

- both scores present;
- one score missing;
- a score on each side of a 20/40/60/80 artwork threshold;
- light and dark Home Screen wallpapers;
- tinted and clear Home Screen appearances on current iOS;
- device locked with widget previews disabled and enabled;
- Larger Text and VoiceOver.

The chosen widget should be readable at a glance without making the meaning obvious to a
casual observer. In every state, verify that each score remains wholly inside its own footer zone
and never touches or overlaps either figure. Confirm both figures retain comfortable clearance
from the rounded widget border, the thin centre and footer dividers remain subtle, and one-, two-
and three-digit scores remain readable with clear bottom-edge spacing.
