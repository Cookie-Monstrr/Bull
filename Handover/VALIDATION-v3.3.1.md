# Bull v3.3.1 Validation Record

## Completed in this environment

- Confirmed the first Xcode diagnostics were remediated by importing `Combine` and removing
  the actor-isolated default-argument expression.
- Traced failed setup from initial consent through CloudKit snapshot publication and local
  Risk Control protection.
- Confirmed unconfirmed setup cancellation invalidates late asynchronous results before
  they can update local oversight state.
- Confirmed established-share revocation still requires CloudKit confirmation and retains
  protection on failure.
- Added failed-setup cancellation and clean-retry cases to the physical-device checklist.
- Verified the updated project structure, entitlements and compressed handover package.

## Still required on the Mac

1. Build Bull v3.3.1 build 36 with the Apple SDK.
2. Run all XCTest methods.
3. Reproduce setup failure, press `Cancel Setup` during `Preparing…`, and confirm the owner
   returns to an ended/unprotected setup state without reinstalling or losing data.
4. With visible iCloud headroom, retry and complete the two-account share flow.

This environment cannot claim an Xcode build or CloudKit runtime pass.
