//
//  LogPeriodView.swift
//  bloom-ios
//
//  Period logging screen — a calendar where the user taps each day of a period, rather than a
//  "Start Period"/"End Period" button flow. On appear, pre-selects the most recent PeriodLog's
//  date range for editing (so continuing an ongoing period, or correcting one, is just tapping
//  more days); "Log a Different Period" clears the selection to log an unrelated one instead.
//  This single screen covers both the live-logging and backfill cases the old button-driven
//  flow split into two — same calendar view either way.
//
//  Root entry point: present `LogPeriodView()` from anywhere (e.g. via `.sheet`).
//

import SwiftUI
import SwiftData

struct LogPeriodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDays: Set<Date> = []
    @State private var loggedDays: Set<Date> = []
    @State private var editingPeriod: PeriodLog?
    @State private var errorMessage: String?

    private var cycleRepository: CycleRepository {
        CycleRepository(modelContext: modelContext)
    }

    private var userRepository: UserRepository {
        UserRepository(modelContext: modelContext)
    }

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

                Section {
                    PeriodDayRangeCalendar(
                        selectedDays: $selectedDays,
                        loggedDays: loggedDays,
                        initialMonth: selectedDays.min() ?? Date()
                    )
                    .padding(.vertical, 4)
                } header: {
                    Text(editingPeriod == nil ? "Tap each day of your period" : "Editing your most recent period")
                }

                if editingPeriod != nil {
                    Section {
                        Button("Log a Different Period") {
                            editingPeriod = nil
                            selectedDays = []
                        }
                        .tint(Color.bloomSecondary)
                    } footer: {
                        Text("Clears the current selection so you can log a separate period instead of editing this one.")
                    }
                }
            }
            .navigationTitle("Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(Color.bloomPrimary)
                        .disabled(selectedDays.isEmpty)
                }
            }
            .onAppear(perform: loadMostRecentPeriod)
        }
    }

    private func loadMostRecentPeriod() {
        do {
            let periods = try cycleRepository.allPeriodLogs()
            loggedDays = Set(periods.flatMap { Self.daysBetween($0.startDate, $0.endDate) })
            guard let mostRecent = periods.first else { return }
            editingPeriod = mostRecent
            selectedDays = Self.daysBetween(mostRecent.startDate, mostRecent.endDate)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load period history: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard let start = selectedDays.min(), let end = selectedDays.max() else { return }
        do {
            if let editingPeriod {
                try cycleRepository.updatePeriodDates(editingPeriod, start: start, end: end)
            } else {
                let user = try userRepository.currentUser()
                _ = try cycleRepository.logPeriod(start: start, end: end, for: user)
            }
            dismiss()
        } catch {
            errorMessage = "Couldn't save this period: \(error.localizedDescription)"
        }
    }

    private static func daysBetween(_ start: Date, _ end: Date) -> Set<Date> {
        let calendar = Calendar.current
        var days: Set<Date> = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            days.insert(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }
}

#Preview {
    LogPeriodView()
}
