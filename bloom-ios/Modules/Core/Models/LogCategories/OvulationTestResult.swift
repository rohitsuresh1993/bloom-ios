import Foundation

// The actual OPK (ovulation predictor kit / LH test) reading, matching how real test strips
// report results. nil on Log means no test was taken that day.
enum OvulationTestResult: Int, Codable {
    case negative = 0
    case lowFertility = 1
    case highFertility = 2
    case peak = 3
}
