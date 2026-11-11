import Foundation

// Derived directly from CyclePredictionEngine's output, not a separate data source.
enum FertilityEngine {
    // `lutealPhaseLengths` is this user's own observed luteal-phase lengths (days from a
    // confirmed ovulation to the following period start), oldest to newest — empty until the
    // caller can derive any from logged OvulationTestResult peaks. `confirmedOvulationDate`
    // overrides inference entirely for this cycle when a positive/peak test was logged.
    //
    // Returns nil when the user reports being on hormonal contraception: natural ovulation is
    // suppressed, so showing a fertile window would be medically misleading. Callers render
    // nothing rather than checking a flag.
    static func fertilityWindow(
        predictedNextPeriodStart: Date,
        lutealPhaseLengths: [Double],
        prior: CyclePrior,
        confirmedOvulationDate: Date? = nil,
        isOnHormonalContraception: Bool,
        calendar: Calendar = .current
    ) -> FertilityWindow? {
        guard !isOnHormonalContraception else { return nil }

        let ovulationDate: Date
        let isConfirmed: Bool
        if let confirmedOvulationDate {
            ovulationDate = confirmedOvulationDate
            isConfirmed = true
        } else {
            let lutealPhaseLength = blendedLutealPhaseLength(observed: lutealPhaseLengths, prior: prior)
            ovulationDate = calendar.date(
                byAdding: .day, value: -Int(lutealPhaseLength.rounded()), to: predictedNextPeriodStart
            ) ?? predictedNextPeriodStart
            isConfirmed = false
        }

        // ~5 days of sperm survival before ovulation, plus the day of ovulation itself and ~24hr
        // of egg viability after it (ACOG-cited, see ARCHITECTURE.md).
        let fertileStart = calendar.date(
            byAdding: .day, value: -(PredictionConstants.fertileWindowLength - 1), to: ovulationDate
        ) ?? ovulationDate
        let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulationDate) ?? ovulationDate

        return FertilityWindow(
            estimatedOvulationDate: ovulationDate,
            fertileWindowStart: fertileStart,
            fertileWindowEnd: fertileEnd,
            isConfirmedByTest: isConfirmed
        )
    }

    private static func blendedLutealPhaseLength(observed: [Double], prior: CyclePrior) -> Double {
        guard !observed.isEmpty else { return prior.meanLutealPhase }

        if observed.count == 1 {
            let weight = PredictionConstants.singleObservationShrinkageWeight
            return weight * observed[0] + (1 - weight) * prior.meanLutealPhase
        }

        let sampleMean = observed.reduce(0, +) / Double(observed.count)
        let sampleVariance = observed.reduce(0) { $0 + pow($1 - sampleMean, 2) } / Double(observed.count - 1)
        let standardErrorVariance = sampleVariance / Double(observed.count)

        return (prior.lutealPhaseVariance * sampleMean + standardErrorVariance * prior.meanLutealPhase)
            / (prior.lutealPhaseVariance + standardErrorVariance)
    }
}
