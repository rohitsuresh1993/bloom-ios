import Foundation

// Shared "upcoming predicted period days" forecast — used by HomeViewModel (the cycle-phase
// ring's "Period in N days" / "Next period: around X – Y"), CalendarPage, and LogPeriodView, so
// all three screens that show a forecast agree on the same one rather than drifting apart as
// each gets edited independently.
enum PeriodPrediction {
    static func upcomingPeriodDays(periods: [PeriodLog], user: User, calendar: Calendar) -> Set<Date> {
        let sortedStarts = periods.map(\.startDate).sorted()
        guard let lastPeriodStart = sortedStarts.last else { return [] }

        let cycleLengths: [Double] = zip(sortedStarts, sortedStarts.dropFirst()).map {
            Double(calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: $1)
            ).day ?? 0)
        }
        let age = calendar.dateComponents([.year], from: user.dateOfBirth, to: Date()).year ?? 25
        let prior = PriorTable.lookup(ageBucket: AgeBucket(age: age), conditions: user.knownConditions)
        let prediction = CyclePredictionEngine.predictNextPeriod(
            cycleLengths: cycleLengths,
            lastPeriodStartDate: lastPeriodStart,
            prior: prior,
            calendar: calendar
        )

        let periodLength = averagePeriodLength(periods: periods, calendar: calendar)
        var days: Set<Date> = []
        var current = calendar.startOfDay(for: prediction.predictedStartDate)
        for _ in 0..<max(Int(periodLength.rounded()), 1) {
            days.insert(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private static func averagePeriodLength(periods: [PeriodLog], calendar: Calendar) -> Double {
        let lengths: [Double] = periods.compactMap { log in
            guard log.startDate != log.endDate else { return nil } // open period — length not known yet
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: log.startDate), to: calendar.startOfDay(for: log.endDate)
            ).day ?? 0
            return Double(days + 1)
        }
        guard !lengths.isEmpty else { return PredictionConstants.assumedMenstrualPhaseLength }
        return lengths.reduce(0, +) / Double(lengths.count)
    }
}
