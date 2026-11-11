import Foundation

// Plain output of CyclePredictionEngine — never a @Model type, so the engine stays usable from
// hand-built arrays in a unit test with no database involved.
struct CyclePrediction {
    let predictedStartDate: Date
    let earliestLikelyStartDate: Date
    let latestLikelyStartDate: Date
    let predictedCycleLength: Double
    let posteriorVariance: Double
    let confidence: ConfidenceLevel
    let isIrregular: Bool
}
