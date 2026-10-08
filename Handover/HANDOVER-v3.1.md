# Bull Native v3.1 Handover

Build date: 2026-08-28

## Product Decisions Implemented

- Urge Routine, Urge State and Bull State describe the selected day. Their score
  cards say `Today`. Bull Routine remains `Last 7 Days`.
- Every expanded score card is titled `<Score> Breakdown`; the former explanatory
  `Why … Is …` copy is removed.
- Method badges use only `Automatic`, `Semi-Automatic` or `Manual`, and are omitted
  when the input method is already obvious.
- The custom loading page is removed. Bull enters `ContentView` directly after the
  system launch screen and any enabled privacy lock.
- User-facing wake language is `Dawn`; legacy Fajr storage identifiers remain
  compatible so historical sleep metadata is not rewritten.

## Today Screen

The former `Today's Inputs` card and the separate Stress/Bull State quick-action
tiles are removed.

Urge Routine Breakdown now owns:

- Sleep Protection, Stress Regulation and Environment Protection.
- Secondary 7-Day Momentum from finalized v3.1 daily Urge Routine snapshots.
- Edit Stress Plan, Open Risk Zones, Stress Check-In and Log Stress Relief actions.

Bull Routine Breakdown now owns:

- Cardio with Log / Correct Cardio.
- Sleep with Sync Apple Health and Edit Sleep.
- Bull Fuel with On Plan, Partly, Off Plan and Clear.
- Strength with scheduled-set progress, Log Strength Workout and Edit Exercise Plan.

Urge State and Bull State Breakdowns each contain a full-width primary log button.

## Timestamped State Logs

### Live Urge

Every saved urge is an independent timestamped 0–10 observation. Today's Urge
State uses the newest timestamped observation, not the daily peak. A logged zero
is real; no observation remains missing. The log supports edit and delete. Daily
peak remains available only in Stats for later sleep/urge and time-of-day analysis.

### Bull State

Every v3.1 Bull State row saves one atomic timestamped record containing:

- Wake: Dawn, Final Wake or Other Wake.
- Erection: Not Observed, No or Yes.
- EHS 1–4 when erection is Yes.
- Healthy Sexual Desire 0–10.

The newest complete row drives today's Bull State. Rows can be edited or deleted.
Legacy wake and desire streams are preserved but never guessed into artificial
pairs.

## Stress Regulation

Morning Stress is logged after Final Wake. Evening Stress is logged before bed.
Either endpoint can be saved, edited or cleared independently. During today, the
morning value is compared with the newest live stress reading for a provisional
score. Evening Stress finalizes the daily score; past missing endpoints remain
missing.

Stress-relief activity data no longer awards routine points or uses weekly targets.
Prospective logging is the primary flow:

1. Choose the activity and log Stress Before.
2. Start it and leave the sheet or app.
3. Reopen the sheet, log Stress After and complete it.

An explicit Estimated Afterwards fallback remains for rough recollection. Stats
rank activities with prospective evidence first and label estimate-only evidence.

## Exercise and Bull Fuel

- Bull Fuel maps On Plan to 100, Partly to 50 and Off Plan to 0. Legacy Done / Not
  Done maps to 100 / 0 without rewriting old rows.
- The Planned Strength Session toggle, whole-session completion toggle, workout
  note, automatic-coaching note and numbered list icon are removed from the live UI.
- Strength plan days store structured exercises with target sets, rep range and an
  optional suggested weight. v3.1 parses compatible v3.0 prescription text into
  this structure during migration.
- Workout execution duplicates those planned exercises. Each scheduled set has an
  independent completion control plus actual kg and reps. Extra sets are retained
  for Stats but do not inflate routine credit.
- Rolling Strength credit equals completed scheduled sets divided by scheduled
  sets. Each historical day is evaluated against its applicable versioned plan.
- Cardio is not duplicated in the strength execution screen.

## Data and Compatibility

- Payload version: 13.
- Current four-score version: 8.
- Existing v1–v6 `scoreSnapshots` remain untouched.
- Existing final v7 `fourScoreSnapshots` remain untouched.
- New arrays/fields decode leniently so older Native and PWA backups remain usable.
- v3.1 never fabricates a combined Bull State record from separate legacy streams.

## Files Most Relevant to v3.1

- `Bull/Core/V31Logic.swift` — additive migration and current scoring rules.
- `Bull/Core/V30Models.swift` — timestamped observations and compatible model
  extensions.
- `Bull/BullStore.swift` — persistence, current/final snapshots and log operations.
- `Bull/TodayView.swift` — consolidated score-card UI.
- `Bull/V30TrackingViews.swift` — stress and Live Urge workflows.
- `Bull/SexualCheckInView.swift` — atomic Bull State workflow.
- `Bull/ExercisePlanView.swift` — structured plan and per-set execution.
- `BullTests/V31Tests.swift` — v3.1 migration, scoring and evidence tests.
