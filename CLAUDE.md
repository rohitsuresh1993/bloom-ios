# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Cyclo is an early-stage iOS period/cycle-tracking app, built with SwiftUI + SwiftData. The project is currently
data-model-only: there is no app entry point, UI, or test target yet. Expect to build these out.

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

All source currently lives under `cyclo-ios/cyclo-ios/Modules/Core/Models/`. The module layout anticipates future
`Modules/<Feature>` separation, but only `Core/Models` exists so far.

See `ARCHITECTURE.md` for the full tech stack, module plan, and prediction strategy — this section just describes
the models as they exist in code today.

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

- **Branch `2-create-data-models` (current, HEAD = `fb96f88`)**: SwiftData models only, no UI, no `@main` App entry
  point, no Assets.xcassets. This is the branch CLAUDE.md describes above.
- **Branch `origin/3-create-home-view`**: a sibling branch, diverged from a *different* initial commit (`e96a026`,
  not `1f0ea2e`), with a working home screen (`cyclo-ios/UI/Views/pageApp.swift` — the `@main` entry point,
  `cyclo-ios/UI/Views/HomePage.swift`, `cyclo-ios/UI/Components/TopBar.swift`) plus `Assets.xcassets` defining
  `Color.cycloPrimary` / `Color.cycloSecondary`. It has **no Models directory at all** — built independently of
  this branch. The two branches will need to be reconciled/merged before the app has both data and UI.
- Legacy duplicate: a top-level `Modules/Core/Models/` directory (outside `cyclo-ios/`, not part of the
  Xcode-synchronized target root) holds broken/stub leftovers — empty files, a `Date` class that shadows
  `Foundation.Date`, references to a nonexistent `@Id` macro. It is **not compiled into the app**. As of this
  writing these stub files are staged in git's index (as adds) but already deleted from disk, and `LICENSE` /
  `README.md` are deleted from disk but unstaged — i.e. mid-cleanup, not yet committed either way. When working
  with models, always use the `cyclo-ios/Modules/...` path — that's the one actually compiled into the app. The
  top-level `Modules/` directory should eventually be deleted outright.
