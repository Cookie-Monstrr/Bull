# Bull Roadmap After v3.1.1

## v3.2 Candidates

### Location-Aware Stress Activities

Allow an activity to opt into a private local geofence. On entry, prompt for
Stress Before; on exit, prompt for Stress After. Reuse the proven Risk Zone region
monitoring lifecycle, but keep stress locations and risk locations as distinct
concepts. Include explicit permission, boundary uncertainty, dwell-time and missed
exit handling before release.

This was deliberately deferred from v3.1 so the new prospective stress workflow
can first establish whether Morning/Evening and before/after logging are useful and
stable without adding location-trigger complexity.

### Stressful-Event Coaching

Pre-plan a known stressful event with expected triggers, a before-event stress
reading, chosen coping actions, reminders and a post-event reflection. Coaching
must remain assistive and must not silently change score weights.

### Context-Aware Stress Reminders

Reintroduce automatic Morning and Evening Stress reminders only when Bull has a
trustworthy actual-wake and planned-bedtime source. Prefer HealthKit wherever it
can supply the required observation; use a future Layla connection only for timing
Bull cannot obtain independently. Avoid fixed clock reminders that can fire at the
wrong point in the user's sleep day.

### Post-Lapse Recovery Streak Freeze · Exploratory

Explore whether promptly completing the configured Post-Lapse Plan can earn a
streak freeze or preserve a separate recovery streak. A freeze must never delete,
hide or reclassify the lapse in history or analysis. Before implementation, define
the completion window, required plan evidence and anti-gaming rules, and compare a
single clean streak with a clearer two-streak model.

### Sleep and Timestamped Urge Analysis

Relate prior-night sleep duration/score to timestamped Live Urge observations,
including time of day, latest urge and daily peak. Require enough observed days and
show missingness rather than treating unlogged urges as zero.

### Strength Progression Stats

Track load, reps, completed sets and estimated volume by exercise and muscle group.
Show progression without rewarding extra sets in Bull Routine. Keep plan-version
boundaries visible so changed prescriptions are compared fairly.

## Research Guardrails

- Separate prospective, retrospective and migrated evidence.
- Prefer descriptive associations until coverage thresholds are met.
- Never claim causation from location, sleep, stress or sexual-health correlations.
- Keep all health and location data on-device unless a later explicit sync design is
  separately approved.
