import Foundation

// One-way export target, never a read source — SwiftData stays the sole source of truth for
// prediction (see ARCHITECTURE.md "HealthKit"). Wrapped behind this protocol so it's mockable:
// the real HealthKit store isn't reliably unit-testable in a simulator, and a caller can swap in
// a no-op implementation when the user hasn't granted authorization.
protocol HealthStoreWriting {
    var isHealthDataAvailable: Bool { get }

    // No read types are ever requested — this only grants HealthKit permission to receive a
    // copy, never to feed anything back into Bloom's own predictions.
    func requestAuthorization() async throws

    // `intensity` nil means only the period's date range is known (e.g. from the tap-to-start/
    // tap-to-end flow), not a specific daily reading — written as HealthKit's "unspecified" flow
    // value. `isCycleStart` sets HKMetadataKeyMenstrualCycleStart on the first day of a period.
    func exportMenstrualFlow(_ intensity: FlowIntensity?, on date: Date, isCycleStart: Bool) async throws

    // For spotting/bleeding that falls outside a logged period — HealthKit models this as its
    // own binary category type, distinct from menstrualFlow.
    func exportIntermenstrualBleeding(on date: Date) async throws

    func exportOvulationTestResult(_ result: OvulationTestResult, on date: Date) async throws
    func exportSexualActivity(_ activities: [SexualActivity], on date: Date) async throws
    func exportContraceptiveUse(_ status: OralContraceptiveStatus, on date: Date) async throws
}
