//
//  CalendarPage.swift
//  cyclo-ios
//
//  Calendar tab: a read-only month view of the user's period and log history (HistoryCalendarView
//  highlights period days filled, other logged days ringed) — tapping a day shows what was
//  logged, via DayDetailSheet. Doesn't let you edit from here; that's TodayLogView/LogPeriodView's
//  job, reached from Home's quick-log row.
//
//  Root entry point: this is a tab root (see RootTabView), not presented via `.sheet`.
//

import SwiftUI
import SwiftData

struct CalendarPage: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tabCoordinator: AppTabCoordinator

    @State private var periodDays: Set<Date> = []
    @State private var loggedDays: Set<Date> = []
    @State private var selectedDay: SelectedDay?
    @State private var errorMessage: String?

    // `.sheet(item:)` needs Identifiable; wrapping avoids a retroactive `Identifiable`
    // conformance on `Date` itself just for this one call site.
    private struct SelectedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }

    private var cycleRepository: CycleRepository { CycleRepository(modelContext: modelContext) }
    private var logRepository: LogRepository { LogRepository(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HistoryCalendarView(
                        periodDays: periodDays,
                        loggedDays: loggedDays,
                        onSelectDay: { selectedDay = SelectedDay(date: $0) }
                    )
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { load() }
        .onChange(of: tabCoordinator.selectedTab) { _, newValue in
            guard newValue == .calendar else { return }
            load()
        }
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(
                date: day.date,
                isPeriodDay: periodDays.contains(day.date),
                log: try? logRepository.log(on: day.date)
            )
        }
    }

    private func load() {
        do {
            let periods = try cycleRepository.allPeriodLogs()
            periodDays = Set(periods.flatMap { Self.daysBetween($0.startDate, $0.endDate) })

            let logs = try logRepository.allLogs()
            let calendar = Calendar.current
            loggedDays = Set(logs.map { calendar.startOfDay(for: $0.timestamp) })

            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your history: \(error.localizedDescription)"
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

// MARK: - Day detail

private struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let isPeriodDay: Bool
    let log: Log?

    var body: some View {
        NavigationStack {
            List {
                if isPeriodDay {
                    Section {
                        Label("Period day", systemImage: "drop.fill")
                            .foregroundStyle(Color.cycloPrimary)
                    }
                }

                if let log {
                    ForEach(Self.sections(for: log), id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.values, id: \.self) { value in
                                Text(value)
                            }
                        }
                    }
                }

                if log == nil && !isPeriodDay {
                    Section {
                        Text("Nothing logged on this day.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private struct DetailSection {
        let title: String
        let values: [String]
    }

    // Same per-category grouping HomeViewModel.chips(for:) flattens into one strip — grouped
    // under a title here instead, since this is a dedicated detail view rather than an inline
    // Home strip.
    private static func sections(for log: Log) -> [DetailSection] {
        var sections: [DetailSection] = []
        func humanized<T>(_ value: T) -> String { HomeViewModel.humanizeCaseName(String(describing: value)) }

        if let mood = log.mood, !mood.isEmpty {
            sections.append(DetailSection(title: "Mood", values: mood.map(humanized)))
        }
        if let symptoms = log.symptoms, !symptoms.isEmpty {
            sections.append(DetailSection(title: "Symptoms", values: symptoms.map(humanized)))
        }
        if let flowIntensity = log.flowIntensity {
            sections.append(DetailSection(title: "Flow", values: [humanized(flowIntensity)]))
        }
        if let physicalActivity = log.physicalActivity, !physicalActivity.isEmpty {
            sections.append(DetailSection(title: "Physical Activity", values: physicalActivity.map(humanized)))
        }
        if let sexualActivity = log.sexualActivity, !sexualActivity.isEmpty {
            sections.append(DetailSection(title: "Sexual Activity", values: sexualActivity.map(humanized)))
        }
        if let sexDrive = log.sexDrive {
            sections.append(DetailSection(title: "Sex Drive", values: [humanized(sexDrive)]))
        }
        if let vaginalDischarge = log.vaginalDischarge {
            sections.append(DetailSection(title: "Vaginal Discharge", values: [humanized(vaginalDischarge)]))
        }
        if let ovulationTestResult = log.ovulationTestResult {
            sections.append(DetailSection(title: "Ovulation Test", values: [humanized(ovulationTestResult)]))
        }
        if let pregnancyTest = log.pregnancyTest {
            sections.append(DetailSection(title: "Pregnancy Test", values: [humanized(pregnancyTest)]))
        }
        if let oralContraceptiveStatus = log.oralContraceptiveStatus {
            sections.append(DetailSection(title: "Oral Contraceptive", values: [humanized(oralContraceptiveStatus)]))
        }
        if let digestionAndStool = log.digestionAndStool, !digestionAndStool.isEmpty {
            sections.append(DetailSection(title: "Digestion & Stool", values: digestionAndStool.map(humanized)))
        }
        if let other = log.other, !other.isEmpty {
            sections.append(DetailSection(title: "Other", values: other.map(humanized)))
        }
        return sections
    }
}

#Preview {
    CalendarPage()
        .environmentObject(AppTabCoordinator())
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
