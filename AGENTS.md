# Bull development rules

These rules apply to work in this repository. Read `docs/PROJECT_CONTEXT.md` before changing product behavior or scoring.

## Branch and scope

- Work on `Test`. Keep `main` stable; do not commit, merge, or push to `main` as part of ordinary development.
- Check the current branch and working tree before editing. Preserve unrelated changes.
- Do not implement roadmap features, new scoring models, or feature removals without explicit approval. A proposal in documentation is not implementation authority.

## Product and data safety

- Preserve existing functionality, app identity, stored user data, backup compatibility, and historical scores unless a change explicitly authorizes a migration or removal.
- Prioritise reliability, privacy, and simplicity. Prefer small, reviewable changes over unnecessary dependencies or architectural rewrites.
- Treat relapse, sexual-health, location, HealthKit, and therapist data as sensitive. Minimise collection, storage, sharing, logging, notification text, and widget payloads.
- Never introduce credentials, API keys, certificates, provisioning profiles, secrets, or personal data into Git. Review staged changes before committing.
- Do not delete the installed app or reset data as a testing shortcut. Preserve the existing bundle IDs, App Group, entitlements, and CloudKit contract when testing updates.

## Platform constraints

- Follow established SwiftUI state and navigation patterns in the project. Keep the app, widget extension, and tests consistent when changing shared contracts.
- HealthKit permission and data availability vary by device and source. Handle denied access, missing samples, delayed samples, and manual entries without inventing measurements.
- WidgetKit timelines and reload requests are best effort; widgets cannot be treated as continuously running or as a source of truth. Keep shared widget data narrowly scoped and privacy sensitive.
- iOS background execution, remote notifications, and Core Location geofences are best effort. Do not promise immediate delivery or continuous monitoring. Test foreground, background, and stale-state behavior where relevant.

## Verification and reporting

- Build the affected Xcode targets and run relevant tests before reporting an application change complete. Use a physical device for capabilities that a simulator cannot establish, including HealthKit, geofences, notifications, App Group handoff, and CloudKit sharing.
- If a required build or device check cannot run, say exactly what was and was not verified; do not claim runtime success from static checks.
- For documentation-only changes, verify the repository facts and review the diff; an app build is not required unless the documentation changes build inputs.
- Report changed files, behavior, verification, and remaining limitations. Do not commit or push unless requested.
