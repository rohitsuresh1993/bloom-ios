# Cyclo — Architecture, Tech Stack & Prediction Strategy

## Context

Cyclo is meant to be a full-featured replacement for Flo (period/symptom logging, prediction, fertility
tracking, insights) built around one non-negotiable principle: the user's period and symptom data never touches
a server anyone but the user controls. This is a direct response to Flo's repeated data breaches and the
reporting that Meta employees mocked Flo users' period data after a data-sharing deal — the architecture needs
to make that kind of violation structurally impossible, not just promise it in a privacy policy.

The repo today is close to a blank slate: SwiftData models for `User`, `PeriodLog`, and `Log` (+ 10 symptom-
category enums) exist on branch `2-create-data-models`; a disconnected UI stub (`HomePage`, `TopBar`, a
placeholder `@main` app) exists on `origin/3-create-home-view`; nothing else — no ML, no HealthKit, no security,
no auth, no networking, no dependencies — exists anywhere in the repo. This document fixes the stack and
architecture, and corrects several gaps found in the existing models, before more UI/feature code is built on
top of them.

Decisions locked in during the architecture-planning session (2026-10-30):
1. **Sync**: v1 ships strictly local-only. Models are shaped now so an opt-in CloudKit sync can be bolted on
   later without a data migration.
2. **HealthKit**: Cyclo writes cycle data to HealthKit at **full Flo-style parity** (menstrual flow, intermenstrual
   bleeding, ovulation test results, sexual activity, contraceptive use). HealthKit is a one-way **export
   target**, never a read source — SwiftData stays the sole source of truth. This isn't a privacy boundary (both
   live on-device); it's to avoid two data sources that could disagree — if the prediction engine could read from
   either, a HealthKit edit from another app or a failed/delayed sync would make predictions non-deterministic.
   Keeping SwiftData the only thing the engine reads keeps it a single source of truth.
3. **File protection**: `NSFileProtectionComplete` (strictest — the store is unreadable whenever the device is
   locked, including for background work).
4. **Account model**: Cyclo keeps an optional **Sign in with Apple** layer (no passwords, ever) as a future
   identity anchor, but it does not gate any core logging functionality — a user can log periods/symptoms fully
   offline without ever signing in. Apple's opaque per-app user identifier is stored in Keychain, not in the
   SwiftData store, and is never sent anywhere (there's no server to send it to; its only purpose is as a stable
   identity for possible future multi-device features). `User.email` is dropped — there's no login flow to use
   it, and Sign in with Apple's optional relay email isn't needed for anything either.
5. **CloudKit-readiness schema fixes, and separately-found model gaps, both happen now** (full list below),
   while there's no real user data to migrate — cheapest possible time to fix them.
6. **Fertility tracking is in scope** (ovulation estimate + fertile window), not just period prediction.
7. **Onboarding collects self-reported conditions** from a fixed list (not detected from data) to adjust
   prediction defaults — never framed as diagnosis.

## Tech Stack

- **Persistence**: SwiftData, local-only `ModelContainer` for v1 (`cloudKitDatabase: .none` in the
  `ModelConfiguration`, so flipping to `.private("iCloud.cyclo.cyclo-ios")` later is additive, not a rewrite).
  Use `VersionedSchema`/`SchemaMigrationPlan` from the start so migrations are additive-only going forward.
- **Prediction**: plain Swift statistics (Bayesian blending, see below) — no CoreML/CreateML, no day-level
  sequence/"next-token" model. A single user generates a few dozen scalar cycle-length observations a year —
  that's a weighted-average problem, not a model-training problem. A sequence model framed over calendar days
  doesn't fix this either: the natural periodic unit is the cycle (21-35 days), not the calendar month, and a
  sequence model only earns its complexity by pretraining on *many people's* day-level data — which reintroduces
  the pooled-data problem this architecture exists to avoid. The one legitimate way to use more-than-this-user's
  data is a model trained once, offline, by the developer, on **public research data** (not Cyclo users), shipped
  frozen in the app bundle — see "Stratified cold-start priors" below, which does exactly this at the
  statistical-table level without needing an ML framework at all. Swift Numerics only if circular-statistics
  needs arise later; Accelerate is unnecessary at this data scale.
- **Security at rest**: SwiftData store file protection = `NSFileProtectionComplete`. Optional, user-enabled
  biometric app-lock via `LocalAuthentication` (`LAContext` — resolves to Face ID or Touch ID automatically based
  on device hardware, no separate code path needed per biometric type), implemented as a presentation-layer gate
  in front of the root `WindowGroup` — not a data-layer concern. Keychain holds: an optional PIN fallback if
  biometrics are unavailable, and the Sign in with Apple opaque user identifier (see Auth below). No other secrets
  exist — there's no server, so no passwords/API tokens to store.
- **Auth**: Sign in with Apple (`AuthenticationServices`), optional and skippable, never blocking core app use.
  No password, no custom credential storage — Apple handles identity verification entirely; Cyclo only persists
  the opaque per-app user identifier Apple returns, in Keychain.
- **HealthKit**: `HKHealthStore.requestAuthorization(toShare:read:)` with **write-only** types — no read types
  requested, since HealthKit is never a source of truth. Export happens from the repository layer after a
  successful SwiftData save, behind a `HealthStoreWriting` protocol so it's mockable/optional.
- **UI**: SwiftUI (already chosen). `Swift Charts` (first-party) likely covers Insights visualizations — no
  charting dependency needed.
- **Dependencies**: first-party Apple frameworks only, zero SPM (Swift Package Manager — Apple's built-in
  dependency manager) packages, for v1. Every third-party dependency is an unaudited trust surface for an app
  whose entire pitch is trustworthiness, and nothing currently required needs one.
- **Testing**: add a `cyclo-iosTests` target (Swift Testing, `@Test`/`#expect`). Priorities: table-driven tests of
  the prediction engine (0/1/2/3/6/12-cycle inputs, regular vs. high-variance synthetic series, DST/year-boundary
  dates); in-memory-`ModelContainer` repository tests; DTO round-trip tests. Wrap HealthKit, LocalAuthentication,
  and Sign in with Apple behind protocols (`HealthStoreWriting`, `BiometricAuthenticating`, `AppleSignInProviding`)
  specifically so they're mockable — their real implementations aren't reliably unit-testable in a simulator.
  (Full detailed test-case design to be discussed separately when implementation starts.)

## Module Architecture

Extends the existing `Modules/<Area>` convention:

```
cyclo-ios/Modules/
  Core/
    Models/              (existing: User, PeriodLog, Log, LogCategories/* — see fixes below)
    Persistence/         (NEW: ModelContainer setup, schema versioning/migration plans)
    Repositories/         (NEW: CycleRepository, LogRepository, UserRepository — protocol + SwiftData impl)
  Prediction/              (NEW: UI-agnostic, no SwiftData import, independently testable)
    CyclePredictionEngine.swift     (pure math: priors, Bayesian blend, confidence windows)
    FertilityEngine.swift           (ovulation estimate + fertile window, derived from CyclePredictionEngine output)
    SymptomCorrelationEngine.swift  (phase-bucketed frequency correlation over Log data)
    PriorTable.swift                 (stratified cold-start priors by age bucket / condition — static data)
    Models/ (CyclePrediction, FertilityWindow, ConfidenceLevel — plain Swift structs)
  HealthKitIntegration/    (NEW)
    HealthStoreWriting.swift (protocol)
    HealthKitExporter.swift  (concrete impl, write-only categories)
    HealthKitAuthorizationManager.swift
  Auth/                    (NEW)
    AppleSignInProviding.swift (protocol)
    AppleSignInManager.swift   (concrete impl, Keychain-backed identifier storage)
  Security/                (NEW)
    AppLockManager.swift (LocalAuthentication wrapper)
    AppLockGateView.swift (SwiftUI lock screen in front of WindowGroup)
  Features/
    Onboarding/ Home/ Logging/ Insights/ Settings/
```

**Data flow**: Feature views never touch `ModelContext` directly — they call `Repositories`, which own SwiftData
access, are the seam where CloudKit sync later hooks in (swap `ModelConfiguration`, no call-site changes), and
trigger HealthKit export post-save. `Prediction` takes only plain data (dates, DTOs, the user's recorded
conditions/age bucket) in and plain `CyclePrediction`/`FertilityWindow` values out — never a `@Model` type. This
isn't a privacy boundary (everything's already on-device either way) — it's a testability/decoupling convention:
the engine can be driven by hand-built arrays in a unit test with no database involved. Every run is still
per-individual — the repository looks up *that user's own* history and hands only their data in; the only
genuinely population-level numbers are the small set of constants in `PriorTable`, fixed at build time from
public research, used only until that same person has enough of their own history to dominate the blend.
HealthKit export is one-directional and repository-triggered; nothing reads from HealthKit back into prediction.
`AppLockGateView` wraps the `@main` app's root content (replacing the placeholder `pageApp.swift` once the UI
branch is merged in).

## Model fixes (apply now, before UI is built on top of the current shapes)

Reviewed all existing files (`User.swift`, `PeriodEvent.swift`, `Log.swift`, `LogCategories/*.swift`) for fields,
validation, and naming. Findings and fixes, bundled together since nothing depends on the current schema yet:

- **`User.swift`**: drop `email` (no login flow needs it). Drop `@Attribute(.unique)` on `uuid` — SwiftData's
  CloudKit integration doesn't support unique constraints at all, so it must go for the opt-in-sync path to stay
  additive; uniqueness becomes the repository's job instead (trivial for a one-profile-per-device app). Add
  `modifiedAt: Date` (free now, helps future CloudKit conflict resolution). Add
  `knownConditions: [MenstrualCondition] = []` (self-reported at onboarding, see Prediction Strategy below). Add
  repository-level validation: `dateOfBirth` not in the future, within a sane age range.
- **`PeriodEvent.swift`**: rename the file to `PeriodLog.swift` to match the class name it actually contains.
  Change `var user: User` to `var user: User?` (CloudKit requires all relationship properties optional). Add an
  explicit `id: UUID = UUID()` (currently relies on SwiftData's implicit `persistentModelID`, which isn't a stable
  CloudKit identity). Add repository-level validation: `endDate >= startDate`.
- **`Log.swift`**: most single-value optional properties become optional **arrays**, since a day can realistically
  have more than one value in these categories — `mood: [Mood]?`, `symptoms: [Symptoms]?`,
  `physicalActivity: [PhysicalActivity]?`, `digestionAndStool: [DigestionAndStool]?`, `other: [Other]?`. Some stay
  single-valued because they're genuinely one-reading-per-day: `vaginalDischarge`, `ovulationTestResult` (renamed,
  see below), `pregnancyTest`, `oralContraceptiveStatus`, `sexDrive` (new, see below). Add a new single-valued
  `flowIntensity: FlowIntensity?` category (light/medium/heavy/spotting) so users who want per-day granularity can
  log it, without changing the existing fast "tap to start/end period" flow on `PeriodLog`. Add `id: UUID =
  UUID()` to `Log` for the same CloudKit-identity reason as `PeriodLog`.
- **`SexAndSexDrive` enum**: currently conflates two unrelated things (activity type and libido level) into cases
  that aren't mutually exclusive in real life, so today's model can't record both on the same day. Split into
  `SexualActivity` (array-valued: `didntHaveSex`, `protectedSex`, `unprotectedSex`, `oralSex`, `analSex`,
  `masturbation`, `sensualTouch`, `sexToys`, `orgasm`) and `SexDrive` (single-valued: `highSexDrive`,
  `neutralSexDrive`, `lowSexDrive`).
- **`OvulationTest` enum → real result, not metadata**: current cases (`.logOvulationTest`, `.didntTakeTests`,
  `.ovulationMyMethod`) never record an actual test reading — a bug relative to the now-in-scope fertility
  tracker, which needs a real positive/negative/peak value to work at all. Redesign as
  `OvulationTestResult: negative, lowFertility, highFertility, peak` (matches how real OPK strips report), stored
  as `ovulationTestResult: OvulationTestResult?` on `Log` (`nil` = no test taken that day, consistent with every
  other optional category's convention).
- **`OralContraceptiveStatus` enum**: add `.missedPill`. Being on hormonal contraception suppresses natural
  ovulation, so this isn't just a logging nicety — the `FertilityEngine` must check it and suppress the fertile-
  window display entirely for users who report it, since showing one would be medically misleading.
- **`DigestionAndStool` enum**: add a baseline `.normal` case, consistent with `Symptoms.everythingIsFine`.
- New `MenstrualCondition` enum (for `User.knownConditions`, self-selected at onboarding, never inferred):
  `pcos`, `endometriosis`, `thyroidDisorder`, `uterineFibroids`, `perimenopause`, `onHormonalContraception`,
  `other`, `preferNotToSay`.
- Housekeeping already flagged in `CLAUDE.md`: the legacy top-level `Modules/Core/Models/` duplicate (broken
  stubs, not part of the build target) still needs deleting — unchanged by this plan, just restating it's still
  pending.

## Period, Fertility & Symptom Prediction Strategy

### Cold start (0 cycles): stratified priors, not one flat constant
Rather than a single 28-day constant for everyone, ship a small **static lookup table** (`PriorTable`) — trained
once, offline, by the developer, from public research figures, bundled as a frozen asset. It's keyed by age
bucket and self-reported `knownConditions`, returning a `(meanCycleLength, cycleVariance, meanLutealPhase)` row
to seed the same Bayesian blend described below, instead of one number for everyone. This is still not ML in the
deep-learning sense — it's a richer starting prior — and it ships static, never retrains, never phones home.
**The actual table values need a dedicated, carefully-sourced research pass before shipping** (e.g. PCOS-specific
cycle-length/variance figures) — don't hardcode guessed numbers; this is flagged as a follow-up task, not done in
this planning pass. For the *general* (no condition reported) baseline row, real research gives: mean cycle
length ~27-28 days, mean luteal phase ~12-14 days, mean follicular phase ~13-17 days. The follicular phase is the
larger driver of cycle-length variability — a 2024 cohort (53 women, 676 cycles) found follicular-phase variance
roughly double luteal-phase variance (10.3-11.2 vs. 4.3 days²) — but luteal phase is **not** a near-fixed 14 days
either: 55% of women in that cohort had at least one luteal phase under 10 days, so the prior's variance for the
luteal estimate should reflect real spread, not false precision.
([source](https://academic.oup.com/humrep/article/39/11/2565/7775370),
[source](https://uk.clearblue.com/sites/default/files/HCP_Publications/Articles-Pregnancy/Variability_in_length_of_menstrual_cycles_within_and_between_women.pdf))

Onboarding collects: last period start date (anchors the first estimate), a rough self-reported cycle-length
bucket ("~28 days" / "shorter" / "longer" / "not sure"), date of birth (age-bucket lookup key), and the
self-reported conditions list (lookup key + fertility-window suppression input) — see list below. Nothing else;
no symptom/sexual-activity history at onboarding, since none of it improves a day-1 estimate and it's exactly the
kind of over-collection this product is positioned against. Shown as a date **range**, never a single date,
clearly labeled low-confidence.

**Onboarding conditions list** (self-selected, multi-select, never inferred/detected from logged data): PCOS,
Endometriosis, Thyroid disorder, Uterine fibroids, Perimenopause, Currently on hormonal contraception,
Other/none of these, Prefer not to say.

### Early-to-mature data: one formula, not two code paths
Precision-weighted (inverse-variance) Bayesian blending of the prior (now condition/age-stratified, not flat)
with the user's own observed cycle lengths:

```
posterior mean = (σ₀² · x̄ₙ + (s²ₙ/n) · μ₀) / (σ₀² + s²ₙ/n)
```

**What this actually is, in plain terms**: it's the standard way to combine two Gaussian (bell-curve) estimates of
the same unknown number, each weighted by how much you trust it. Think of two experts guessing this person's true
average cycle length — Expert A is the population/stratified prior (`μ₀`, `σ₀²`): confident-ish, but generic,
and never gets more sure of itself. Expert B is this person's own logged cycles (`x̄ₙ`, `s²ₙ`): at first very
unsure (barely any data), but gets *more* confident the more cycles they've watched, because the standard error
of a sample mean (`s²ₙ/n`) shrinks as `n` grows. The formula weights each expert by **1/their own variance**
("precision") and takes a weighted average — the same technique used in meta-analysis to combine independent
studies, or sensor fusion to combine two noisy readings. This is the textbook "normal-normal conjugate" Bayesian
update: if your prior belief and new evidence are both Gaussian, the updated belief is also Gaussian, and its
mean is exactly this precision-weighted average — not something invented for this app.

Where: `μ₀`, `σ₀²` = the `PriorTable` row for this user (age bucket + conditions); `x̄ₙ`/`s²ₙ` = this user's own
mean/variance over their `n` logged cycles. For `n = 1` (no sample variance computable yet), use a fixed
shrinkage instead: `0.3 · x_observed + 0.7 · μ₀`. **Both the prior's variance and the n=1 shrinkage weight are
working defaults, not derived constants** — `σ₀ = 4 days` is a rough stand-in loosely consistent with the ~3.4-day
SD found in the cited research, rounded for simplicity; `0.3` exists only as an engineering safety valve so one
weird first cycle (illness, stress, a data-entry slip) doesn't swing the estimate too hard. Treat both as "ship a
sane default, tune after watching real usage," not numbers to get exactly right up front.

Predicted next period start = last period start + posterior mean cycle length. Confidence band = the posterior
variance `1/(1/σ₀² + n/s²ₙ)`, directly driving the UI's uncertainty range. As `n` grows, the prior's weight
shrinks toward zero on its own — this is the entire mechanism for "getting smarter over time." There's no
separate "graduate to a smarter model" step to build; it's the same formula, naturally sliding trust from the
prior to the user's own data.

### Maturity checkpoint at 6 cycles — a convention, not a derived number
Being honest about this one: there is no study that identifies a precise "variability has now stabilized"
threshold. What exists: research commonly uses **4 cycles** as a practical minimum for estimating a person's own
variability (used by Clearblue's own variability analysis and a retrospective chart study restricted to this
population); the Apple Women's Health Study's public explainer uses 5 cycles as its "typical length" example; a
large self-tracking dataset study found its highest-data users averaging ~11 cycles
([source](https://arxiv.org/pdf/1909.11211)). **6** sits in a reasonable middle zone between "bare minimum" and
"high precision" — pick it as a defensible starting convention, document it as tunable, and don't treat it as
scientifically derived. Below ~5-6 cycles, sample variance itself is too noisy to trust (variance-of-a-variance
problem), which is exactly why the `n=1` shrinkage and the inverse-variance weighting exist — they already handle
the transition smoothly without a hard mode switch. Past 6 cycles, prefer a **recency-weighted trailing window
(last 6-12 cycles)** over an all-time average, since cycle characteristics drift with age, stress, and
medication — standard practice in cycle-tracking apps.

### No trained on-device ML model for v1 — stratified static priors instead, true personalization deferred
Restated from Tech Stack: a single user's cycle-length series is a few dozen scalars, which the Bayesian blend
already handles well; training a model would require either per-user data leaving the device, or a population
model trained on other users' data, both of which conflict with the core principle. The one real middle ground —
a developer-trained, offline, static `PriorTable` (above) — is scoped into v1. **True on-device personalization**
(e.g. CoreML model-update APIs fine-tuning a shipped base model using only that one user's local data, never
leaving the device) is a legitimate v2+ idea, explicitly deferred rather than rejected — revisit once the basic
engine has real usage data to show whether the simple blend is actually leaving accuracy on the table.

### Fertility window (newly in scope)
Derived directly from the cycle engine's output, not a separate data source: estimated ovulation date =
predicted next period start − predicted luteal-phase length (from the same stratified-prior/Bayesian-blended
mean used for cycle length). Fertile window = ~6 days, ending the day after estimated ovulation — based on
sperm surviving ~5 days in the reproductive tract plus ~12-24 hours of egg viability after release (ACOG-cited
figures) ([source](https://www.medicalnewstoday.com/articles/322951),
[source](https://www.healthline.com/health/fertility/predict-fertile-window)). If the user has logged a real
`ovulationTestResult` (positive/peak) via the fixed `OvulationTest` category, that directly confirms/overrides the
inferred window for that cycle rather than relying purely on inference. If the user reports
`onHormonalContraception`, **suppress the fertility window entirely** — showing one would be medically
misleading, since hormonal contraception suppresses natural ovulation.

### Irregularity (PCOS, perimenopause, etc.): widen and flag, don't force precision, don't diagnose
Two inputs now, not one: (1) the self-reported `knownConditions` from onboarding directly widen the prior and
suppress/soften fertility-window confidence up front, and (2) compute the coefficient of variation
(`CV = SD/mean`) over the trailing window as an ongoing data-driven check, flagging irregular when `CV` exceeds
roughly 0.12-0.15 (cycle-to-cycle variation beyond ~7-9 days), broadly consistent with clinical irregularity
thresholds. When flagged (by either input): widen the confidence band using the actual computed variance (never
clamp it narrower than the math says), switch UI copy to an explicit range instead of implied precision, and —
per explicit instruction — **never claim to detect a condition**; only ever reflect what the user told us at
onboarding plus honest uncertainty from their own data. Do not build a mixture/bimodal model for this — it's
over-engineering for the data volume and risks false confidence; flag + widen + honest copy is the right-sized
answer.

### Symptom prediction (secondary, modest scope)
Not forward prediction — phase-correlation over already-logged `Log` data. Bucket entries by cycle-relative day
(normalized into menstrual/follicular/ovulatory/luteal phases using the user's own typical cycle length) and
compute frequency/co-occurrence counts per phase per `LogCategory` case (e.g. "cramps logged in the 2 days
before your period in 4 of your last 5 cycles"). Presented as retrospective pattern-surfacing, not a forward
claim — the data volume and self-report noise don't support a confident forward prediction. No ML needed — a
group-by-and-count over local data, implemented in `SymptomCorrelationEngine`, tested the same way as the cycle
engine.

### Confidence communication everywhere
Every surfaced prediction carries a range/±day count and a qualitative label (`n<3` "still learning your cycle",
`n 3-5` "estimated", `n≥6` "based on your recent cycles"). The `HomePage` placeholder's "days until period" hero
number becomes "Next period: around Nov 12–18" style phrasing, not a bare single date — and softens further when
the irregularity flag is active. Fertility-window UI follows the same range-first convention, and simply doesn't
render at all when suppressed (hormonal contraception).

## Tunable constants (not structural — centralize, revisit freely later)

`σ₀² = 16` (general-population default, superseded per-row by `PriorTable` once that's built), `n=1` shrinkage
weight `0.3`, irregularity `CV` threshold `~0.12-0.15`, maturity checkpoint `6` cycles, trailing window `6-12`
cycles, fertile window length `6` days. Keep all of these in one place (e.g. a `PredictionConstants` file) so
they can be tuned without touching engine logic or rewriting test fixtures wholesale.

## Follow-up work explicitly flagged (not done in this planning pass)

- **`PriorTable` actual values**: needs a dedicated, carefully-sourced research pass per age bucket and per
  condition (especially PCOS/endometriosis/thyroid/perimenopause-specific cycle statistics) before shipping —
  don't hardcode guessed numbers.
- **Sign in with Apple flow details**: exact onboarding placement (offered once, skippable, revisitable later
  from Settings) to be designed when `Features/Onboarding` is built.
- **Testing plan**: detailed test-case design deferred to implementation time, per the user's request.

## Verification (when implementation starts)

- Unit-test the prediction engine first, against the table-driven cases described above, before any UI consumes it.
- Verify CloudKit-readiness schema changes compile and existing model relationships still behave correctly with
  `PeriodLog.user` optional (call sites must now unwrap).
- Confirm `NSFileProtectionComplete` doesn't break expected foreground behavior (there's no background work yet
  to conflict with it).
- Validate HealthKit writes in the Health app on a real device/simulator once `HealthKitExporter` exists, checking
  each written category (flow, intermenstrual bleeding, ovulation test, sexual activity, contraceptive).
- Validate Sign in with Apple's skip path actually leaves full logging functionality usable with zero account.
