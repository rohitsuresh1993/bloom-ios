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
    @EnvironmentObject private var tourCoordinator: TourCoordinator

    @State private var selectedDays: Set<Date> = []
    @State private var loggedDays: Set<Date> = []
    @State private var predictedPeriodDays: Set<Date> = []
    @State private var editingPeriod: PeriodLog?
    @State private var errorMessage: String?

    private var cycleRepository: CycleRepository {
        CycleRepository(modelContext: modelContext)
    }

    private var userRepository: UserRepository {
        UserRepository(modelContext: modelContext)
    }

    var body: some View {
        // Wraps the whole screen so this GeometryReader is a genuine ancestor of the
        // `.tourAnchor(.logPeriod)`-tagged calendar below — required for `proxy[anchor]` to
        // resolve correctly (see TourOverlayView's doc comment). This sheet's content is a
        // separate view tree from RootTabView's for preference-propagation purposes, so it needs
        // its own anchor collection + resolution rather than relying on RootTabView's.
        GeometryReader { proxy in
            ZStack {
                periodForm
                TourOverlayView(
                    allowedSteps: [.logPeriod],
                    cutoutRect: tourCoordinator.resolvedCutoutRect(in: proxy),
                    containerSize: proxy.size,
                    onNext: { dismiss(); tourCoordinator.advance() },
                    onSkip: { dismiss(); tourCoordinator.skip() }
                )
            }
        }
        // Must match the scrim's own .ignoresSafeArea() inside TourOverlayView — see
        // RootTabView's identical comment for why the two have to agree.
        .ignoresSafeArea()
        .onPreferenceChange(TourAnchorPreferenceKey.self) { newAnchors in
            tourCoordinator.anchors.merge(newAnchors) { _, new in new }
        }
    }

    private var periodForm: some View {
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
                        predictedPeriodDays: predictedPeriodDays,
                        initialMonth: selectedDays.min() ?? Date()
                    )
                    .padding(.vertical, 4)
                    .tourAnchor(.logPeriod)
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
            predictedPeriodDays = PeriodPrediction.upcomingPeriodDays(
                periods: periods, user: try userRepository.currentUser(), calendar: Calendar.current
            )
            guard let mostRecent = periods.first else { return }

            // Only pre-select the most recent period for editing when it's still "open" —
            // startDate == endDate means it was logged as a single day with no end yet, i.e.
            // genuinely still being extended day by day (same signal CycleRepository/
            // averagePeriodLength already use for "length not known yet"). A *closed* most
            // recent period is historical, possibly weeks old — pre-filling its days here would
            // silently extend that old range on save if the user just tapped a new day, and
            // would also block the picking-the-first-day auto-highlight+haptic sequence below
            // for what the user actually means as logging a brand new period.
            guard mostRecent.startDate == mostRecent.endDate else { return }
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
        .environmentObject(TourCoordinator())
}
