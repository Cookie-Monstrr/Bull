# Bull Native v3.2.1 Handover

## Release Identity

- Marketing version: 3.2.1
- Build: 34
- Deployment target: iOS 17+
- Payload: v14 in `bull-data-v14.json`
- Active four-score version: 9
- Unit-test inventory: 153 test methods across 10 Swift files

## Purpose of This Patch

v3.2.1 is the correction-safety, privacy and reliability pass requested before Bull is
opened to a therapist, Layla or test users. It remediates the source-level issues that
can be resolved without a Mac, signed profiles, a physical iPhone, the Layla project or
a therapist-access product design.

It does **not** implement remote therapist oversight or the Layla transport. Those remain
blocked until their separate security and integration contracts are approved and built.

## Historical Corrections

The missing v3.2 feature is now implemented: a previous day's ejaculatory-control log
can be opened, added, edited and deleted. The selected date is visible in the editor.
An edit preserves the original event ID and timestamp, adds `modifiedTs`, and preserves
live or retrospective provenance.

Past-day actions are also reachable for Urge State and Bull State. Past Stress Relief
now receives the selected date and is forced into retrospective mode, preventing the
v3.2 defect where a correction made while viewing yesterday could be saved to today.

### Score correction policy

v3.2.1 adopts **corrected truth with revision metadata**:

- corrections in the current v3.2 score era recompute the affected finalized day;
- rolling routine inputs also recompute the following six affected seven-day snapshots;
- each replacement increments `revision` and retains `originalRecordedTs`;
- the UI marks a corrected historical score and its revision;
- v3.1 and older score eras remain frozen and are never reopened.

Ejaculatory control remains an event-only observation and therefore does not change a
four-score snapshot.

## Privacy and Backup Hardening

- Device authentication now fails closed when it is unavailable, cancelled or fails.
- The privacy-lock preference is persisted only after successful authentication.
- Full-backup export now warns that the JSON is unencrypted and names the sensitive
  categories it contains.
- A separate redacted export contains finalized four-score snapshots only. It excludes
  raw notes, sexual observations, locations, zone/safeguard history and Layla records.
- Imports are capped at 25 MB.
- Every v3.0–v3.2 array plus `fourScoreSnapshots` participates in malformed-row reporting.
- A verified, decodable pre-import copy is now required before current data is replaced.

Password-encrypted recovery export and a selective therapist report remain future work.
The redacted score file is a safer manual review artifact, not therapist oversight.

## Risk Zone and Notification Hardening

- Actual Risk Zone notifications now say **“Take action before you regret it!”**
- Detailed mode may append the chosen safeguard; private mode contains no Bull name,
  place name or safeguard text.
- Snooze removes the active one-shot, legacy repeat and all pending follow-ups before
  scheduling one ten-minute reminder.
- Future Risk Zone nudges are a finite series of one-shots, capped at eight and bounded
  by the end of the active zone window. They cannot repeat indefinitely into a safe window.
- Completing a safeguard or leaving the zone cancels the full series.
- The Time Sensitive Notifications entitlement is declared. Code checks the iOS setting
  and falls back to a normal private reminder when priority delivery is unavailable.
- Foreground already-inside reconciliation works with When In Use permission; background
  region monitoring still correctly requires Always permission.

The Risk Zone settings copy is shorter: `Alerts`, `Time-Sensitive Alerts`, and
`Repeat Every N Minutes`. Slash-separated action titles were removed throughout app
controls, and exact built-in legacy labels are safely shortened without replacing user
customisations.

## Layla Consumer Hardening

Bull rejects invalid, future-dated, stale and equal-timestamp conflicting Layla
snapshots. An exact replay is idempotent; a strictly newer same-day snapshot becomes the
only authority and updates derived fields once. The latest 30 accepted records remain.

This is still consumer logic only. A real App Group/other transport and the owner of an
unexpected-wake alert while Bull is suspended have not been implemented.

## Health, Stats and Accessibility

- HealthKit status now accurately means the authorization request completed; it does not
  claim Apple disclosed read permission.
- The usage description names Sleep, HRV, Resting Heart Rate and Workouts.
- Sleep queries include overlapping samples and clip asleep intervals to both window
  boundaries.
- Live Urge observations of 7+ now count in the high-urge experiment outcome.
- `All Time` no longer silently stops at ten years.
- Forced Light Mode was removed so Bull follows the system appearance.
- Edit/delete icon controls added in this patch have explicit accessibility labels.

Health, notifications, location, dark appearance, Dynamic Type and VoiceOver still need
the physical-device validation in `VALIDATION-v3.2.1.md`.

## Main Changed Files

- `Bull/BullStore.swift` — corrections, score revisions, import rollback, Layla checks,
  bounded zone windows and concise legacy-label repair.
- `Bull/SexualCheckInView.swift`, `Bull/V30TrackingViews.swift`, `Bull/TodayView.swift` —
  past-day editors and selected-date wording.
- `Bull/Core/V29Models.swift`, `Bull/Core/V30Models.swift` — backward-compatible correction
  metadata.
- `Bull/Core/BackupImporter.swift`, `Bull/SettingsView.swift` — import/export hardening.
- `Bull/Core/V28Logic.swift`, `Bull/NotificationService.swift`, `Bull/ContentView.swift` —
  tested notification copy and bounded follow-ups.
- `Bull/Core/V31Logic.swift` — monotonic Layla ingestion and deterministic same-time rows.
- `Bull/HealthKitService.swift`, `Bull/HighRiskZoneService.swift` — system-boundary fixes.
- `BullTests/V321Tests.swift` — v3.2.1 regression suite.

## Remaining Release Blockers

1. Build, tests, Analyze and physical-device validation have not yet been run.
2. Remote therapist oversight is not implemented.
3. Layla cross-app transport and suspended-app alert ownership are not implemented.
4. Encrypted full backup, import preview/field-level repair reporting and large-data
   persistence benchmarking remain open hardening work.
5. App Store archive privacy report/disclosures must be reconciled before distribution.
