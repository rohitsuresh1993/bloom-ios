//
//  HistoryCalendarView.swift
//  bloom-ios
//
//  Read-only month calendar for CalendarPage — distinct from Logging's PeriodDayRangeCalendar,
//  which is a selection *editor* for logging a period. This one never mutates anything: it just
//  highlights history (period days filled, other logged days ringed) and reports taps via
//  `onSelectDay` so the caller can show what was logged that day.
//

import SwiftUI

struct HistoryCalendarView: View {
    let periodDays: Set<Date>
    let loggedDays: Set<Date>
    let onSelectDay: (Date) -> Void

    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let maxSelectableMonth = Date()

    init(
        periodDays: Set<Date>,
        loggedDays: Set<Date>,
        initialMonth: Date = Date(),
        onSelectDay: @escaping (Date) -> Void
    ) {
        self.periodDays = periodDays
        self.loggedDays = loggedDays
        self.onSelectDay = onSelectDay
        self._displayedMonth = State(initialValue: Calendar.current.startOfDay(for: initialMonth))
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdaySymbolsRow
            dayGrid
            legend
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { shiftMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(action: { shiftMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(isNextMonthDisabled)
        }
        // Same fix as PeriodDayRangeCalendar's identical comment: unstyled Buttons sharing a
        // List/Form row pick up the row's own tap handling instead of acting independently.
        .contentShape(Rectangle())
    }

    private var weekdaySymbolsRow: some View {
        HStack {
            ForEach(calendar.veryShortStandaloneWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysInDisplayedMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let normalized = calendar.startOfDay(for: day)
        let isPeriodDay = periodDays.contains(normalized)
        let isLoggedOnly = !isPeriodDay && loggedDays.contains(normalized)
        let isToday = calendar.isDateInToday(day)

        return Button {
            onSelectDay(normalized)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.subheadline.weight(isPeriodDay ? .bold : .regular))
                .foregroundStyle(isPeriodDay ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isPeriodDay ? Color.bloomPrimary : Color.clear)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.bloomSecondary, lineWidth: isLoggedOnly ? 1.5 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(isToday ? 0.4 : 0), lineWidth: 1)
                        .padding(1)
                )
                .contentShape(Circle())
        }
        // .plain for the same reason PeriodDayRangeCalendar's dayCell needs it — see that file's
        // comment on this exact line.
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(Color.bloomPrimary).frame(width: 10, height: 10)
                Text("Period").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Circle().strokeBorder(Color.bloomSecondary, lineWidth: 1.5).frame(width: 10, height: 10)
                Text("Logged").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var isNextMonthDisabled: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return true }
        return calendar.compare(nextMonth, to: maxSelectableMonth, toGranularity: .month) == .orderedDescending
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }

    // 42 slots (6 full weeks) for the displayed month; nil entries are leading/trailing padding.
    private func daysInDisplayedMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekdayOfMonth = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }

        let leadingEmptyCount = ((firstWeekdayOfMonth - calendar.firstWeekday) + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var result: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
        for dayOffset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
}

#Preview {
    HistoryCalendarView(periodDays: [Date()], loggedDays: []) { _ in }
        .padding()
}
