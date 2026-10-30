import Foundation

// UI-agnostic, no SwiftData import by convention (see ARCHITECTURE.md "Data flow") — takes only
// plain values in (this user's own observed cycle lengths, their PriorTable row) and returns a
// plain CyclePrediction out, so it's testable with hand-built arrays and no ModelContext.
enum CyclePredictionEngine {
    // `cycleLengths` is this user's own history, oldest to newest, in days. Empty for a brand-new
    // user (cold start) — the prior then stands alone.
    static func predictNextPeriod(
        cycleLengths: [Double],
        lastPeriodStartDate: Date,
        prior: CyclePrior,
        calendar: Calendar = .current
    ) -> CyclePrediction {
        let observationCount = cycleLengths.count
        let trailing = Array(cycleLengths.suffix(PredictionConstants.trailingWindowCycleCount))

        let posteriorMean: Double
        let posteriorVariance: Double

        if trailing.isEmpty {
            posteriorMean = prior.meanCycleLength
            posteriorVariance = prior.cycleLengthVariance
        } else if trailing.count == 1 {
            let observed = trailing[0]
            let weight = PredictionConstants.singleObservationShrinkageWeight
            posteriorMean = weight * observed + (1 - weight) * prior.meanCycleLength
            posteriorVariance = prior.cycleLengthVariance
        } else {
            (posteriorMean, posteriorVariance) = blend(observations: trailing, prior: prior.meanCycleLength, priorVariance: prior.cycleLengthVariance)
        }

        let posteriorStandardDeviation = posteriorVariance.squareRoot()
        let predictedStart = calendar.date(
            byAdding: .day, value: Int(posteriorMean.rounded()), to: lastPeriodStartDate
        ) ?? lastPeriodStartDate
        let earliest = calendar.date(
            byAdding: .day, value: -Int(posteriorStandardDeviation.rounded()), to: predictedStart
        ) ?? predictedStart
        let latest = calendar.date(
            byAdding: .day, value: Int(posteriorStandardDeviation.rounded()), to: predictedStart
        ) ?? predictedStart

        return CyclePrediction(
            predictedStartDate: predictedStart,
            earliestLikelyStartDate: earliest,
            latestLikelyStartDate: latest,
            predictedCycleLength: posteriorMean,
            posteriorVariance: posteriorVariance,
            confidence: .forObservationCount(observationCount),
            isIrregular: isIrregular(cycleLengths: trailing)
        )
    }

    // Coefficient of variation over the trailing window — a data-driven signal independent of
    // self-reported conditions. Only ever used to widen confidence bands and soften UI copy;
    // never to claim a diagnosis (see ARCHITECTURE.md "Irregularity").
    static func isIrregular(cycleLengths: [Double]) -> Bool {
        guard cycleLengths.count >= 2 else { return false }
        let mean = cycleLengths.reduce(0, +) / Double(cycleLengths.count)
        guard mean > 0 else { return false }
        let variance = cycleLengths.reduce(0) { $0 + pow($1 - mean, 2) } / Double(cycleLengths.count - 1)
        let coefficientOfVariation = variance.squareRoot() / mean
        return coefficientOfVariation > PredictionConstants.irregularityCVThreshold
    }

    // The normal-normal conjugate update: precision-weighted (inverse-variance) blend of the
    // prior with the sample mean of this user's own observations. See ARCHITECTURE.md for the
    // plain-terms explanation of why this is the right tool here.
    private static func blend(
        observations: [Double], prior priorMean: Double, priorVariance: Double
    ) -> (mean: Double, variance: Double) {
        let sampleMean = observations.reduce(0, +) / Double(observations.count)
        let sampleVariance = observations.reduce(0) { $0 + pow($1 - sampleMean, 2) } / Double(observations.count - 1)
        let standardErrorVariance = sampleVariance / Double(observations.count)

        let posteriorMean = (priorVariance * sampleMean + standardErrorVariance * priorMean)
            / (priorVariance + standardErrorVariance)
        let posteriorVariance = 1 / (1 / priorVariance + 1 / standardErrorVariance)
        return (posteriorMean, posteriorVariance)
    }
}
