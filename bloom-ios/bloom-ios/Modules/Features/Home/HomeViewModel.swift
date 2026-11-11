//
//  HomeViewModel.swift
//  bloom-ios
//
//  Owns Home's data-fetching/computation: builds on the repositories HomePage hands it (from
//  `@Environment(\.modelContext)`), runs the Prediction engines, and exposes plain view-ready
//  `@Published` state.
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

    // Whether a given insight is drawn from this user's own logged history or, below the data
    // threshold, from PopulationInsights' cold-start generalizations — the card reads this to
    // caption itself honestly rather than presenting population stats as personal.
    enum InsightSource {
        case personal
        case population
    }

    struct PatternInsight: Identifiable {
        let id = UUID()
        let text: String
        let source: InsightSource
    }

    // Which full-screen Logging sheet (built by the Logging feature) is presented over Home.
    // `.period` keeps its own calendar-based screen (LogPeriodView); every other category lives
    // on the single unified TodayLogView now (see LogCategoryKind) — `logScrollTarget` says
    // which of its cards to scroll to when opened from one of Home's quick-log buttons.
    enum ActiveSheet: Identifiable {
        case period
        case today

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

    // Mood/Symptoms insight cards (empty => render nothing). Kept as two separate published
    // arrays, not one combined list, so Home can render them as two distinct cards.
    @Published private(set) var moodInsights: [PatternInsight] = []
    @Published private(set) var symptomInsights: [PatternInsight] = []

    // Quick-log row + today's chip strip
    @Published private(set) var todaysChips: [String] = []
    @Published private(set) var periodLoggedToday: Bool = false
    @Published private(set) var flowLoggedToday: Bool = false
    // Drives the "+" quick-log button's logged-today dot — true if anything other than Period
    // or Flow (which have their own buttons) has a value today.
    @Published private(set) var moreLoggedToday: Bool = false
    @Published var activeSheet: ActiveSheet?
    @Published private(set) var logScrollTarget: LogCategoryKind?
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
            flowLoggedToday = todaysLogValue?.flowIntensity != nil
            moreLoggedToday = Self.hasMoreCategoriesLogged(todaysLogValue)
            todaysChips = Self.chips(for: todaysLogValue)

            guard hasCycleData else {
                fertileArcRange = nil
                fertilityCard = nil
                moodInsights = []
                symptomInsights = []
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

            // Within a week of the predicted next period (today through 7 days out), a countdown
            // is more useful than "Day N / phase" — and meaningful even on hormonal contraception,
            // since a predicted withdrawal bleed date is still a real date. Takes priority over
            // both the normal phase subtitle and the contraception-only "DAY OF CYCLE" one above.
            // Outside this window (including an overdue/negative days-until with no new period
            // logged yet) the normal "Day N" display from above is left untouched.
            let daysUntilPeriod = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: today),
                to: calendar.startOfDay(for: prediction.predictedStartDate)
            ).day ?? Int.max
            switch daysUntilPeriod {
            case 0:
                ringCenterTitle = "Today"
                ringCenterSubtitle = "PERIOD DUE"
            case 1:
                ringCenterTitle = "1"
                ringCenterSubtitle = "DAY UNTIL PERIOD"
            case 2...7:
                ringCenterTitle = "\(daysUntilPeriod)"
                ringCenterSubtitle = "DAYS UNTIL PERIOD"
            default:
                break
            }

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

            // Below 3 observed cycles (same ConfidenceLevel.stillLearning threshold used for the
            // fertile-window gate above), this user's own per-phase frequencies are too thin to
            // trust — fall back to PopulationInsights' cold-start generalizations instead of
            // showing nothing. Re-checked per category below too, since even with >=3 cycles a
            // *specific* phase/symptom combination can still fail to clear the 50% ratio floor.
            let logsThisHistory = try logRepository.logs(from: sortedStarts.first ?? today, to: today)
            let hasEnoughPersonalData = prediction.confidence != .stillLearning
            symptomInsights = Self.buildSymptomInsights(
                logs: logsThisHistory,
                periodStartDates: sortedStarts,
                typicalCycleLength: prediction.predictedCycleLength,
                typicalLutealPhaseLength: lutealLengthForBucketing,
                currentPhase: currentPhase,
                hasEnoughPersonalData: hasEnoughPersonalData,
                calendar: calendar
            )
            moodInsights = Self.buildMoodInsights(
                logs: logsThisHistory,
                periodStartDates: sortedStarts,
                typicalCycleLength: prediction.predictedCycleLength,
                typicalLutealPhaseLength: lutealLengthForBucketing,
                currentPhase: currentPhase,
                hasEnoughPersonalData: hasEnoughPersonalData,
                calendar: calendar
            )
        } catch {
            errorMessage = "Couldn't load your cycle data."
        }
    }

    // MARK: - Quick log row

    // Opens the real Logging feature's screens (Modules/Features/Logging) as sheets, rather than
    // mutating repositories directly here — that interim fast path is gone now that Logging
    // exists. HomePage calls `refresh()` on dismiss so the ring/fertility/chip state picks up
    // whatever was just logged. Every category but Period shares TodayLogView now; each button
    // just sets which of its cards to land on.
    func tapPeriod() { activeSheet = .period }
    func presentFlowSheet() { logScrollTarget = .flowIntensity; activeSheet = .today }
    func presentMoreSheet() { logScrollTarget = nil; activeSheet = .today }

    // MARK: - Private helpers

    private static func hasMoreCategoriesLogged(_ log: Log?) -> Bool {
        guard let log else { return false }
        return !(log.mood?.isEmpty ?? true)
            || !(log.symptoms?.isEmpty ?? true)
            || !(log.physicalActivity?.isEmpty ?? true)
            || !(log.sexualActivity?.isEmpty ?? true)
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

    private struct PersonalCandidate {
        let phrase: String
        let occurrences: Int
        let cyclesObserved: Int
        let ratio: Double
    }

    private static func buildSymptomInsights(
        logs: [Log],
        periodStartDates: [Date],
        typicalCycleLength: Double,
        typicalLutealPhaseLength: Double,
        currentPhase: CyclePhase,
        hasEnoughPersonalData: Bool,
        calendar: Calendar
    ) -> [PatternInsight] {
        if hasEnoughPersonalData {
            let observations: [SymptomCorrelationEngine.SymptomObservation] = logs.compactMap { log in
                guard let symptoms = log.symptoms else { return nil }
                let filtered = symptoms.filter { $0 != .everythingIsFine }
                guard !filtered.isEmpty else { return nil }
                return SymptomCorrelationEngine.SymptomObservation(date: log.timestamp, symptoms: filtered)
            }
            let frequencies = SymptomCorrelationEngine.phaseFrequencies(
                observations: observations,
                periodStartDates: periodStartDates,
                typicalCycleLength: typicalCycleLength,
                typicalLutealPhaseLength: typicalLutealPhaseLength,
                calendar: calendar
            )

            // 50%-occurrence-over-observed-cycles floor — below this, the pattern is too thin to
            // surface as "this is what you might notice," per ARCHITECTURE.md's retrospective-
            // only framing for this engine.
            let personal = frequencies
                .filter { $0.phase == currentPhase && $0.cyclesObserved > 0 }
                .compactMap { frequency -> PersonalCandidate? in
                    let ratio = Double(frequency.occurrences) / Double(frequency.cyclesObserved)
                    guard ratio >= 0.5 else { return nil }
                    return PersonalCandidate(
                        phrase: phrase(forSymptom: frequency.symptom),
                        occurrences: frequency.occurrences,
                        cyclesObserved: frequency.cyclesObserved,
                        ratio: ratio
                    )
                }
                .sorted { $0.ratio > $1.ratio }

            if !personal.isEmpty {
                return personal.prefix(3).map { candidate in
                    PatternInsight(
                        text: "You might \(candidate.phrase) today — shown up in "
                            + "\(candidate.occurrences) of your last \(candidate.cyclesObserved) cycles.",
                        source: .personal
                    )
                }
            }
        }

        // Cold start, or this phase just hasn't produced a confident personal pattern yet.
        return PopulationInsights.topSymptoms(forPhase: currentPhase).prefix(3).map { symptom in
            PatternInsight(
                text: "Many people \(phrase(forSymptom: symptom)) during the "
                    + "\(currentPhase.displayName.lowercased()) phase.",
                source: .population
            )
        }
    }

    private static func buildMoodInsights(
        logs: [Log],
        periodStartDates: [Date],
        typicalCycleLength: Double,
        typicalLutealPhaseLength: Double,
        currentPhase: CyclePhase,
        hasEnoughPersonalData: Bool,
        calendar: Calendar
    ) -> [PatternInsight] {
        if hasEnoughPersonalData {
            let observations: [SymptomCorrelationEngine.MoodObservation] = logs.compactMap { log in
                guard let moods = log.mood, !moods.isEmpty else { return nil }
                return SymptomCorrelationEngine.MoodObservation(date: log.timestamp, moods: moods)
            }
            let frequencies = SymptomCorrelationEngine.moodPhaseFrequencies(
                observations: observations,
                periodStartDates: periodStartDates,
                typicalCycleLength: typicalCycleLength,
                typicalLutealPhaseLength: typicalLutealPhaseLength,
                calendar: calendar
            )

            let personal = frequencies
                .filter { $0.phase == currentPhase && $0.cyclesObserved > 0 }
                .compactMap { frequency -> PersonalCandidate? in
                    let ratio = Double(frequency.occurrences) / Double(frequency.cyclesObserved)
                    guard ratio >= 0.5 else { return nil }
                    return PersonalCandidate(
                        phrase: phrase(forMood: frequency.mood),
                        occurrences: frequency.occurrences,
                        cyclesObserved: frequency.cyclesObserved,
                        ratio: ratio
                    )
                }
                .sorted { $0.ratio > $1.ratio }

            if !personal.isEmpty {
                return personal.prefix(3).map { candidate in
                    PatternInsight(
                        text: "You might \(candidate.phrase) today — shown up in "
                            + "\(candidate.occurrences) of your last \(candidate.cyclesObserved) cycles.",
                        source: .personal
                    )
                }
            }
        }

        return PopulationInsights.topMoods(forPhase: currentPhase).prefix(3).map { mood in
            PatternInsight(
                text: "Many people \(phrase(forMood: mood)) during the "
                    + "\(currentPhase.displayName.lowercased()) phase.",
                source: .population
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
