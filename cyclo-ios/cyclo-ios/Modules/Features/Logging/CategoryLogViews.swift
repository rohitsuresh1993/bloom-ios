//
//  CategoryLogViews.swift
//  cyclo-ios
//
//  One screen per `Log` category (Symptoms, Mood, Flow Intensity, Activity) instead of the
//  single all-categories LogDayView — each is reached from its own quick-log button on Home, and
//  shows that category's options as selectable rows (SelectableOptionRow), not chips. The two
//  generic views below do the load-existing-log/save-back work once; `get`/`set` point each
//  concrete screen at its one `Log` property so editing one category never touches another's
//  value on the same day's `Log`. `nil` on the model always means "not logged that day" — an
//  empty multi-select saves back as `nil`, never `[]` (same convention as LogDayView).
//
//  Root entry points: LogSymptomsView(), LogMoodView(), LogFlowView(), LogActivityView().
//

import SwiftUI
import SwiftData

struct MultiSelectCategoryLogView<Option: LogCategoryOption>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let title: String
    let date: Date
    let get: (Log) -> [Option]?
    let set: (Log, [Option]?) -> Void

    @State private var selection: [Option] = []
    @State private var existingLog: Log?
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var logRepository: LogRepository { LogRepository(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                MultiSelectOptionSection(selection: $selection)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(Color.cycloPrimary)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            guard let log = try logRepository.log(on: date) else { return }
            existingLog = log
            selection = get(log) ?? []
        } catch {
            errorMessage = "Couldn't load this day's log: \(error.localizedDescription)"
        }
    }

    private func save() {
        let log = existingLog ?? Log(timestamp: date)
        set(log, selection.isEmpty ? nil : selection)
        do {
            try logRepository.saveLog(log)
            dismiss()
        } catch {
            errorMessage = "Couldn't save this log: \(error.localizedDescription)"
        }
    }
}

struct SingleSelectCategoryLogView<Option: LogCategoryOption>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let title: String
    let date: Date
    let get: (Log) -> Option?
    let set: (Log, Option?) -> Void

    @State private var selection: Option?
    @State private var existingLog: Log?
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var logRepository: LogRepository { LogRepository(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                SingleSelectOptionSection(selection: $selection)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(Color.cycloPrimary)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            guard let log = try logRepository.log(on: date) else { return }
            existingLog = log
            selection = get(log)
        } catch {
            errorMessage = "Couldn't load this day's log: \(error.localizedDescription)"
        }
    }

    private func save() {
        let log = existingLog ?? Log(timestamp: date)
        set(log, selection)
        do {
            try logRepository.saveLog(log)
            dismiss()
        } catch {
            errorMessage = "Couldn't save this log: \(error.localizedDescription)"
        }
    }
}

// MARK: - Concrete per-category screens

struct LogSymptomsView: View {
    let date: Date
    init(date: Date = Date()) { self.date = date }

    var body: some View {
        MultiSelectCategoryLogView<Symptoms>(
            title: "Symptoms",
            date: date,
            get: { $0.symptoms },
            set: { log, value in log.symptoms = value }
        )
    }
}

struct LogMoodView: View {
    let date: Date
    init(date: Date = Date()) { self.date = date }

    var body: some View {
        MultiSelectCategoryLogView<Mood>(
            title: "Mood",
            date: date,
            get: { $0.mood },
            set: { log, value in log.mood = value }
        )
    }
}

struct LogFlowView: View {
    let date: Date
    init(date: Date = Date()) { self.date = date }

    var body: some View {
        SingleSelectCategoryLogView<FlowIntensity>(
            title: "Flow Intensity",
            date: date,
            get: { $0.flowIntensity },
            set: { log, value in log.flowIntensity = value }
        )
    }
}

struct LogActivityView: View {
    let date: Date
    init(date: Date = Date()) { self.date = date }

    var body: some View {
        MultiSelectCategoryLogView<PhysicalActivity>(
            title: "Activity",
            date: date,
            get: { $0.physicalActivity },
            set: { log, value in log.physicalActivity = value }
        )
    }
}

#Preview {
    LogSymptomsView()
}
