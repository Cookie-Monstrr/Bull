# Bull 3.4 build 49 — changes and testing

Date: 2026-09-06. Baseline: supplied complete build-48 handover.
Status: implemented source, awaiting Xcode and physical-device gates. No remote push.

## Stats: six charts, two visible per tab

| Tab | First chart | Second chart |
| --- | --- | --- |
| Overview | Urge State + Urge Routine | Bull State + Bull Routine |
| Breakdown | Urge Routine: 3 component attainment lines | Bull Routine: 4 component attainment lines |
| Sleep / HRV | Sleep hours + relapse-day markers | HRV + prior baseline + relapse-day markers |

Shared 7D, 30D, 1Y and All range; completed civil days through yesterday. Average
values live inside the cards, not four additional score tiles. Legends toggle
lines, chart selection inspects a day. Missing/excluded observations make gaps;
zero stays zero. Single observations stay visible. Scoring-era changes break lines.

Removed from the displayed Stats UI: the separate Stress/Health/Urges pages,
State Outcomes graph, Top Associations/See All, their old graph/card clutter and
duplicated score tiles. Underlying logs, exports and analysis code are retained.

Component weights remain Urge 40/35/25 and Bull 40/30/20/10. Percentage means
attainment within a component. A short text below each Breakdown graph ranks the
largest weighted shortfall on at least three dates with every component observed;
unequal coverage cannot decide the ranking. This is a mathematical shortfall,
not a causal estimate or an instruction to pursue perfect scores.

New score snapshots optionally save their component values. Old snapshots still
decode. Current-era historical components are reconstructed only if the routine
total matches its frozen total; mismatches and earlier scoring eras remain gaps.
Even a matching reconstructed total cannot prove exact historical provenance;
these observations are labelled reconstructed. Opening Stats never saves or
changes a historical total. Bull Routine remains rolling seven-day attainment.

Sleep/HRV graphs use recorded measurements, not inferred missing values. Relapse
markers obey the existing lapse-counting policy and frozen event day keys. Wet
dreams do not count. Markers remain visible on days without valid biometrics.
HRV baseline is the existing median of up to 30 previous observed days, requiring
seven. These are temporal associations, not evidence of causation; within-day
ordering and missing relapse logs limit interpretation.

## Widgets

Face Off: score footer now has an explicit centered frame, larger vertical room,
bottom breathing space and artwork-specific optical horizontal placement based
on the shipped figure body centres rather than the Devil's tail. Artwork is
unchanged. Final optical balance must be reviewed in WidgetKit on the user's phone.

Today's Priorities: new system-medium oxblood/gold widget, stackable with Face Off.
Shows the highest-ranked two or three pending actions (depending on available
height), with a count of additional items and component-weight badges. Safety
actions come first; ordinary actions are roughly weight-prioritised. Sleep
shows both U 40% and B 30%, never a misleading combined 70% score.

Actions are derived from today's plan, logs, sleep availability and active zone
safeguards. It asks for scheduled cardio/sets, not extra exercise just to fill a
rolling score. Unknown activity is labelled planned, not confirmed incomplete.
Stress logging is not presented as automatic recovery. Sleep preparation helps
tonight, not last night's immutable outcome. Food's explicit Off Plan record is
treated as recorded, not silently reset to unfinished.

Tap opens `bull://priorities` after the app's privacy lock. The full list routes
to existing entry screens; Health imports retain their target date even across
midnight and do not open a sensitive sheet while locked. The widget itself does
not directly mark habits complete. Health correction retains the existing override
semantics. Generic task titles/weights/progress only cross the App Group boundary;
no notes, coordinates, zone names, relapse logs or raw Health measurements.

Priorities expire after 30 minutes or at midnight, whichever comes first; stale
entries say Open Bull to refresh. This is deliberately conservative: a suspended
app cannot continuously infer new tasks. Foreground ticks and normal saves publish
updates; WidgetKit controls delivery timing. Face Off also clears yesterday's
payload at midnight. Therapist-role installations clear both widget payloads.

Pending: the two new routine figure sets (five stages each). No substitute art
or routine-figure widget has been shipped in this build.

## Cancel Oversight → End Access

The prior stop path could return false while `isSyncing`, without useful feedback.
The new path serializes End Access behind the active cloud operation (20-second
wait bound), blocks duplicate starts and shows waiting/revoking/success/error state.
Share preparation and recovery are serialized with that state.

It rereads the exact owner share identity after waiting, then revokes that share
using CKModifyRecordsOperation. Request/resource limits and a 30-second outer
timer bound queued/executing revocation. Completion resumes once even when a late
callback races the timeout. Missing-share/zone responses are accepted only for
the targeted deletion (partial failures must identify that exact share alone).

Local oversight ends only after server-confirmed revocation/absence. Offline,
timeout and other errors retain protection and show retry guidance. Partial setup
is checked remotely too; missing local metadata is not proof of absent access.
History is not deleted. An owner-private CloudKit zone/subscription can remain;
this is access revocation, not a cloud-data-erasure feature. Previously downloaded
copies cannot be recalled. End Access is not cleared for real use until two-device
tests pass, consistent with the inherited Oversight release gate.

## Compatibility and delivery

- Marketing version 3.4, build 49 across app/widget/test configurations; iOS 17+.
- Same `com.ahmed.Bull`, App Group and CloudKit container; payload v15, scoring v9.
- No score formula, recovery-file, import policy or therapist projection expansion.
- App Info.plist adds only the Bull URL scheme, with generated plist settings kept.
- Build49Tests adds 24 regression methods; previous test files are unchanged.
- The changed-files ZIP overlays build 48 with relative paths; no source deletions.
- The full ZIP is a standalone source project. Previous handovers remain historical.

Export a backup before installing. Open/build with your existing signing team and
install over Bull. Do not delete Bull, change bundle IDs or reset its data.

## Validation performed here

See `BUILD49-STATIC-VALIDATION.txt` for exact results. Swift files were parsed with
tree-sitter-swift; project syntax, XML plists, JSON asset files, widget registration,
release versions, preserved assets/core logic/tests and archive integrity were checked.
This is not Swift type checking, Xcode compilation, UI rendering or XCTest execution.
No Xcode/Swift SDK, simulator, iPhone, HealthKit or signed CloudKit environment is
available here. The additional tests have been written, not run.

## Required Mac/device checks

1. Build Bull and BullWidgets in Xcode; run the Bull test scheme (all existing tests
   plus Build49Tests). Verify generated Info.plist and new URL-scheme registration.
2. Install over build 48 using the same identity. Compare backups, frozen historical
   totals, today's scores, manual overrides, Health imports and previous-good recovery.
3. Stats: all three tabs/ranges; empty install, one point, missing/excluded/zero days,
   version boundaries, reconstructed gaps, date selection, legend toggles and long
   histories. Confirm markers against actual lapse policy/day keys. Test large text.
4. Widget gallery: Face Off + Today's Priorities. Test five figure stages, 0/10/68/100
   scores, two/three-row sizing, stacking, dark/tinted modes and physical optical centring.
5. Priorities: active exit-only vs safeguard zone, rest/workout days, partial/completed
   sets, Health/manual cardio, evening timing, sleep suppression, food states, stale
   expiry/midnight, background updates and widget tap while locked/therapist role.
6. End Access with two iCloud accounts: pending invitation, accepted share, incomplete
   setup, active prepare/sync, duplicate taps, lost connection, absent share, timeout
   and retry. Confirm recipient cannot fetch fresh shared records and owner Risk
   Controls unlock only after confirmed revocation. History must remain intact.
7. Test resetting only on a disposable test installation after export; it must still
   stop when revocation is unconfirmed. Repeat inherited Layla and Health device gates.

Do not distribute as verified until these gates pass. Supply screenshots/build errors
for the next iteration; then add the user's routine artwork and review before pushing.
