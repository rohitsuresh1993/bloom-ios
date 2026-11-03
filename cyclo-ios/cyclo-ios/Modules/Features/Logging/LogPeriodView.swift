//
//  LogPeriodView.swift
//  cyclo-ios
//
//  Period logging screen. An "open" period is the most recent `PeriodLog` where
//  `startDate == endDate`, per `CycleRepository.startPeriod`'s own doc comment: it sets
//  `endDate = startDate` initially and expects `endPeriod` to correct it later.
//  - No open period: shows a "Start Period" action (`CycleRepository.startPeriod(on:for:)`).
//  - An open period: shows a date picker and "End Period" action
//    (`CycleRepository.endPeriod(_:on:)`).
//  - Either way, a secondary "Log a Past Period" action backfills a period where both dates
//    are already known (`CycleRepository.logPeriod(start:end:for:)`), via `LogPastPeriodView`
//    below.
//
//  Root entry point: present `LogPeriodView()` from anywhere (e.g. via `.sheet`).
//

import SwiftUI
import SwiftData

struct LogPeriodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var openPeriod: PeriodLog?
    @State private var endDate = Date()
    @State private var errorMessage: String?
    @State private var isShowingBackfill = false

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
                    if let openPeriod {
                        DatePicker(
                            "Period ended",
                            selection: $endDate,
                            in: Calendar.current.startOfDay(for: openPeriod.startDate)...,
                            displayedComponents: .date
                        )

                        Button(action: endOpenPeriod) {
                            Text("End Period")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.cycloPrimary)
                    } else {
                        Button(action: startNewPeriod) {
                            Text("Start Period")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.cycloPrimary)
                    }
                } header: {
                    Text(openPeriod == nil ? "No Period in Progress" : "Period in Progress")
                } footer: {
                    if let openPeriod {
                        Text("Started \(openPeriod.startDate.formatted(date: .abbreviated, time: .omitted)).")
                    }
                }

                Section {
                    Button("Log a Past Period") {
                        isShowingBackfill = true
                    }
                    .tint(Color.cycloSecondary)
                } footer: {
                    Text("Backfill a period you forgot to log at the time, with both the start and end dates already known.")
                }
            }
            .navigationTitle("Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: loadOpenPeriod)
            .sheet(isPresented: $isShowingBackfill) {
                LogPastPeriodView(onSave: loadOpenPeriod)
            }
        }
    }

    private func loadOpenPeriod() {
        do {
            let periods = try cycleRepository.allPeriodLogs()
            openPeriod = periods.first { $0.startDate == $0.endDate }
            if let openPeriod {
                endDate = max(Date(), openPeriod.startDate)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load period history: \(error.localizedDescription)"
        }
    }

    private func startNewPeriod() {
        do {
            let user = try userRepository.currentUser()
            openPeriod = try cycleRepository.startPeriod(on: Date(), for: user)
            endDate = openPeriod?.startDate ?? Date()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't start period: \(error.localizedDescription)"
        }
    }

    private func endOpenPeriod() {
        guard let openPeriod else { return }
        do {
            try cycleRepository.endPeriod(openPeriod, on: endDate)
            self.openPeriod = nil
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't end period: \(error.localizedDescription)"
        }
    }
}

/// Backfills a period where both the start and end dates are already known. Presented as a
/// sheet from `LogPeriodView`; not meant to be a standalone entry point.
private struct LogPastPeriodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onSave: () -> Void

    @State private var startDate = Date()
    @State private var endDate = Date()
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

                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                DatePicker(
                    "End date",
                    selection: $endDate,
                    in: Calendar.current.startOfDay(for: startDate)...,
                    displayedComponents: .date
                )
            }
            .navigationTitle("Log a Past Period")
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
        }
    }

    private func save() {
        do {
            let user = try userRepository.currentUser()
            _ = try cycleRepository.logPeriod(start: startDate, end: endDate, for: user)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Couldn't save this period: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LogPeriodView()
}
