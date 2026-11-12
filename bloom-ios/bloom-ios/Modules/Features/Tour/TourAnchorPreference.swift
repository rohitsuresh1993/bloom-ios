import SwiftUI

// First custom PreferenceKey in this codebase. Lets any view mark itself as a tour target without
// needing a reference to TourCoordinator — the anchor just bubbles up to whichever ancestor is
// collecting it (see TourCoordinator's three mount points: RootTabView, LogPeriodView,
// TodayLogView — one per presentation context, since a `.sheet()`'s content is a separate view
// tree for preference-propagation purposes and can't be seen from outside it).
struct TourAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [TourStep: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourStep: Anchor<CGRect>], nextValue: () -> [TourStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func tourAnchor(_ step: TourStep) -> some View {
        anchorPreference(key: TourAnchorPreferenceKey.self, value: .bounds) { [step: $0] }
    }
}
