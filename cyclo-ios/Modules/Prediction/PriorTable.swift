import Foundation

// Stratified cold-start prior for one (age bucket, known conditions) combination. `mean`/
// `variance` describe the population-level belief about cycle length and luteal-phase length
// before this user's own data is blended in — see CyclePredictionEngine.
struct CyclePrior {
    let meanCycleLength: Double
    let cycleLengthVariance: Double
    let meanLutealPhase: Double
    let lutealPhaseVariance: Double
}

enum AgeBucket: CaseIterable {
    case under20
    case twentiesToThirties
    case fortyPlus

    init(age: Int) {
        switch age {
        case ..<20: self = .under20
        case 20..<40: self = .twentiesToThirties
        default: self = .fortyPlus
        }
    }
}

// Rough self-reported cycle-length bucket collected once at onboarding (see
// Features/Onboarding) and stored in UserDefaults, not as a persisted model field — it's a
// cold-start-only nudge that naturally stops mattering once the Bayesian blend in
// CyclePredictionEngine has enough of the user's own cycle history to dominate the prior.
enum SelfReportedCycleLengthBucket: String, CaseIterable {
    case shorter
    case typical
    case longer
    case notSure

    // Flat nudge applied to the prior's mean cycle length — see PredictionConstants for why
    // these are working defaults, not sourced per-bucket figures.
    var meanCycleLengthDelta: Double {
        switch self {
        case .shorter: return PredictionConstants.selfReportedShorterCycleLengthDelta
        case .longer: return PredictionConstants.selfReportedLongerCycleLengthDelta
        case .typical, .notSure: return 0
        }
    }
}

// Developer-trained-offline lookup table, not ML: a richer starting prior than one flat
// population constant, bundled frozen, never retrained, never phones home.
//
// IMPORTANT: the row values below are general-population figures from the research cited in
// ARCHITECTURE.md (mean cycle ~27-28 days, mean luteal phase ~12-14 days, σ₀² ≈ 16). The
// condition multipliers are *not* sourced per-condition statistics — they're a placeholder
// widening so known-irregularity conditions don't get a falsely narrow band before the real,
// carefully-sourced per-condition research pass (flagged as follow-up work in ARCHITECTURE.md)
// ships actual PCOS/endometriosis/thyroid/perimenopause-specific figures.
enum PriorTable {
    private static let baseRows: [AgeBucket: CyclePrior] = [
        .under20: CyclePrior(
            meanCycleLength: 28.5, cycleLengthVariance: 20,
            meanLutealPhase: 13, lutealPhaseVariance: 10
        ),
        .twentiesToThirties: CyclePrior(
            meanCycleLength: 28, cycleLengthVariance: 16,
            meanLutealPhase: 13, lutealPhaseVariance: 9
        ),
        .fortyPlus: CyclePrior(
            meanCycleLength: 29, cycleLengthVariance: 25,
            meanLutealPhase: 12, lutealPhaseVariance: 10
        )
    ]

    private static let conditionVarianceMultiplier: [MenstrualCondition: Double] = [
        .pcos: 2.5,
        .perimenopause: 2.0,
        .thyroidDisorder: 1.5,
        .uterineFibroids: 1.3,
        .endometriosis: 1.2
    ]

    static func lookup(
        ageBucket: AgeBucket,
        conditions: [MenstrualCondition],
        selfReportedLengthBucket: SelfReportedCycleLengthBucket? = nil
    ) -> CyclePrior {
        let base = baseRows[ageBucket] ?? baseRows[.twentiesToThirties]!
        let multiplier = conditions.compactMap { conditionVarianceMultiplier[$0] }.max() ?? 1.0
        let lengthDelta = selfReportedLengthBucket?.meanCycleLengthDelta ?? 0

        return CyclePrior(
            meanCycleLength: base.meanCycleLength + lengthDelta,
            cycleLengthVariance: base.cycleLengthVariance * multiplier,
            meanLutealPhase: base.meanLutealPhase,
            lutealPhaseVariance: base.lutealPhaseVariance * multiplier
        )
    }
}
