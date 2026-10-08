# Bull v3.3 Two-Device Test

You do not need to run this immediately. Budget about 35–50 minutes when you have two
physical iPhones, two different iCloud accounts and the Mac build gate has passed.

## Setup

- Device A: owner account with a protected Bull backup available.
- Device B: therapist test account, preferably a fresh/dedicated Bull install.
- Both devices: online, notifications allowed, Low Power Mode off for the first pass.
- Development pass first; TestFlight Production pass second.

Record `PASS`, `FAIL` or `NOT RUN` beside every item. A partial pass is not release clearance.

## A. Upgrade and scope

- [ ] Device A upgrades from v3.2.1 without losing days, relapses, zones or score history.
- [ ] Yesterday's Ejaculatory Control screen can add, edit and delete yesterday's entry.
- [ ] Device A creates Therapist Oversight and invites exactly one participant.
- [ ] Device B accepts and reaches `Client Oversight`.
- [ ] Device B sees Urge Routine, Urge State, Urge observations, relapses, Risk Zones and
      Risk Controls.
- [ ] Device B does **not** show Bull, Vigour, sexual health, workouts, HealthKit, exact
      coordinates, notes, triggers or next actions.

## B. Risk Zone warning behavior

- [ ] Enter an enabled zone during active hours. Device B receives one warning containing
      **“Take action before you regret it!”** and no coordinates.
- [ ] Exit the zone. Device B's dashboard changes to outside after sync.
- [ ] Temporarily set the zone window inactive, then physically enter. Device B still gets
      an entry warning saying it was outside the active window.
- [ ] Confirm the owner does not receive active-window intervention repeats while the
      window is inactive.
- [ ] With active hours restored, remain inside past one repeat interval. Device B receives
      no faster than the configured interval.
- [ ] Disable notifications or reduce location permission on Device A. Device B receives a
      monitoring warning and sees the degraded status after sync.
- [ ] Restore permissions. Device B's monitoring counts/status recover without reinstall.

## C. No Safeguard Possible

- [ ] Mark a zone `No Safeguard Possible`.
- [ ] Owner Risk Zone UI says leaving is required.
- [ ] No `Safeguard Done` or equivalent completion action appears in-app or on notifications.
- [ ] Device B labels the zone `No safeguard possible`.
- [ ] Remaining inside never changes the zone to safeguarded; leaving changes it to outside.
- [ ] Weekly safeguard goals do not treat the exit-only prompt as a completable opportunity.

## D. Protected changes

- [ ] Shrink the radius. Device A keeps the old radius and shows `Awaiting therapist review`.
- [ ] Device B sees only zone name, old/new radius and other sanitized settings—no centre.
- [ ] Reject with `Discuss`. Device A keeps the old radius.
- [ ] Request again and approve. Device A applies the exact reviewed radius.
- [ ] Request a weakening change, then make a separate stronger change before approval.
      Approval cancels as superseded and does not undo the stronger change.
- [ ] Increase radius or shorten repeat interval. It applies immediately and appears on
      Device B after sync.
- [ ] Try pause, delete, schedule reduction, safeguard change, longer repeats and turning
      off Time Sensitive delivery; each remains pending until review.

## E. Urge and relapse flow

- [ ] Log/edit an Urge State observation on Device A; Device B receives the updated narrow
      projection.
- [ ] Log a counted relapse. Device B receives one relapse warning and sees the record.
- [ ] Confirm relapse notes, triggers and next action are absent.
- [ ] First sync of an account with old history does not create a burst of 90-day-old
      notifications.

## F. Offline and lifecycle

- [ ] Start owner setup while iCloud cannot save (offline or with a controlled test
      failure). Before any invite is confirmed, choose `Cancel Setup`; protection unlocks
      immediately and a late CloudKit completion does not restore the cancelled setup.
- [ ] Retry setup after the failure is removed. The stale error clears, preparation
      completes and the Apple invitation sheet remains visible.
- [ ] Take Device B offline, create an owner event, reconnect and sync. It appears once.
- [ ] Force-quit Device B, create an event and document that delivery can wait until the
      next permitted background execution or app open. Do not call this guaranteed.
- [ ] Device B chooses `Leave Oversight`; its client view clears only after iCloud confirms.
- [ ] Re-invite, then Device A chooses `End Oversight`. Device B shows `Oversight Ended`
      after its next successful sync.
- [ ] Simulate owner revocation failure by going offline before End/Reset. Bull keeps Risk
      Controls protected and does not wipe Device A.
- [ ] Confirm full import and undo-import are unavailable during protected oversight.

## G. Accessibility and load

- [ ] Repeat owner and therapist screens with Large Text and VoiceOver.
- [ ] Confirm Approve, Discuss, menu and exit-only controls have unambiguous labels.
- [ ] Load representative 90-day history and confirm the encrypted snapshot stays below
      900 KB with no visible main-thread stall.

## Result to send back

```text
Bull v3.3 gate: Development/TestFlight
Build: PASS/FAIL
169 tests: PASS/FAIL
Scope leak: NONE/DETAILS
Zone entry active: PASS/FAIL
Zone entry inactive: PASS/FAIL
Exit-only: PASS/FAIL
Protected changes: PASS/FAIL
Monitoring degradation/recovery: PASS/FAIL
Revocation: PASS/FAIL
Force-quit delay observed: YES/NO
Snapshot under 900 KB: YES/NO
Notes/screenshots: ...
```
