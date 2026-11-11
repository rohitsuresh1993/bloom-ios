# Bloom — Feature Development Roadmap (post-architecture)

## Context

The data/domain layer (`Core/Models`, `Core/Persistence`, `Core/Repositories`, `Prediction`, `Auth`, `Security`,
`HealthKitIntegration`) is fully built and already verified to compile — but none of it is reachable by a user
today. `HomePage` is still the original placeholder UI (hardcoded "LOW"/"LOW", a literal "N"), its buttons are
no-ops, and there's no Onboarding, Logging, Settings, or Insights screen, and no test target. This plan sequences
the remaining feature work needed to turn the working backend into a usable app, and identifies which parts are
independent enough to build in parallel via subagents.

Per the user's decisions this session:
- Onboarding's self-reported cycle-length bucket gets wired into `PriorTable` (not dropped) — it should actually
  shift the prediction, not just be collected and ignored.
- Batch 1 below runs now as 4 parallel subagents, each in its own git worktree/branch (`isolation: "worktree"`),
  so they can work simultaneously without stepping on each other's uncommitted changes. Each branch is reviewed
  and merged in individually once its agent reports back — not auto-merged.

## Current state recap

**Built, not yet wired to any UI**: `User`/`PeriodLog`/`Log` models + 12 log-category enums, DTOs, `CycleRepository`/
`LogRepository`/`UserRepository`, `CyclePredictionEngine`/`FertilityEngine`/`SymptomCorrelationEngine`/`PriorTable`,
Sign in with Apple (`AppleSignInManager`), biometric app lock (`AppLockManager`, already wraps the app shell via
`AppLockGateView` but defaults off with no Settings UI to enable it), HealthKit write-only export (`HealthKitExporter`,
not triggered by anything, no Info.plist/entitlement yet).

**Not built at all**: `Features/Onboarding`, `Features/Logging`, `Features/Settings`, `Features/Insights`, test target.

**Approved design reference**: `mockups/home-redesign.html` — cycle-phase ring (replacing the old week-only picker,
now with the 7-day calendar strip kept above it), confidence label, fertility card, symptom/mood "patterns" card
in plain-sentence form, quick-log icon row, today's-log chip strip.

## Batch 1 — 4 parallel, worktree-isolated tracks (run now)

### Track A — Wire HomePage to real data
Replace the placeholder `HomePage` with the approved mockup design, backed by real repository/prediction calls.

- New `HomeViewModel` (`ObservableObject`) owns data-fetching/computation so `HomePage` itself stays thin —
  mirrors the `AppLockGateViewModel` pattern already used in `Modules/Security/AppLockGateView.swift`.
- Pulls: `UserRepository.currentUser()` (DOB, conditions) → `PriorTable.lookup(...)`; `CycleRepository.allPeriodLogs()`
  → cycle-length history → `CyclePredictionEngine.predictNextPeriod(...)`; its output → `FertilityEngine.fertilityWindow(...)`;
  `LogRepository.log(on: Date())` for today's log chip strip.
- Requires extending `SymptomCorrelationEngine` to also bucket `Mood`, not just `Symptoms` (currently
  `SymptomObservation`/`PhaseFrequency` are `Symptoms`-only) — needed for the patterns card's mood sentences to be real.
- Add a small per-case phrasing lookup (`Symptoms`/`Mood` → "feel some cramps" / "feel bloated" / etc.) to turn
  `PhaseFrequency` results into the mockup's sentence format; only surface items at ≥50% occurrence-over-cycles
  for the current phase (frequency floor, avoids a wall of one-off noise).
- Quick-log row buttons get an interim fast path for this batch (e.g. tapping "Period" calls
  `CycleRepository.startPeriod(on: Date())` directly) since `Features/Logging` doesn't exist yet in this same
  batch — upgraded to open Logging's real screens in the post-batch integration pass below.
- Files: `Modules/Features/Home/HomePage.swift`, `Modules/Features/Home/TopBar.swift` (minor), new
  `Modules/Features/Home/HomeViewModel.swift`, `Modules/Prediction/SymptomCorrelationEngine.swift`.
- Does not touch `BloomApp.swift`, `project.pbxproj`, or repository internals (calls, doesn't modify, them).

### Track B — Onboarding flow
New `Features/Onboarding` collecting: last period start date (anchors the first `PeriodLog` via
`CycleRepository.logPeriod`/`startPeriod`), a rough self-reported cycle-length bucket, date of birth, self-reported
conditions (multi-select `MenstrualCondition`), and an optional, skippable Sign in with Apple offer (via the
already-built `AppleSignInManager`).

- **PriorTable extension** (resolves the bucket-is-collected-but-unused gap): add an optional
  self-reported-length parameter to `PriorTable.lookup(...)` that nudges the row's `meanCycleLength` by a small,
  documented, tunable delta per bucket (e.g. "shorter" −3 days, "longer" +3 days, "~28 days"/"not sure" no
  shift) — add the constants to `PredictionConstants.swift`, same "working default, not a derived constant"
  honesty standard the rest of that file already uses.
- **Routing**: `BloomApp.swift` branches to Onboarding vs. `HomePage` based on a new `"bloom.onboardingCompleted"`
  `UserDefaults` flag — same simple-`UserDefaults`-bool pattern `AppLockManager` already uses for
  `isAppLockEnabled`, set true once onboarding's last step completes.
- Files: new `Modules/Features/Onboarding/*`, `Modules/Prediction/PriorTable.swift` + `PredictionConstants.swift`,
  `BloomApp.swift` (routing branch only).
- Does not touch `HomePage.swift`, `project.pbxproj`, or repository internals.

### Track C — Logging flow
New `Features/Logging`: (1) a period start/end screen calling `CycleRepository.startPeriod`/`endPeriod`/`logPeriod`,
(2) a day-log entry screen covering the full `Log` surface (mood, symptoms, sexualActivity, sexDrive,
vaginalDischarge, ovulationTestResult, pregnancyTest, oralContraceptiveStatus, physicalActivity,
digestionAndStool, flowIntensity, other) calling `LogRepository.saveLog`/`log(on:)`.

- Files: new `Modules/Features/Logging/*` only.
- Does not touch `CycleRepository.swift`/`LogRepository.swift` (calls existing methods only), `BloomApp.swift`, or
  `project.pbxproj`.

### Track D — HealthKit entitlement + export wiring
1. Add `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` via `INFOPLIST_KEY_*` build settings
   (matching this project's existing Xcode-16 auto-generated-Info.plist convention — check that before adding a
   standalone `Info.plist`).
2. Add the HealthKit capability + a new `.entitlements` file to the target in `project.pbxproj`.
3. Wire `CycleRepository` and `LogRepository` to call `HealthStoreWriting` (`HealthKitExporter`) after a
   successful save, per the original architecture decision ("export happens from the repository layer after a
   successful SwiftData save").

- **Required to avoid breaking Track C's concurrently-written call sites**: add the `HealthStoreWriting`
  dependency as a *defaulted* initializer parameter (`healthStore: HealthStoreWriting = HealthKitExporter()`) on
  both repositories, so existing `CycleRepository(modelContext:)`/`LogRepository(modelContext:)` call sites keep
  compiling unchanged.
- Files: `bloom-ios.xcodeproj/project.pbxproj` (capability + entitlements reference), new
  `bloom-ios/bloom-ios.entitlements`, Info.plist build settings, `Modules/Core/Repositories/CycleRepository.swift`,
  `Modules/Core/Repositories/LogRepository.swift`.
- Sole track touching `project.pbxproj` in this batch — avoids a merge conflict with the other three.

### Post-Batch-1 integration pass (sequential, after all 4 branches are reviewed and merged)
- Re-point Home's quick-log row at Logging's real screens instead of Track A's interim direct-repository-call
  fast path.
- Clean `xcodebuild` verification, then a manual device walk-through: onboarding → log a period → Home reflects
  real ring/fertility/patterns data → confirm the entry shows up in the Health app.

## Batch 2 — 3 parallel tracks, after Batch 1 is merged and verified

### Track E — Settings screen
App lock on/off + PIN set (`AppLockManager`, already supports this fully), Sign in with Apple status/offer
(`AppleSignInManager`), HealthKit export toggle, edit known conditions — reuses Onboarding's conditions-picker
component from Track B, which is why this is sequenced after Batch 1 rather than alongside it.
Files: new `Modules/Features/Settings/*`.

### Track F — Insights dashboard
Deeper `SymptomCorrelationEngine` surfacing (full phase-by-phase breakdown, not just "today") plus a Swift Charts
visualization of cycle-length history over time. Files: new `Modules/Features/Insights/*`.

### Track G — Test target
Add a `bloom-iosTests` target (Swift Testing, `@Test`/`#expect`) per the original architecture plan's testing
priorities: table-driven `CyclePredictionEngine` tests (0/1/2/3/6/12-cycle inputs, regular vs. high-variance
series, DST/year-boundary dates), in-memory-`ModelContainer` repository tests, DTO round-trip tests,
`SymptomCorrelationEngine` phase-bucketing tests. Touches `project.pbxproj` (new target) — run solo in this
batch, no other pbxproj edits concurrently.

## Anytime, low-conflict — can run alongside either batch

### Track H — PriorTable real research-sourced values
Replace the placeholder condition-variance multipliers in `PriorTable.swift` with a carefully-sourced research
pass per age bucket/condition (PCOS, endometriosis, thyroid, perimenopause-specific cycle statistics), per the
follow-up explicitly flagged in the original architecture plan. Touches only `PriorTable.swift` — near-zero
conflict risk with anything else.

## Verification

- Each worktree branch must pass a clean `xcodebuild -project bloom-ios.xcodeproj -scheme bloom-ios -sdk
  iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build` before merge — same bar used
  throughout this project so far.
- After the Batch 1 integration pass: manual walk-through on the user's physical device (already set up for
  wireless debugging) covering onboarding → first period log → Home showing real data → a Health app entry.
- Batch 2's Track G becomes the real automated verification harness for Prediction/Repositories going forward;
  until then, verification stays manual-walkthrough + clean-build, consistent with how every module so far in
  this project has been verified.
