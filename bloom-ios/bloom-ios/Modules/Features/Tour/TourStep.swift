import Foundation

// The 10 stops of the onboarding tour, in order. Each carries which tab must be selected and,
// for the two steps that live inside a sheet rather than directly on a tab, which sheet must be
// open — TourCoordinator's consumers (RootTabView, HomePage) read this to drive navigation
// themselves rather than the tour reaching into other screens' state directly.
enum TourStep: Int, CaseIterable, Identifiable {
    case cycleRing
    case weekStrip
    case quickLogRow
    case logPeriod
    case todayLog
    case insightsDeck
    case fertilityCard
    case calendarDay
    case profileEdit

    var id: Int { rawValue }

    var requiredTab: AppTab {
        switch self {
        case .cycleRing, .weekStrip, .quickLogRow, .insightsDeck, .fertilityCard, .todayLog, .logPeriod:
            return .home
        case .calendarDay:
            return .calendar
        case .profileEdit:
            return .profile
        }
    }

    // Only todayLog/logPeriod live inside a sheet rather than directly on their tab.
    var requiredSheet: HomeViewModel.ActiveSheet? {
        switch self {
        case .todayLog: return .today
        case .logPeriod: return .period
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .cycleRing: return "Your cycle at a glance"
        case .weekStrip: return "Jump back to today"
        case .quickLogRow: return "Quick logging"
        case .insightsDeck: return "Predicted for you"
        case .fertilityCard: return "Fertility window"
        case .calendarDay: return "Your history"
        case .profileEdit: return "Keep your profile current"
        case .todayLog: return "Log anything"
        case .logPeriod: return "Log a period"
        }
    }

    var message: String {
        switch self {
        case .cycleRing:
            return "This ring shows your current phase, and counts down once your period is close. The label below it says how confident Bloom is — that grows as you log more cycles."
        case .weekStrip:
            return "Swipe through past and upcoming weeks. Double-tap the strip any time to jump straight back to today."
        case .quickLogRow:
            return "Period opens a calendar to log period days. Log opens everything else — mood, symptoms, activity. Flow jumps straight to today's flow intensity."
        case .insightsDeck:
            return "Predicted moods and symptoms for this phase, based on your own history once you have some. Swipe up or down — or just tap — to cycle through them. These are forecasts, not guarantees."
        case .fertilityCard:
            return "Once you've logged 3 cycles, your estimated fertile window and ovulation day show up here — like this:"
        case .calendarDay:
            return "Filled days are logged periods, ringed days have other logs, dotted days are predicted. Tap any day to see what's logged."
        case .profileEdit:
            return "Update your date of birth, known conditions, or cycle length here any time — Bloom's predictions adjust to match."
        case .todayLog:
            return "One screen for everything but your period — mood, symptoms, flow, activity, and more. Search to find a category fast."
        case .logPeriod:
            return "Tap the first day of a period and the next few days highlight automatically. Dotted days are Bloom's prediction for your next one."
        }
    }
}
