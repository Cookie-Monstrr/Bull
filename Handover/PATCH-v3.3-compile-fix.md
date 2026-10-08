# Bull v3.3 Xcode Compile Fix — 2026-09-01

This patch resolves the seven Xcode diagnostics reported on the first physical-device
build attempt. They came from two source issues:

- `TherapistCloudService.swift` now imports `Combine`, which defines
  `ObservableObject` and `@Published`.
- `BullStore.markTherapistOutboxPublished` now resolves its default timestamp inside
  the `@MainActor` method instead of referencing actor-isolated `Self.nowMS` from a
  nonisolated default-argument expression.

No persisted-data schema, scoring, Therapist Oversight scope or Risk Control behavior
changed. Rebuild in Xcode and report any new first error if compilation exposes a further
diagnostic.
