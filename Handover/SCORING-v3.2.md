# Bull v3.2 Scoring Contract

Missing inputs stay missing. Scores are clamped to 0–100. No component silently
reweights itself around a missing sibling. Final historical snapshots retain the
scoring version that produced them.

## Purpose-Specific Sleep

HealthKit first produces the existing transparent components:

- duration: 0–50 points;
- timing consistency: 0–30 points;
- continuity/interruptions: 0–20 points.

Bull normalizes each component to 0–100, then applies these locked v1 purpose weights:

| Purpose | Duration | Timing consistency | Continuity |
| --- | ---: | ---: | ---: |
| Prevention | 45% | 30% | 25% |
| Vigour | 60% | 10% | 30% |

Until Layla supplies `sleepConsistencyDeviationMinutes`, HealthKit bedtime history is
the timing source. A valid Layla value replaces only that component and carries source
`layla-consistency+bull-purpose-sleep`. Manual purpose scores always win.

One likely planned Dawn/Fajr split retains the existing allowance: up to 90 minutes is
excluded from the interruption penalty, and only excess/unplanned wake time is charged.

## Urge Routine — Today

| Pillar | Weight | Rule |
| --- | ---: | --- |
| Sleep Protection | 40% | Selected day's Prevention sleep score |
| Stress Regulation | 35% | Morning-to-live provisional result; Evening final result |
| Environment Protection | 25% | Current effective Risk Zone safeguard status |

The generic `sleep` value is the fallback for a historical/manual day with no separate
Prevention value. Seven-Day Momentum remains secondary and never changes today's score.

## Urge State — Today

`newest timestamped Live Urge (0–10) × 10`

Daily peak remains a Stats-only series.

## Bull Routine — Last 7 Days

| Pillar | Weight | Rule |
| --- | ---: | --- |
| Cardio | 40% | Moderate-equivalent minutes / current weekly target, capped at 100 |
| Sleep | 30% | Mean of observed Vigour sleep scores in the window |
| Bull Fuel | 20% | Mean of On Plan 100, Partly 50 and Off Plan 0 |
| Strength | 10% | Completed scheduled sets / scheduled sets under applicable plans |

The generic `sleep` value is the fallback for an older day with no separate Vigour
value. Manual cardio corrections replace imports. Extra strength sets remain excluded
from the Strength numerator and denominator.

## Bull State — Today

The v3.1 atomic model is unchanged: Erection Health 60% and Healthy Sexual Desire 40%.
No artificial aggregate is made from separate legacy wake/desire records.

## Snapshot Boundary

v3.2 writes `FourScoreSnapshot.scoringVersion == 9` from
`settings.fourScoreV9StartDayKey`. Final version-8 snapshots are displayed as recorded
in Stats but never reopened or recomputed.
