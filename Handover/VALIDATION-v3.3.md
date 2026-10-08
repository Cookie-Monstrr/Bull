# Bull v3.3 Validation Record

## Completed in the static review

- Compared v3.3 against the preserved v3.2.1 tree.
- Confirmed one Xcode project, app target and test target.
- Confirmed v3.3 build 35, iOS 17+, payload v15 and unchanged score version 9.
- Confirmed 66 Swift files and 169 XCTest methods across 11 test files.
- Parsed every JSON fixture and checked the entitlement XML structure.
- Checked all Swift sources for balanced braces, brackets, parentheses, strings and
  comments, plus merge-conflict markers.
- Checked that the retired “Get outside before you regret it” copy is absent and the new
  phrase is covered in owner and therapist tests.
- Checked SwiftUI control titles for slash-separated duplicate wording.
- Checked the therapist projection for excluded keys and added regression coverage for
  Bull/Vigour fields, coordinates, notes, sexual data, workouts, legacy base-risk values
  and compounded-risk alerts.
- Confirmed new CloudKit source APIs against current Apple documentation.

## Not executed in this environment

This workspace is Linux and has no Swift compiler, Apple SDK, Xcode, simulator, signing
identity, provisioning profile, CloudKit account or iPhone. No claim is made that Bull
compiled, that XCTest passed, that Analyze was clean, or that iOS delivered a region,
silent push or notification.

## Required Mac gate

1. Open `Bull.xcodeproj` with the current stable Xcode.
2. Select the shared `Bull` scheme and an iOS 17+ simulator.
3. Clean Build Folder, then Build (`Command-B`).
4. Run Test (`Command-U`) and require all 169 tests to pass.
5. Run Product > Analyze. Resolve new warnings, actor-isolation issues and deprecated
   CloudKit signatures rather than suppressing them.
6. Exercise an upgrade using a copy of a real v14 backup. Confirm the new file is
   `bull-data-v15.json`, all old data is present and score version 9 remains frozen.
7. Archive Release and inspect Xcode's privacy report before changing App Store privacy
   answers.

## Signed-entitlement gate

Do not rely only on `Bull.entitlements`. Inspect the signed app from both a development
device build and the archived Release build. Require:

- `aps-environment` appropriate to the signing profile;
- `com.apple.developer.icloud-container-identifiers` containing
  `iCloud.com.ahmed.Bull`;
- `com.apple.developer.icloud-services` containing `CloudKit`;
- CloudKit Development for a development-signed build and Production for TestFlight;
- HealthKit and Time Sensitive Notifications entitlements.

One inspection command on a Mac is:

```bash
codesign -d --entitlements :- "/path/to/Bull.app"
```

TestFlight uses CloudKit Production. A successful development-device test does not clear
the TestFlight gate.

## Device gates

Run `TWO-DEVICE-TEST-v3.3.md` twice:

1. development-signed builds against CloudKit Development;
2. TestFlight builds against CloudKit Production after schema deployment.

Also repeat the v3.2.1 physical checks for previous-day editing, full/redacted export,
biometric failure, HealthKit empty/denied states, dark appearance, Dynamic Type and
VoiceOver.

## Stop conditions

Do not give therapist access or external test access if any of the following occurs:

- any build, test or Analyze failure;
- any therapist payload shows exact coordinates, Bull, Vigour, sexual, workout, HealthKit
  or free-form note data;
- an exit-only zone exposes a completion action or earns safeguard credit;
- a weakening setting applies before approval, or a stale approval overwrites a newer
  protection;
- a zone entry outside active hours does not reach the therapist dashboard/event stream;
- an owner wipe proceeds after CloudKit revocation fails;
- a transient CloudKit error is displayed as confirmed revocation;
- Development or Production schema lacks the share, snapshot or decision record types;
- the encrypted snapshot reaches 900 KB in representative data;
- a force-quit/network test is described to users as guaranteed emergency monitoring.

Preserve the v3.2.1 package and a protected device backup for rollback.
