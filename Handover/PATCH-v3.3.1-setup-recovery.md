# Bull v3.3.1 Therapist Setup Recovery — 2026-09-01

Physical-device testing exposed a recovery trap after CloudKit rejected the initial
therapist snapshot with `quotaExceeded`:

- `Cancel Setup` now takes effect immediately when no share was ever confirmed, even if
  the failed CloudKit request is still returning.
- In-flight setup and sync work captures a cancellation generation. A late result cannot
  resurrect ended oversight or leave Risk Controls protected after cancellation.
- Partial, unshared CloudKit zones and subscriptions are removed best-effort.
- Retrying clears the stale error and shows a concise iCloud-storage message if Apple still
  reports the quota as full.
- The UI distinguishes `Cancel Setup` from ending an established therapist share. Revoking
  a confirmed share remains fail-safe: Risk Controls stay protected if CloudKit cannot
  confirm revocation.

This patch does not change the shared scope, scoring, persisted-data schema or the rule that
only protection-reducing Risk Control changes require therapist review.
