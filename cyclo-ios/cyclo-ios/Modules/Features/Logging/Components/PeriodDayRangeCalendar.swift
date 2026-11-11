import SwiftUI
import UIKit

// Tap-to-toggle multi-day calendar for selecting the days of a period — used by LogPeriodView
// (both the current/new period and backfilling a past one) and Onboarding's LastPeriodStepView,
// so there's exactly one period-logging interaction in the app, not a "Start Period" button plus
// a separate picker for backfill. A tapped day toggles membership in `selectedDays`; storage only
// has a start/end date range (`PeriodLog` has no per-day granularity), so callers derive
// `start = selectedDays.min()`, `end = selectedDays.max()` — this view surfaces a note when the
// selection has gaps so that collapsing never happens silently.
struct PeriodDayRangeCalendar: View {
    @Binding var selectedDays: Set<Date>
    // Previously-logged period days outside the current selection (e.g. other periods in
    // history) — shown with a lighter ring so the user can see their logging history while
    // picking a new period, without it being confused for the active selection.
    let loggedDays: Set<Date>
    @State private var displayedMonth: Date
    // Tracks the in-flight auto-continue sequence (see `toggle`) so a new tap can cancel it
    // instead of racing it — otherwise a manual toggle mid-sequence and the sequence's own
    // inserts could stomp on each other.
    @State private var autoFillTask: Task<Void, Never>?

    private let calendar = Calendar.current
    private let maxSelectableDate = Date()

    init(selectedDays: Binding<Set<Date>>, loggedDays: Set<Date> = [], initialMonth: Date = Date()) {
        self._selectedDays = selectedDays
        self.loggedDays = loggedDays
        self._displayedMonth = State(initialValue: Calendar.current.startOfDay(for: initialMonth))
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdaySymbolsRow
            dayGrid

            if let start = selectedDays.min(), let end = selectedDays.max() {
                Text(selectionSummary(start: start, end: end))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if hasGaps {
                Text("Your selected days aren't consecutive — Cyclo logs a period as one continuous range, so the days in between will be included too.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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
        // Matches the day grid's fix below: unstyled Buttons sharing this view's single
        // Form/List row would pick up the row's own tap handling instead of acting as
        // independent controls, which is what made the chevrons stop responding after the
        // first tap.
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
        let isSelected = selectedDays.contains(normalized)
        let isPreviouslyLogged = !isSelected && loggedDays.contains(normalized)
        let isFuture = day > maxSelectableDate
        return Button {
            toggle(day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isFuture ? Color.secondary.opacity(0.3) : (isSelected ? .white : .primary))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isSelected ? Color.cycloPrimary : Color.clear)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.cycloPrimary.opacity(0.5), lineWidth: isPreviouslyLogged ? 1.5 : 0)
                )
                .contentShape(Circle())
        }
        // .plain is required here: inside a Form/List row, an unstyled Button picks up the
        // row's own tap-target/selection behavior, which — with ~35 Buttons packed into one
        // LazyVGrid row via Section — was causing a single tap to toggle every day in the grid
        // instead of just the tapped one.
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var hasGaps: Bool {
        guard let start = selectedDays.min(), let end = selectedDays.max() else { return false }
        let expectedCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return expectedCount != selectedDays.count
    }

    private var isNextMonthDisabled: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return true }
        return calendar.compare(nextMonth, to: maxSelectableDate, toGranularity: .month) == .orderedDescending
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }

    private func toggle(_ day: Date) {
        // Any existing auto-continue sequence must not fight a fresh tap, whether that tap
        // is a plain toggle or the start of a new sequence of its own.
        autoFillTask?.cancel()
        autoFillTask = nil

        let normalized = calendar.startOfDay(for: day)
        if selectedDays.contains(normalized) {
            selectedDays.remove(normalized)
            return
        }

        let isFreshSelection = selectedDays.isEmpty
        selectedDays.insert(normalized)
        guard isFreshSelection else { return }

        // First day tapped in a fresh selection (not extending/editing an existing range):
        // auto-continue selecting the next few days so the user doesn't have to tap through
        // an entire period length one day at a time, with a haptic per day added.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        autoFillTask = Task { [calendar, maxSelectableDate] in
            for offset in 1...4 {
                do {
                    try await Task.sleep(nanoseconds: 130_000_000)
                } catch {
                    return
                }
                if Task.isCancelled { return }

                guard let candidate = calendar.date(byAdding: .day, value: offset, to: normalized) else {
                    return
                }
                let normalizedCandidate = calendar.startOfDay(for: candidate)
                // Don't run the sequence past today.
                if normalizedCandidate > maxSelectableDate { return }

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    selectedDays.insert(normalizedCandidate)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    private func selectionSummary(start: Date, end: Date) -> String {
        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let formatter = Date.FormatStyle.dateTime.month(.abbreviated).day()
        if calendar.isDate(start, inSameDayAs: end) {
            return "1 day selected: \(start.formatted(formatter))"
        }
        return "\(dayCount) days selected: \(start.formatted(formatter)) – \(end.formatted(formatter))"
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
    PeriodDayRangeCalendar(selectedDays: .constant([Date()]))
        .padding()
}
