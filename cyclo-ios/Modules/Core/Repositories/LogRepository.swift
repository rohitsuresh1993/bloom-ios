import Foundation
import SwiftData

protocol LogRepositoring {
    // A day's log is one row aggregating everything logged that day, so lookups are by
    // calendar day, not by exact timestamp.
    func log(on date: Date) throws -> Log?
    func saveLog(_ log: Log) throws
    func logs(from startDate: Date, to endDate: Date) throws -> [Log]
    func delete(_ log: Log) throws
}

final class LogRepository: LogRepositoring {
    private let modelContext: ModelContext
    private let calendar = Calendar.current

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func log(on date: Date) throws -> Log? {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let descriptor = FetchDescriptor<Log>(
            predicate: #Predicate { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
        )
        return try modelContext.fetch(descriptor).first
    }

    func saveLog(_ log: Log) throws {
        if log.modelContext == nil {
            modelContext.insert(log)
        }
        try modelContext.save()
    }

    func logs(from startDate: Date, to endDate: Date) throws -> [Log] {
        let descriptor = FetchDescriptor<Log>(
            predicate: #Predicate { $0.timestamp >= startDate && $0.timestamp <= endDate },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor)
    }

    func delete(_ log: Log) throws {
        modelContext.delete(log)
        try modelContext.save()
    }
}
