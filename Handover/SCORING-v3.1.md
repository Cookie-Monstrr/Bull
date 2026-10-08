# Bull v3.1 Scoring Contract

Missing inputs stay missing. Scores are clamped to 0–100. No component silently
reweights itself around a missing sibling.

## Urge Routine — Today

| Pillar | Weight | Rule |
| --- | ---: | --- |
| Sleep Protection | 40% | Selected day's completed-night Sleep Score |
| Stress Regulation | 35% | Morning-to-live provisional result; Evening final result |
| Environment Protection | 25% | Current active Risk Zone safeguard status |

7-Day Momentum is displayed as secondary context and never changes today's score.

### Stress Regulation Table

Endpoint 0–3 always receives 100. Otherwise:

| Morning − Endpoint | Score |
| ---: | ---: |
| 3 or more | 85 |
| 2 | 70 |
| 1 | 55 |
| 0 | 35 |
| −1 | 20 |
| −2 or less | 0 |

## Urge State — Today

`newest timestamped Live Urge (0–10) × 10`

The daily peak is not the headline score. It remains a Stats-only series.

## Bull Routine — Last 7 Days

| Pillar | Weight | Rule |
| --- | ---: | --- |
| Cardio | 40% | Moderate-equivalent minutes / current weekly target, capped at 100 |
| Sleep | 30% | Mean of observed Sleep Scores in the window |
| Bull Fuel | 20% | Mean of On Plan 100, Partly 50 and Off Plan 0 |
| Strength | 10% | Completed scheduled sets / scheduled sets under the applicable plan versions |

Manual cardio corrections replace imported values and never add duplicate minutes.
Extra strength sets are retained for progression analysis but cannot increase the
Strength numerator or denominator.

## Bull State — Today

The newest complete atomic Bull State entry supplies both pillars.

| Pillar | Weight | Rule |
| --- | ---: | --- |
| Erection Health | 60% | No = 0; Yes = 50 + (EHS / 4 × 50); Not Observed = missing |
| Healthy Sexual Desire | 40% | 0–10 × 10 |

No artificial daily aggregate is made from separate legacy wake/desire records.
