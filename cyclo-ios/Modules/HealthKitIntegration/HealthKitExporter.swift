import HealthKit

final class HealthKitExporter: HealthStoreWriting {
    // Referenced by SettingsView's `@AppStorage` toggle rather than duplicating the string there.
    static let exportEnabledDefaultsKey = "cyclo.healthKitExportEnabled"

    private let healthStore: HKHealthStore
    private let authorizationManager: HealthKitAuthorizationManager
    private let userDefaults: UserDefaults

    init(healthStore: HKHealthStore = HKHealthStore(), userDefaults: UserDefaults = .standard) {
        self.healthStore = healthStore
        self.authorizationManager = HealthKitAuthorizationManager(healthStore: healthStore)
        self.userDefaults = userDefaults
    }

    // Defaults to `true` when the key has never been set, so existing users who already granted
    // HealthKit permission see no behavior change until they explicitly turn this off in Settings.
    // Plain `userDefaults.bool(forKey:)` would default to `false` for an unset key, which is wrong
    // here.
    private var isExportEnabled: Bool {
        userDefaults.object(forKey: Self.exportEnabledDefaultsKey) == nil
            ? true
            : userDefaults.bool(forKey: Self.exportEnabledDefaultsKey)
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        try await authorizationManager.requestAuthorization()
    }

    func exportMenstrualFlow(_ intensity: FlowIntensity?, on date: Date, isCycleStart: Bool) async throws {
        guard isExportEnabled else { return }
        let sample = HKCategorySample(
            type: HKCategoryType(.menstrualFlow),
            value: Self.menstrualFlowValue(for: intensity).rawValue,
            start: date,
            end: date,
            metadata: isCycleStart ? [HKMetadataKeyMenstrualCycleStart: true] : nil
        )
        try await healthStore.save(sample)
    }

    func exportIntermenstrualBleeding(on date: Date) async throws {
        guard isExportEnabled else { return }
        let sample = HKCategorySample(
            type: HKCategoryType(.intermenstrualBleeding),
            value: HKCategoryValue.notApplicable.rawValue,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
    }

    func exportOvulationTestResult(_ result: OvulationTestResult, on date: Date) async throws {
        guard isExportEnabled else { return }
        let sample = HKCategorySample(
            type: HKCategoryType(.ovulationTestResult),
            value: Self.ovulationTestValue(for: result).rawValue,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
    }

    func exportSexualActivity(_ activities: [SexualActivity], on date: Date) async throws {
        guard isExportEnabled else { return }
        guard !activities.isEmpty, !activities.contains(.didntHaveSex) else { return }

        var metadata: [String: Any] = [:]
        if activities.contains(.protectedSex) {
            metadata[HKMetadataKeySexualActivityProtectionUsed] = true
        } else if activities.contains(.unprotectedSex) {
            metadata[HKMetadataKeySexualActivityProtectionUsed] = false
        }

        let sample = HKCategorySample(
            type: HKCategoryType(.sexualActivity),
            value: HKCategoryValue.notApplicable.rawValue,
            start: date,
            end: date,
            metadata: metadata.isEmpty ? nil : metadata
        )
        try await healthStore.save(sample)
    }

    func exportContraceptiveUse(_ status: OralContraceptiveStatus, on date: Date) async throws {
        guard isExportEnabled else { return }
        // HealthKit models contraceptive *method*, not day-to-day adherence — a missed dose is
        // still "oral contraceptive in use" for continuity, since HealthKit has no value for
        // "missed."
        let sample = HKCategorySample(
            type: HKCategoryType(.contraceptive),
            value: HKCategoryValueContraceptive.oral.rawValue,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
    }

    private static func menstrualFlowValue(for intensity: FlowIntensity?) -> HKCategoryValueVaginalBleeding {
        guard let intensity else { return .unspecified }
        switch intensity {
        // HealthKit's vaginal-bleeding enum has no "spotting" value — light is the closest fit.
        case .spotting, .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }

    // HealthKit's ovulationTestResult enum doesn't distinguish "low fertility" from
    // "indeterminate" the way a dedicated OPK display does — indeterminate is the closest fit,
    // not an exact match. Flagged as approximate, same spirit as the FlowIntensity mapping above.
    private static func ovulationTestValue(for result: OvulationTestResult) -> HKCategoryValueOvulationTestResult {
        switch result {
        case .negative: return .negative
        case .lowFertility: return .indeterminate
        case .highFertility: return .estrogenSurge
        case .peak: return .luteinizingHormoneSurge
        }
    }
}
