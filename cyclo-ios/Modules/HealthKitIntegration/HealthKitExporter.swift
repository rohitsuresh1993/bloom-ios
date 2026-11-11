import HealthKit

// All actual HealthKit writes funnel through this one actor-isolated queue, regardless of how
// many HealthKitExporter instances exist — most call sites construct one ad hoc per call, and
// LogRepository.exportToHealthKit fires off several independent fire-and-forget Tasks per
// `saveLog` call (one per populated category). Two of those writes racing each other — e.g.
// logging two different flow-intensity values in quick succession — was confirmed (via an
// on-device crash report) to crash deep inside HealthKit's own object-validation code
// (NSException in `-[HKObject _validateForCreation]`), not in Cyclo's own logic. Actor isolation
// guarantees only one write is ever in flight at a time, app-wide, which eliminates that race.
private actor HealthKitWriteQueue {
    static let shared = HealthKitWriteQueue()
    private init() {}

    func save(_ sample: HKSample, to healthStore: HKHealthStore) async throws {
        try await healthStore.save(sample)
    }
}

final class HealthKitExporter: HealthStoreWriting {
    // Referenced by ProfilePage's `@AppStorage` toggle rather than duplicating the string there.
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
        // HKMetadataKeyMenstrualCycleStart is a *required* metadata key for every menstrualFlow
        // category sample per Apple's own header doc (HKMetadata.h) — not just on the first day
        // of a period. Omitting it when `isCycleStart` is false (as this used to) makes
        // HKCategorySample's init raise an uncaught NSException (confirmed via an on-device
        // crash report: `-[HKObject _validateForCreation]`), which `try?` can't catch since it's
        // a raw Objective-C exception, not a Swift `Error`. Always including the key, with its
        // real true/false value, satisfies the requirement either way.
        let sample = HKCategorySample(
            type: HKCategoryType(.menstrualFlow),
            value: Self.menstrualFlowValue(for: intensity).rawValue,
            start: date,
            end: date,
            metadata: [HKMetadataKeyMenstrualCycleStart: isCycleStart]
        )
        try await HealthKitWriteQueue.shared.save(sample, to: healthStore)
    }

    func exportIntermenstrualBleeding(on date: Date) async throws {
        guard isExportEnabled else { return }
        let sample = HKCategorySample(
            type: HKCategoryType(.intermenstrualBleeding),
            value: HKCategoryValue.notApplicable.rawValue,
            start: date,
            end: date
        )
        try await HealthKitWriteQueue.shared.save(sample, to: healthStore)
    }

    func exportOvulationTestResult(_ result: OvulationTestResult, on date: Date) async throws {
        guard isExportEnabled else { return }
        let sample = HKCategorySample(
            type: HKCategoryType(.ovulationTestResult),
            value: Self.ovulationTestValue(for: result).rawValue,
            start: date,
            end: date
        )
        try await HealthKitWriteQueue.shared.save(sample, to: healthStore)
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
        try await HealthKitWriteQueue.shared.save(sample, to: healthStore)
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
        try await HealthKitWriteQueue.shared.save(sample, to: healthStore)
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
