//
//  HomeViewModel.swift
//  cyclo-ios
//
//  Owns Home's data-fetching/computation: builds on the repositories HomePage hands it (from
//  `@Environment(\.modelContext)`), runs the Prediction engines, and exposes plain view-ready
//  `@Published` state. Mirrors the small-focused-view-model pattern established by
//  `AppLockGateViewModel` (Modules/Security/AppLockGateView.swift).
//

import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - View-ready state

    struct WeekDayItem: Identifiable {
        let id = UUID()
        let date: Date
        let letter: String
        let number: Int
        let isToday: Bool
        let hasPeriodFlow: Bool
    }

    // One page of the horizontally-scrollable week carousel.
    struct WeekItem: Identifiable {
        let id = UUID()
        let days: [WeekDayItem]
    }

    struct DayRange {
        let start: Double
        let end: Double
    }

    struct FertilityCardData {
        let fertileWindowRangeText: String
        let estimatedOvulationText: String
        let statusSentence: String
        let isConfirmedByTest: Bool
    }

    struct PatternInsight: Identifiable {
        let id = UUID()
        let text: String
    }

    // Which full-screen Logging sheet (built by the Logging feature) is presented over Home.
    // One case per category screen (Symptoms/Mood/Flow/Activity each get their own — see
    // CategoryLogViews.swift) rather than one combined "day" sheet; `.more` covers the
    // remaining Log categories that don't have a dedicated quick-log button yet.
    enum ActiveSheet: Identifiable {
        case period
        case symptoms
        case mood
        case flow
        case activity
        case more

        var id: Self { self }
    }

    // Week strip
    @Published private(set) var weeks: [WeekItem] = []
    // Index into `weeks` of the week containing today — the carousel scrolls here initially.
    @Published private(set) var currentWeekID: WeekItem.ID?

    // Cycle-phase ring
    @Published private(set) var hasCycleData: Bool = false
    @Published private(set) var dayOfCycle: Int = 0
    @Published private(set) var predictedCycleLength: Double = 28
    @Published private(set) var periodArcLengthDays: Double = PredictionConstants.assumedMenstrualPhaseLength
    @Published private(set) var fertileArcRange: DayRange?
    @Published private(set) var ringMarkerFraction: Double = 0
    @Published private(set) var ringCenterTitle: String = ""
    @Published private(set) var ringCenterSubtitle: String = ""
    @Published private(set) var nextPeriodRangeText: String = ""
    @Published private(set) var confidenceLabel: String = ""

    // Fertility card (nil => render nothing)
    @Published private(set) var fertilityCard: FertilityCardData?

    // Patterns card (empty => render nothing)
    @Published private(set) var patternInsights: [PatternInsight] = []

    // Quick-log row + today's chip strip
    @Published private(set) var todaysChips: [String] = []
    @Published private(set) var periodLoggedToday: Bool = false
    @Published private(set) var symptomsLoggedToday: Bool = false
    @Published private(set) var moodLoggedToday: Bool = false
    @Published private(set) var flowLoggedToday: Bool = false
    @Published private(set) var activityLoggedToday: Bool = false
    @Published private(set) var moreLoggedToday: Bool = false
    @Published var activeSheet: ActiveSheet?
    @Published var errorMessage: String?

    // MARK: - Dependencies (handed in by HomePage via `configure`, since HomePage must stay
    // zero-argument constructible and @Environment isn't available at init time)

    private var cycleRepository: CycleRepositoring?
    private var logRepository: LogRepositoring?
    private var userRepository: UserRepositoring?
    private var currentUser: User?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    init() {}

    func configure(
        cycleRepository: CycleRepositoring,
        logRepository: LogRepositoring,
        userRepository: UserRepositoring
    ) {
        guard self.cycleRepository == nil else { return }
        self.cycleRepository = cycleRepository
        self.logRepository = logRepository
        self.userRepository = userRepository
        refresh()
    }

    // MARK: - Refresh

    func refresh() {
        guard let cycleRepository, let logRepository, let userRepository else { return }
        let today = Date()
        let calendar = Calendar.current

        do {
            let user = try userRepository.currentUser()
            currentUser = user
            let isOnContraception = user.knownConditions.contains(.onHormonalContraception)

            // `allPeriodLogs()` is sorted newest-start-first.
            let allPeriods = try cycleRepository.allPeriodLogs()
            hasCycleData = !allPeriods.isEmpty
            periodLoggedToday = allPeriods.contains { Self.periodCovers(day: today, log: $0, calendar: calendar) }

            let builtWeeks = Self.buildWeeks(today: today, periods: allPeriods, calendar: calendar)
            weeks = builtWeeks.weeks
            currentWeekID = builtWeeks.todayWeekID

            let todaysLogValue = try logRepository.log(on: today)
            symptomsLoggedToday = !(todaysLogValue?.symptoms?.isEmpty ?? true)
            moodLoggedToday = !(todaysLogValue?.mood?.isEmpty ?? true)
            flowLoggedToday = todaysLogValue?.flowIntensity != nil
            activityLoggedToday = !(todaysLogValue?.physicalActivity?.isEmpty ?? true)
            moreLoggedToday = Self.hasMoreCategoriesLogged(todaysLogValue)
            todaysChips = Self.chips(for: todaysLogValue)

            guard hasCycleData else {
                fertileArcRange = nil
                fertilityCard = nil
                patternInsights = []
                return
            }

            let sortedStarts = allPeriods.map(\.startDate).sorted()
            guard let lastPeriodStart = sortedStarts.last else { return }

            let cycleLengths: [Double] = zip(sortedStarts, sortedStarts.dropFirst()).map {
                Double(calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: $0),
                    to: calendar.startOfDay(for: $1)
                ).day ?? 0)
            }

            let age = calendar.dateComponents([.year], from: user.dateOfBirth, to: today).year ?? 25
            let prior = PriorTable.lookup(ageBucket: AgeBucket(age: age), conditions: user.knownConditions)

            let prediction = CyclePredictionEngine.predictNextPeriod(
                cycleLengths: cycleLengths,
                lastPeriodStartDate: lastPeriodStart,
                prior: prior,
                calendar: calendar
            )
            predictedCycleLength = prediction.predictedCycleLength
            confidenceLabel = prediction.confidence.label
            nextPeriodRangeText = "Next period: around "
                + "\(Self.dateFormatter.string(from: prediction.earliestLikelyStartDate)) – "
                + "\(Self.dateFormatter.string(from: prediction.latestLikelyStartDate))"

            let dayOffset = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastPeriodStart),
                to: calendar.startOfDay(for: today)
            ).day ?? 0
            let dayOfCycleValue = max(1, dayOffset + 1)
            dayOfCycle = dayOfCycleValue
            ringCenterTitle = "Day \(dayOfCycleValue)"
            ringMarkerFraction = min(Double(dayOfCycleValue) / prediction.predictedCycleLength, 1.0)
            periodArcLengthDays = Self.averagePeriodLength(periods: allPeriods, calendar: calendar)

            let confirmedOvulationDate: Date? = try? logRepository
                .logs(from: lastPeriodStart, to: today)
                .first(where: { $0.ovulationTestResult == .peak })?
                .timestamp

            let fertilityWindow = FertilityEngine.fertilityWindow(
                predictedNextPeriodStart: prediction.predictedStartDate,
                lutealPhaseLengths: [],
                prior: prior,
                confirmedOvulationDate: confirmedOvulationDate,
                isOnHormonalContraception: isOnContraception,
                calendar: calendar
            )

            let lutealLengthForBucketing: Double
            if let fertilityWindow {
                lutealLengthForBucketing = Double(
                    calendar.dateComponents(
                        [.day], from: fertilityWindow.estimatedOvulationDate, to: prediction.predictedStartDate
                    ).day ?? Int(prior.meanLutealPhase)
                )
            } else {
                lutealLengthForBucketing = prior.meanLutealPhase
            }

            let currentPhase = SymptomCorrelationEngine.phase(
                forDayOffset: dayOfCycleValue - 1,
                cycleLength: prediction.predictedCycleLength,
                lutealPhaseLength: lutealLengthForBucketing
            )
            ringCenterSubtitle = isOnContraception ? "DAY OF CYCLE" : currentPhase.displayName.uppercased()

            // n>=3 observed cycles gate — showing a fertile window or named phase confidence any
            // earlier overstates how much the engine actually knows yet.
            let showFertileDetail = fertilityWindow != nil && prediction.confidence != .stillLearning

            if showFertileDetail, let fertilityWindow {
                let startDay = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: lastPeriodStart),
                    to: calendar.startOfDay(for: fertilityWindow.fertileWindowStart)
                ).day ?? 0
                let endDay = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: lastPeriodStart),
                    to: calendar.startOfDay(for: fertilityWindow.fertileWindowEnd)
                ).day ?? 0
                fertileArcRange = DayRange(start: Double(max(startDay, 0)), end: Double(endDay + 1))

                fertilityCard = FertilityCardData(
                    fertileWindowRangeText: "\(Self.dateFormatter.string(from: fertilityWindow.fertileWindowStart))"
                        + " – \(Self.dateFormatter.string(from: fertilityWindow.fertileWindowEnd))",
                    estimatedOvulationText: Self.dateFormatter.string(from: fertilityWindow.estimatedOvulationDate),
                    statusSentence: Self.fertilityStatusSentence(today: today, window: fertilityWindow, calendar: calendar),
                    isConfirmedByTest: fertilityWindow.isConfirmedByTest
                )
            } else {
                fertileArcRange = nil
                fertilityCard = nil
            }

            if prediction.confidence != .stillLearning {
                let logsThisHistory = try logRepository.logs(from: sortedStarts.first ?? today, to: today)
                patternInsights = Self.buildPatternInsights(
                    logs: logsThisHistory,
                    periodStartDates: sortedStarts,
                    typicalCycleLength: prediction.predictedCycleLength,
                    typicalLutealPhaseLength: lutealLengthForBucketing,
                    currentPhase: currentPhase,
                    calendar: calendar
                )
            } else {
                patternInsights = []
            }
        } catch {
            errorMessage = "Couldn't load your cycle data."
        }
    }

    // MARK: - Quick log row

    // Opens the real Logging feature's screens (Modules/Features/Logging) as sheets, rather than
    // mutating repositories directly here — that interim fast path is gone now that Logging
    // exists. HomePage calls `refresh()` on dismiss so the ring/fertility/chip state picks up
    // whatever was just logged. Each category opens its own screen (CategoryLogViews.swift)
    // instead of one shared combined form.
    func tapPeriod() { activeSheet = .period }
    func presentSymptomsSheet() { activeSheet = .symptoms }
    func presentMoodSheet() { activeSheet = .mood }
    func presentFlowSheet() { activeSheet = .flow }
    func presentActivitySheet() { activeSheet = .activity }
    func presentMoreSheet() { activeSheet = .more }

    // MARK: - Private helpers

    // Drives the "More" quick-log button's logged-today dot — true if any of the categories
    // without their own dedicated screen (see CategoryLogViews.swift) has a value today.
    private static func hasMoreCategoriesLogged(_ log: Log?) -> Bool {
        guard let log else { return false }
        return !(log.sexualActivity?.isEmpty ?? true)
            || log.sexDrive != nil
            || log.vaginalDischarge != nil
            || log.ovulationTestResult != nil
            || log.pregnancyTest != nil
            || log.oralContraceptiveStatus != nil
            || !(log.digestionAndStool?.isEmpty ?? true)
            || !(log.other?.isEmpty ?? true)
    }

    private static func periodCovers(day: Date, log: PeriodLog, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: log.startDate)
        let end = calendar.startOfDay(for: log.endDate)
        return dayStart >= start && dayStart <= end
    }

    // Builds a scrollable carousel of weeks (8 weeks back, 1 week forward, plus today's own
    // week) rather than just the current calendar week, so swiping the strip actually goes
    // somewhere — per the "should be scrollable horizontally like a carousel" request.
    private static func buildWeeks(
        today: Date, periods: [PeriodLog], calendar: Calendar
    ) -> (weeks: [WeekItem], todayWeekID: WeekItem.ID?) {
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfTodaysWeek = calendar.date(
            byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: today)
        ) else {
            return ([], nil)
        }

        let weeksBack = 8
        let weeksForward = 1
        let letterFormatter = DateFormatter()
        letterFormatter.dateFormat = "E"

        var weeks: [WeekItem] = []
        var todayWeekID: WeekItem.ID?

        for weekOffset in -weeksBack...weeksForward {
            guard let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: startOfTodaysWeek) else { continue }

            let days: [WeekDayItem] = (0..<7).compactMap { dayOffset -> WeekDayItem? in
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { return nil }
                let letter = String(letterFormatter.string(from: date).prefix(1))
                let number = calendar.component(.day, from: date)
                let isToday = calendar.isDate(date, inSameDayAs: today)
                let hasFlow = periods.contains { periodCovers(day: date, log: $0, calendar: calendar) }
                return WeekDayItem(date: date, letter: letter, number: number, isToday: isToday, hasPeriodFlow: hasFlow)
            }

            let week = WeekItem(days: days)
            weeks.append(week)
            if weekOffset == 0 { todayWeekID = week.id }
        }

        return (weeks, todayWeekID)
    }

    private static func averagePeriodLength(periods: [PeriodLog], calendar: Calendar) -> Double {
        let lengths: [Double] = periods.compactMap { log in
            guard log.startDate != log.endDate else { return nil } // open period — length not known yet
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: log.startDate),
                to: calendar.startOfDay(for: log.endDate)
            ).day ?? 0
            return Double(days + 1)
        }
        guard !lengths.isEmpty else { return PredictionConstants.assumedMenstrualPhaseLength }
        return lengths.reduce(0, +) / Double(lengths.count)
    }

    private static func fertilityStatusSentence(today: Date, window: FertilityWindow, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: today)
        let start = calendar.startOfDay(for: window.fertileWindowStart)
        let end = calendar.startOfDay(for: window.fertileWindowEnd)
        let ovulation = calendar.startOfDay(for: window.estimatedOvulationDate)

        if day < start {
            return "Low — your fertile window hasn't started yet"
        } else if day == ovulation {
            return "High — today is your estimated ovulation day"
        } else if day >= start && day <= end {
            return "High — you're in your fertile window"
        } else {
            return "Low — past ovulation"
        }
    }

    private static func buildPatternInsights(
        logs: [Log],
        periodStartDates: [Date],
        typicalCycleLength: Double,
        typicalLutealPhaseLength: Double,
        currentPhase: CyclePhase,
        calendar: Calendar
    ) -> [PatternInsight] {
        let symptomObservations: [SymptomCorrelationEngine.SymptomObservation] = logs.compactMap { log in
            guard let symptoms = log.symptoms else { return nil }
            let filtered = symptoms.filter { $0 != .everythingIsFine }
            guard !filtered.isEmpty else { return nil }
            return SymptomCorrelationEngine.SymptomObservation(date: log.timestamp, symptoms: filtered)
        }
        let moodObservations: [SymptomCorrelationEngine.MoodObservation] = logs.compactMap { log in
            guard let moods = log.mood, !moods.isEmpty else { return nil }
            return SymptomCorrelationEngine.MoodObservation(date: log.timestamp, moods: moods)
        }

        let symptomFrequencies = SymptomCorrelationEngine.phaseFrequencies(
            observations: symptomObservations,
            periodStartDates: periodStartDates,
            typicalCycleLength: typicalCycleLength,
            typicalLutealPhaseLength: typicalLutealPhaseLength,
            calendar: calendar
        )
        let moodFrequencies = SymptomCorrelationEngine.moodPhaseFrequencies(
            observations: moodObservations,
            periodStartDates: periodStartDates,
            typicalCycleLength: typicalCycleLength,
            typicalLutealPhaseLength: typicalLutealPhaseLength,
            calendar: calendar
        )

        struct Candidate {
            let phrase: String
            let occurrences: Int
            let cyclesObserved: Int
            let ratio: Double
        }

        var candidates: [Candidate] = []

        // 50%-occurrence-over-observed-cycles floor — below this, the pattern is too thin to
        // surface as "this is what you might notice," per ARCHITECTURE.md's retrospective-only
        // framing for this engine.
        for frequency in symptomFrequencies where frequency.phase == currentPhase && frequency.cyclesObserved > 0 {
            let ratio = Double(frequency.occurrences) / Double(frequency.cyclesObserved)
            guard ratio >= 0.5 else { continue }
            candidates.append(Candidate(
                phrase: phrase(forSymptom: frequency.symptom),
                occurrences: frequency.occurrences,
                cyclesObserved: frequency.cyclesObserved,
                ratio: ratio
            ))
        }

        for frequency in moodFrequencies where frequency.phase == currentPhase && frequency.cyclesObserved > 0 {
            let ratio = Double(frequency.occurrences) / Double(frequency.cyclesObserved)
            guard ratio >= 0.5 else { continue }
            candidates.append(Candidate(
                phrase: phrase(forMood: frequency.mood),
                occurrences: frequency.occurrences,
                cyclesObserved: frequency.cyclesObserved,
                ratio: ratio
            ))
        }

        return candidates
            .sorted { $0.ratio > $1.ratio }
            .prefix(3)
            .map { candidate in
                PatternInsight(
                    text: "You might \(candidate.phrase) today — shown up in \(candidate.occurrences) of your last \(candidate.cyclesObserved) cycles."
                )
            }
    }

    // MARK: - Phrasing lookups (UI copy, so it lives here rather than in the UI-agnostic engine)

    private static func phrase(forSymptom symptom: Symptoms) -> String {
        switch symptom {
        case .everythingIsFine: return "feel like everything's fine" // filtered out before this is ever reached
        case .cramps: return "feel some cramps"
        case .tenderBreasts: return "have tender breasts"
        case .headache: return "get a headache"
        case .acne: return "notice some acne"
        case .backache: return "have a backache"
        case .fatigue: return "feel fatigued"
        case .cravings: return "get cravings"
        case .insomnia: return "have trouble sleeping"
        case .abdominalPain: return "have abdominal pain"
        case .vaginalItching: return "experience vaginal itching"
        case .vaginalDryness: return "experience vaginal dryness"
        }
    }

    private static func phrase(forMood mood: Mood) -> String {
        switch mood {
        case .calm: return "feel calm"
        case .happy: return "feel happy"
        case .energetic: return "feel energetic"
        case .frisky: return "feel frisky"
        case .moodSwings: return "have mood swings"
        case .irritated: return "feel irritated"
        case .sad: return "feel sad"
        case .anxious: return "feel anxious"
        case .depressed: return "feel low"
        case .feelingGuilty: return "feel guilty"
        case .obsessiveThoughts: return "have obsessive thoughts"
        case .lowEnergy: return "have low energy"
        case .apathetic: return "feel apathetic"
        case .confused: return "feel confused"
        case .verySelfCritical: return "be hard on yourself"
        }
    }

    // Short labels for the quick-log sheet rows and today's chip strip — derived from the raw
    // case name (e.g. `.tenderBreasts` -> "Tender breasts") rather than a second exhaustive
    // switch, since these just need a readable noun, not a grammatical sentence fragment.
    static func humanizeCaseName(_ raw: String) -> String {
        var result = ""
        for (index, character) in raw.enumerated() {
            if character.isUppercase {
                if index != 0 { result += " " }
                result += character.lowercased()
            } else {
                result += String(character)
            }
        }
        guard let first = result.first else { return result }
        return first.uppercased() + result.dropFirst()
    }

    private static func chips(for log: Log?) -> [String] {
        guard let log else { return [] }
        var chips: [String] = []
        if let mood = log.mood { chips += mood.map { humanizeCaseName(String(describing: $0)) } }
        if let symptoms = log.symptoms { chips += symptoms.map { humanizeCaseName(String(describing: $0)) } }
        if let sexualActivity = log.sexualActivity {
            chips += sexualActivity.map { humanizeCaseName(String(describing: $0)) }
        }
        if let sexDrive = log.sexDrive { chips.append(humanizeCaseName(String(describing: sexDrive))) }
        if let vaginalDischarge = log.vaginalDischarge {
            chips.append(humanizeCaseName(String(describing: vaginalDischarge)))
        }
        if let ovulationTestResult = log.ovulationTestResult {
            chips.append(humanizeCaseName(String(describing: ovulationTestResult)))
        }
        if let pregnancyTest = log.pregnancyTest { chips.append(humanizeCaseName(String(describing: pregnancyTest))) }
        if let oralContraceptiveStatus = log.oralContraceptiveStatus {
            chips.append(humanizeCaseName(String(describing: oralContraceptiveStatus)))
        }
        if let physicalActivity = log.physicalActivity {
            chips += physicalActivity.map { humanizeCaseName(String(describing: $0)) }
        }
        if let digestionAndStool = log.digestionAndStool {
            chips += digestionAndStool.map { humanizeCaseName(String(describing: $0)) }
        }
        if let flowIntensity = log.flowIntensity {
            chips.append(humanizeCaseName(String(describing: flowIntensity)) + " flow")
        }
        if let other = log.other { chips += other.map { humanizeCaseName(String(describing: $0)) } }
        return chips
    }
}
