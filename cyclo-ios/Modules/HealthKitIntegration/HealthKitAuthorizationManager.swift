import HealthKit

enum HealthKitAuthorizationError: Error {
    case healthDataUnavailable
}

final class HealthKitAuthorizationManager {
    // Write-only — no read types, since HealthKit is never a source of truth for Cyclo's own
    // predictions.
    static let shareTypes: Set<HKSampleType> = [
        HKCategoryType(.menstrualFlow),
        HKCategoryType(.intermenstrualBleeding),
        HKCategoryType(.ovulationTestResult),
        HKCategoryType(.sexualActivity),
        HKCategoryType(.contraceptive)
    ]

    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitAuthorizationError.healthDataUnavailable
        }
        try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: [])
    }
}
