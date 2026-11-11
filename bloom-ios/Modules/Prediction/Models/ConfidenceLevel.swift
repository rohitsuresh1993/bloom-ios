import Foundation

enum ConfidenceLevel {
    case stillLearning
    case estimated
    case basedOnRecentCycles

    static func forObservationCount(_ cycleCount: Int) -> ConfidenceLevel {
        switch cycleCount {
        case ..<3: return .stillLearning
        case 3..<PredictionConstants.maturityCheckpointCycleCount: return .estimated
        default: return .basedOnRecentCycles
        }
    }

    var label: String {
        switch self {
        case .stillLearning: return "Still learning your cycle"
        case .estimated: return "Estimated"
        case .basedOnRecentCycles: return "Based on your recent cycles"
        }
    }
}
