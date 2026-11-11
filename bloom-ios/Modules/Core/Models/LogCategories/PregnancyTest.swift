import Foundation

enum PregnancyTest: Int, Codable {
    case didntTakeTests = 0
    case positive = 1
    case negative = 2
    case faintLine = 3
}
