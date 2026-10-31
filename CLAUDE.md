# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Cyclo is an early-stage iOS period/cycle-tracking app, built with SwiftUI + SwiftData. It has a real `@main` entry
point (`CycloApp.swift`) and a first Home screen, plus a full set of UI-agnostic data/domain modules (Persistence,
Repositories, Prediction, Auth, Security, HealthKitIntegration) — see `ARCHITECTURE.md`. Most of these aren't
wired together yet (repositories don't yet trigger HealthKit export; `HomePage` doesn't yet read real data from
Repositories/Prediction) — see "Current repo state notes" below for what's real vs. placeholder. There's still no
test target.

- Xcode project: `cyclo-ios.xcodeproj`, single target `cyclo-ios`
- Bundle ID: `cyclo.cyclo-ios`
- iOS deployment target: 18.5
- Swift version: 5.0
- The target uses Xcode 16's **file-system-synchronized group** feature (`PBXFileSystemSynchronizedRootGroup`) —
  every file placed under `cyclo-ios/cyclo-ios/` is automatically picked up by the build, no manual
  "add to target" step or pbxproj edit required.

## Commands

Build and test from the command line with `xcodebuild` (no CocoaPods/SPM dependencies, no Package.swift):

```bash
# Build for a simulator
xcodebuild -project cyclo-ios.xcodeproj -scheme cyclo-ios -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# List available schemes/targets (useful if the default scheme name changes)
xcodebuild -project cyclo-ios.xcodeproj -list
```

There is no test target yet. Once one is added, run tests with:

```bash
xcodebuild -project cyclo-ios.xcodeproj -scheme <test-scheme> -destination 'platform=iOS Simulator,name=iPhone 16' test
# single test:
xcodebuild ... test -only-testing:<TargetName>/<ClassName>/<testMethodName>
```

Opening `cyclo-ios.xcodeproj` in Xcode and using Cmd+R / Cmd+U is the simpler day-to-day workflow.

## Architecture

Source lives under `cyclo-ios/cyclo-ios/Modules/` (`Core/Models`, `Core/Persistence`, `Core/Repositories`,
`Prediction`, `Auth`, `Security`, `HealthKitIntegration`, `Features/Home`), plus the app entry point
`cyclo-ios/cyclo-ios/CycloApp.swift` and `Assets.xcassets` at the synchronized root. See `ARCHITECTURE.md` for the
full tech stack, module plan, and prediction strategy — this section just describes the models as they exist in
code today.

**Persistence model (SwiftData `@Model` classes):**
- `User` (`Models/User.swift`) — `uuid` (not unique at the DB level — SwiftData+CloudKit doesn't support unique
  constraints, so uniqueness will be enforced by a repository once one exists), `name`, `dateOfBirth`,
  `knownConditions: [MenstrualCondition]` (self-reported at onboarding, never inferred), `modifiedAt`. No `email`
  field — the app has no login that would use it.
- `PeriodLog` (`Models/PeriodLog.swift`, file renamed from `PeriodEvent.swift` to match the class) — `id: UUID`,
  optional `user: User?` (optional because CloudKit requires all relationships optional), `startDate`/`endDate`.
- `Log` (`Models/Log.swift`) — a single per-timestamp entry aggregating optional category values (see below), plus
  `id: UUID`.

**Log categories (`Models/LogCategories/*.swift`):** plain `Int`-backed `Codable` enums, one per symptom/tracking
dimension: `Mood`, `Symptoms`, `SexualActivity`, `SexDrive`, `VaginalDischarge`, `OvulationTestResult`,
`PregnancyTest`, `OralContraceptiveStatus`, `PhysicalActivity`, `DigestionAndStool`, `FlowIntensity`, `Other`.
(`SexualActivity`/`SexDrive` were split from a single `SexAndSexDrive` enum that conflated two unrelated concepts;
`OvulationTestResult` was redesigned from the old `OvulationTest`, which never actually captured a test result.)
On `Log`, most categories that can realistically have more than one value per day are optional **arrays**
(`mood: [Mood]?`, `symptoms: [Symptoms]?`, `sexualActivity: [SexualActivity]?`, `physicalActivity:
[PhysicalActivity]?`, `digestionAndStool: [DigestionAndStool]?`, `other: [Other]?`); categories that are
genuinely one-reading-per-day stay single-valued optionals (`sexDrive`, `vaginalDischarge`,
`ovulationTestResult`, `pregnancyTest`, `oralContraceptiveStatus`, `flowIntensity`). `nil` always means "not
logged that day," consistently across every category. When adding a new trackable dimension, add an enum here
and a corresponding property on `Log` (array- or single-valued, depending on whether multiple values per day
make sense) plus its DTO (see below).

**DTO pattern:** Each `@Model` class has a matching `Codable` DTO struct (`LogDTO`, `PeriodLogDTO`) with
`toDTO()` / `toModel()` conversion extensions. DTOs exist so model data can cross boundaries that can't carry
SwiftData `@Model` instances directly (e.g. networking, encoding, places needing `Identifiable` value types with a
stable `id`). `PeriodLogDTO` stores `userId` instead of embedding `User` — follow that pattern (pass a `User`
reference into `toModel(user:)`) when adding DTOs for models with relationships, rather than embedding the related
`@Model` object in the DTO.

## Current repo state notes

- **Branch `2-create-data-models` (current)**: has the full data/domain module set plus a real app entry point
  and a first UI screen. The project now actually links (`xcodebuild ... build` succeeds, launches, and renders in
  the simulator) — previously every build failed to link with an expected "Undefined symbols `_main`" error since
  there was no `@main`.
- **UI/data reconciliation (done)**: a sibling branch, `origin/3-create-home-view`, had diverged from a *different*
  initial commit (`e96a026`, not this branch's `1f0ea2e`) and had **no common ancestor** with this branch
  (`git merge-base` returns nothing) — it was built independently, with a working home screen but no Models
  directory at all. Rather than `git merge --allow-unrelated-histories` (which would fight over two independently
  -authored `project.pbxproj` files), its content was ported by hand: `HomePage.swift`/`TopBar.swift` moved from
  that branch's ad hoc `UI/Views`/`UI/Components` into this branch's `Modules/Features/Home/` convention,
  `Assets.xcassets` copied over as-is (its colorset folders are named `CycloPrimaryColor`/`CycloSecondaryColor`,
  but `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` — already set in this branch's
  pbxproj — generates the symbols as `Color.cycloPrimary`/`Color.cycloSecondary`, dropping the redundant "Color"
  suffix), and a new `CycloApp.swift` written to wire `PersistenceController`'s `ModelContainer` and
  `AppLockGateView` around `HomePage`. That branch's own `project.pbxproj`, empty/unused Objective-C bridging
  header, `LICENSE`, and `README.md` were left behind (this branch's copies are equivalent or richer).
  `origin/3-create-home-view` itself is now superseded/stale. **`HomePage` is still the original placeholder UI**
  (hardcoded "LOW"/"LOW" fertility and pregnancy-chance strings, a literal `"N"` for days-until-period) — wiring
  it to real `Repositories`/`Prediction` output is unstarted follow-up work, not a bug.
- Legacy duplicate top-level `Modules/Core/Models/` directory (broken stub leftovers, outside the Xcode-
  synchronized target root): already deleted. When working with models, use the `cyclo-ios/Modules/...` path.
