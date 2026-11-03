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
    private let healthStore: HealthStoreWriting

    init(modelContext: ModelContext, healthStore: HealthStoreWriting = HealthKitExporter()) {
        self.modelContext = modelContext
        self.healthStore = healthStore
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
        exportToHealthKit(log)
    }

    // One-way, best-effort export of each non-nil category on this day's log — never blocks or
    // fails the local save above, and never feeds anything back into Cyclo's own predictions
    // (see ARCHITECTURE.md "HealthKit"). If `requestAuthorization()` was never called, the
    // underlying `HKHealthStore.save` calls simply fail silently, which is fine here.
    private func exportToHealthKit(_ log: Log) {
        let healthStore = self.healthStore
        let timestamp = log.timestamp
        if let flowIntensity = log.flowIntensity {
            Task {
                try? await healthStore.exportMenstrualFlow(flowIntensity, on: timestamp, isCycleStart: false)
            }
        }
        if let ovulationTestResult = log.ovulationTestResult {
            Task {
                try? await healthStore.exportOvulationTestResult(ovulationTestResult, on: timestamp)
            }
        }
        if let sexualActivity = log.sexualActivity, !sexualActivity.isEmpty {
            Task {
                try? await healthStore.exportSexualActivity(sexualActivity, on: timestamp)
            }
        }
        if let oralContraceptiveStatus = log.oralContraceptiveStatus {
            Task {
                try? await healthStore.exportContraceptiveUse(oralContraceptiveStatus, on: timestamp)
            }
        }
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
