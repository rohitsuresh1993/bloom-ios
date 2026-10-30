import Foundation

// Centralized so these can be tuned from watching real usage without touching engine logic or
// rewriting test fixtures. None of these are derived constants — see ARCHITECTURE.md's
// "Prediction Strategy" section for what each one actually is and isn't.
enum PredictionConstants {
    // Fixed shrinkage toward the prior when a user has exactly one observed cycle, since sample
    // variance isn't computable from a single point yet.
    static let singleObservationShrinkageWeight = 0.3

    // Below this many logged cycles, sample variance is too noisy to fully trust on its own —
    // the inverse-variance blend already handles this smoothly, this just drives the UI label.
    static let maturityCheckpointCycleCount = 6

    // Prefer recency over all-time average: cycle characteristics drift with age, stress, and
    // medication.
    static let trailingWindowCycleCount = 12

    // CV = SD/mean over the trailing window. Beyond this, flag irregular and widen/soften the UI
    // rather than clamping the confidence band narrower than the math says.
    static let irregularityCVThreshold = 0.12

    // ~5 days of sperm survival + ~24hr egg viability (ACOG-cited), ending the day after
    // estimated ovulation.
    static let fertileWindowLength = 6

    // Assumed menstrual-flow duration for phase bucketing in SymptomCorrelationEngine. Not
    // currently derived from the user's own FlowIntensity logs — a reasonable fixed default
    // until that refinement is worth the complexity.
    static let assumedMenstrualPhaseLength = 5.0
}
