import Foundation
import SwiftData

enum CycleRepositoryError: Error {
    case endDateBeforeStartDate
}

protocol CycleRepositoring {
    func startPeriod(on date: Date, for user: User?) throws -> PeriodLog
    func endPeriod(_ periodLog: PeriodLog, on endDate: Date) throws
    func logPeriod(start: Date, end: Date, for user: User?) throws -> PeriodLog
    func allPeriodLogs() throws -> [PeriodLog]
    func delete(_ periodLog: PeriodLog) throws
}

final class CycleRepository: CycleRepositoring {
    private let modelContext: ModelContext
    private let healthStore: HealthStoreWriting

    init(modelContext: ModelContext, healthStore: HealthStoreWriting = HealthKitExporter()) {
        self.modelContext = modelContext
        self.healthStore = healthStore
    }

    // Matches the "tap to start a period" flow — the end date isn't known yet, so it starts
    // equal to the start date and gets corrected by `endPeriod` once the period actually ends.
    func startPeriod(on date: Date, for user: User?) throws -> PeriodLog {
        let periodLog = PeriodLog(user: user, startDate: date, endDate: date)
        modelContext.insert(periodLog)
        try modelContext.save()
        // One-way, best-effort export — never blocks or fails the local save (see
        // ARCHITECTURE.md "HealthKit"). No per-day intensity is known yet at period-start time;
        // that's `Log.flowIntensity`'s job via `LogRepository.saveLog`.
        let healthStore = self.healthStore
        Task {
            try? await healthStore.exportMenstrualFlow(nil, on: date, isCycleStart: true)
        }
        return periodLog
    }

    // No additional export here: HealthKit's menstrualFlow sample is a single per-day category
    // sample, not a date range, so the one written by `startPeriod` for the period's start day
    // already covers what a "period" means to HealthKit. Extending the end date doesn't create a
    // new day-level fact to export — any subsequent days' actual flow readings are the per-day
    // `Log.flowIntensity` export path via `LogRepository.saveLog`, not this method's job.
    func endPeriod(_ periodLog: PeriodLog, on endDate: Date) throws {
        try Self.validate(startDate: periodLog.startDate, endDate: endDate)
        periodLog.endDate = endDate
        try modelContext.save()
    }

    // For when both dates are already known up front, e.g. backfilling historical periods. This
    // never routes through `startPeriod`, so — to keep HealthKit at parity with the live-logging
    // path — it exports the same "cycle start" marker `startPeriod` would have, on the period's
    // start day.
    func logPeriod(start: Date, end: Date, for user: User?) throws -> PeriodLog {
        try Self.validate(startDate: start, endDate: end)
        let periodLog = PeriodLog(user: user, startDate: start, endDate: end)
        modelContext.insert(periodLog)
        try modelContext.save()
        let healthStore = self.healthStore
        Task {
            try? await healthStore.exportMenstrualFlow(nil, on: start, isCycleStart: true)
        }
        return periodLog
    }

    func allPeriodLogs() throws -> [PeriodLog] {
        let descriptor = FetchDescriptor<PeriodLog>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func delete(_ periodLog: PeriodLog) throws {
        modelContext.delete(periodLog)
        try modelContext.save()
    }

    private static func validate(startDate: Date, endDate: Date) throws {
        guard endDate >= startDate else {
            throw CycleRepositoryError.endDateBeforeStartDate
        }
    }
}
