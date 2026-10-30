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

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Matches the "tap to start a period" flow — the end date isn't known yet, so it starts
    // equal to the start date and gets corrected by `endPeriod` once the period actually ends.
    func startPeriod(on date: Date, for user: User?) throws -> PeriodLog {
        let periodLog = PeriodLog(user: user, startDate: date, endDate: date)
        modelContext.insert(periodLog)
        try modelContext.save()
        return periodLog
    }

    func endPeriod(_ periodLog: PeriodLog, on endDate: Date) throws {
        try Self.validate(startDate: periodLog.startDate, endDate: endDate)
        periodLog.endDate = endDate
        try modelContext.save()
    }

    // For when both dates are already known up front, e.g. backfilling historical periods.
    func logPeriod(start: Date, end: Date, for user: User?) throws -> PeriodLog {
        try Self.validate(startDate: start, endDate: end)
        let periodLog = PeriodLog(user: user, startDate: start, endDate: end)
        modelContext.insert(periodLog)
        try modelContext.save()
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
