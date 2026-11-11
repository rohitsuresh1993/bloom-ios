//
//  TodayLogView.swift
//  cyclo-ios
//
//  Unified log-entry screen replacing the old per-category sheets (LogSymptomsView, LogMoodView,
//  LogFlowView, LogActivityView, LogDayView) — every Log category (except the period date range,
//  which stays its own calendar-based LogPeriodView) is one scrollable screen of white cards,
//  matching the reference design: date-nav header, search field, and a FlowLayout of icon+label
//  pills per card. Selections autosave immediately (no separate Save step), the same
//  "every control applies immediately" convention Settings already uses.
//
//  Root entry point: present `TodayLogView(date:scrollTarget:)` from anywhere (e.g. via `.sheet`).
//

import SwiftUI
import SwiftData

struct TodayLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let initialScrollTarget: LogCategoryKind?

    @State private var date: Date
    @State private var searchQuery = ""
    @State private var periods: [PeriodLog] = []
    @State private var existingLog: Log?
    @State private var errorMessage: String?

    @State private var mood: [Mood] = []
    @State private var symptoms: [Symptoms] = []
    @State private var physicalActivity: [PhysicalActivity] = []
    @State private var flowIntensity: FlowIntensity?
    @State private var sexualActivity: [SexualActivity] = []
    @State private var sexDrive: SexDrive?
    @State private var vaginalDischarge: VaginalDischarge?
    @State private var ovulationTestResult: OvulationTestResult?
    @State private var pregnancyTest: PregnancyTest?
    @State private var oralContraceptiveStatus: OralContraceptiveStatus?
    @State private var digestionAndStool: [DigestionAndStool] = []
    @State private var other: [Other] = []

    init(date: Date = Date(), scrollTarget: LogCategoryKind? = nil) {
        _date = State(initialValue: date)
        initialScrollTarget = scrollTarget
    }

    private var logRepository: LogRepository { LogRepository(modelContext: modelContext) }
    private var cycleRepository: CycleRepository { CycleRepository(modelContext: modelContext) }

    private static let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        searchField

                        cardsStack
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .onAppear {
                    guard let initialScrollTarget else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo(initialScrollTarget, anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { dateHeader }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.cycloPrimary)
                }
            }
            .task { try? await loadPeriods() }
            .task(id: date) { load() }
        }
    }

    // MARK: - Header

    private var dateHeader: some View {
        HStack(spacing: 20) {
            Button {
                changeDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            VStack(spacing: 2) {
                Text(Self.titleText(for: date))
                    .font(.headline)
                if let cycleDayText = Self.cycleDayText(for: date, periods: periods) {
                    Text(cycleDayText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 100)

            Button {
                changeDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.3)
        }
        .foregroundStyle(Color.cycloPrimary)
    }

    private var canGoForward: Bool {
        date < Self.calendar.startOfDay(for: Date())
    }

    private func changeDate(by dayOffset: Int) {
        guard let newDate = Self.calendar.date(byAdding: .day, value: dayOffset, to: date) else { return }
        date = newDate
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchQuery)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }

    // MARK: - Cards

    @ViewBuilder
    private var cardsStack: some View {
        if MultiSelectChipFlow<Mood>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Mood") {
                MultiSelectChipFlow(query: searchQuery, selection: $mood, onChange: save)
            }
            .id(LogCategoryKind.mood)
        }

        if MultiSelectChipFlow<Symptoms>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Symptoms") {
                MultiSelectChipFlow(query: searchQuery, selection: $symptoms, onChange: save)
            }
            .id(LogCategoryKind.symptoms)
        }

        if MultiSelectChipFlow<PhysicalActivity>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Physical Activity") {
                MultiSelectChipFlow(query: searchQuery, selection: $physicalActivity, onChange: save)
            }
            .id(LogCategoryKind.physicalActivity)
        }

        if SingleSelectChipFlow<FlowIntensity>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Flow Intensity") {
                SingleSelectChipFlow(query: searchQuery, selection: $flowIntensity, onChange: save)
            }
            .id(LogCategoryKind.flowIntensity)
        }

        if MultiSelectChipFlow<SexualActivity>.matchesQuery(searchQuery)
            || SingleSelectChipFlow<SexDrive>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Sex & Sex Drive") {
                VStack(alignment: .leading, spacing: 10) {
                    MultiSelectChipFlow(query: searchQuery, selection: $sexualActivity, onChange: save)
                    SingleSelectChipFlow(query: searchQuery, selection: $sexDrive, onChange: save)
                }
            }
            .id(LogCategoryKind.sexAndSexDrive)
        }

        if SingleSelectChipFlow<VaginalDischarge>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Vaginal Discharge") {
                SingleSelectChipFlow(query: searchQuery, selection: $vaginalDischarge, onChange: save)
            }
            .id(LogCategoryKind.vaginalDischarge)
        }

        if SingleSelectChipFlow<OvulationTestResult>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Ovulation Test") {
                SingleSelectChipFlow(query: searchQuery, selection: $ovulationTestResult, onChange: save)
            }
            .id(LogCategoryKind.ovulationTestResult)
        }

        if SingleSelectChipFlow<PregnancyTest>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Pregnancy Test") {
                SingleSelectChipFlow(query: searchQuery, selection: $pregnancyTest, onChange: save)
            }
            .id(LogCategoryKind.pregnancyTest)
        }

        if SingleSelectChipFlow<OralContraceptiveStatus>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Oral Contraceptive") {
                SingleSelectChipFlow(query: searchQuery, selection: $oralContraceptiveStatus, onChange: save)
            }
            .id(LogCategoryKind.oralContraceptiveStatus)
        }

        if MultiSelectChipFlow<DigestionAndStool>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Digestion & Stool") {
                MultiSelectChipFlow(query: searchQuery, selection: $digestionAndStool, onChange: save)
            }
            .id(LogCategoryKind.digestionAndStool)
        }

        if MultiSelectChipFlow<Other>.matchesQuery(searchQuery) {
            LogCategoryCard(title: "Other") {
                MultiSelectChipFlow(query: searchQuery, selection: $other, onChange: save)
            }
            .id(LogCategoryKind.other)
        }
    }

    // MARK: - Load / Save

    private func loadPeriods() async throws {
        periods = try cycleRepository.allPeriodLogs()
    }

    private func load() {
        errorMessage = nil
        do {
            guard let log = try logRepository.log(on: date) else {
                existingLog = nil
                mood = []
                symptoms = []
                physicalActivity = []
                flowIntensity = nil
                sexualActivity = []
                sexDrive = nil
                vaginalDischarge = nil
                ovulationTestResult = nil
                pregnancyTest = nil
                oralContraceptiveStatus = nil
                digestionAndStool = []
                other = []
                return
            }
            existingLog = log
            mood = log.mood ?? []
            symptoms = log.symptoms ?? []
            physicalActivity = log.physicalActivity ?? []
            flowIntensity = log.flowIntensity
            sexualActivity = log.sexualActivity ?? []
            sexDrive = log.sexDrive
            vaginalDischarge = log.vaginalDischarge
            ovulationTestResult = log.ovulationTestResult
            pregnancyTest = log.pregnancyTest
            oralContraceptiveStatus = log.oralContraceptiveStatus
            digestionAndStool = log.digestionAndStool ?? []
            other = log.other ?? []
        } catch {
            errorMessage = "Couldn't load this day's log: \(error.localizedDescription)"
        }
    }

    private func save() {
        let log = existingLog ?? Log(timestamp: date)
        log.mood = mood.isEmpty ? nil : mood
        log.symptoms = symptoms.isEmpty ? nil : symptoms
        log.physicalActivity = physicalActivity.isEmpty ? nil : physicalActivity
        log.flowIntensity = flowIntensity
        log.sexualActivity = sexualActivity.isEmpty ? nil : sexualActivity
        log.sexDrive = sexDrive
        log.vaginalDischarge = vaginalDischarge
        log.ovulationTestResult = ovulationTestResult
        log.pregnancyTest = pregnancyTest
        log.oralContraceptiveStatus = oralContraceptiveStatus
        log.digestionAndStool = digestionAndStool.isEmpty ? nil : digestionAndStool
        log.other = other.isEmpty ? nil : other

        do {
            try logRepository.saveLog(log)
            existingLog = log
        } catch {
            errorMessage = "Couldn't save this log: \(error.localizedDescription)"
        }
    }

    // MARK: - Header text helpers

    private static func titleText(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func cycleDayText(for date: Date, periods: [PeriodLog]) -> String? {
        let day = calendar.startOfDay(for: date)
        let priorStarts = periods.map { calendar.startOfDay(for: $0.startDate) }.filter { $0 <= day }
        guard let mostRecentStart = priorStarts.max() else { return nil }
        let offset = calendar.dateComponents([.day], from: mostRecentStart, to: day).day ?? 0
        return "Cycle day \(offset + 1)"
    }
}

#Preview {
    TodayLogView()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
