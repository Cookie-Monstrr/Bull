# Bull Native v3.1.1 Patch

## Risk Zone Reliability

- Existing monitored regions are re-queried whenever Bull launches or returns to
  the foreground.
- A current foreground location fix reconciles stale entry/exit history before
  active-hour alerts are evaluated.
- Zone status now distinguishes Inside, Outside, Safeguarded, Action Needed and
  Checking Location instead of using the ambiguous label Active.
- The device check can reconcile the current zone state and send a real local test
  notification.
- Time-Sensitive delivery and repeat cadence now live inside Risk Zones under
  Alert Behaviour.

## Today Screen

- Events is collapsible, its Live Urge count reads the timestamped observation
  stream, and the visible label is Urges Logged.
- What Counts as a Lapse moved into Events.
- Manage Personal Experiments moved into the Personal Experiments card.
- Sick, Travelling and Wet Dream switches have a protected trailing inset.
- Stress Plan, Stress Relief, Stress Check-In and Risk Zone actions use distinct
  icons and the approved two-row order.
- Add New Trigger and Add New Response are available after completing the
  Physiological Sigh; newly created choices are selected immediately for that log.

## Settings

Settings now contains only Apple Health, Lapse Support, Privacy, Data & Backup and
About. Duplicate navigation, fixed score descriptions, Bull Fuel display,
Scientific Basis and Status, Personal Experiments, Purpose Statement and fixed-time
Stress reminder controls were removed. Any old fixed-time Stress reminders are
cancelled on launch.

## Scoring

No score arithmetic changed. Bull Fuel remains the approved rolling seven-day
average and may therefore contribute 4/20 after one On Plan day when earlier logged
days in the window were Off Plan.

## Roadmap Only

The Post-Lapse Plan streak-freeze idea remains exploratory. A future design must
preserve the lapse in history and analysis even if timely recovery-plan execution
protects a separate streak.
