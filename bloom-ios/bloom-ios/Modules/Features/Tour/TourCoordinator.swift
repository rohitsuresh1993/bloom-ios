import SwiftUI

// Drives the onboarding tour's step sequence. Doesn't know about tabs or sheets itself — each
// consumer (RootTabView for tab switches, HomePage for sheet presentation + the two
// conditionally-absent steps) reads `currentStep` and reacts on its own, since TourCoordinator
// has no reference to AppTabCoordinator or HomeViewModel and shouldn't need one.
@MainActor
final class TourCoordinator: ObservableObject {
    static let tourCompletedDefaultsKey = "bloom.tourCompleted"

    @Published private(set) var isActive = false
    @Published private(set) var stepIndex = 0
    // Populated by whichever mount point's `.onPreferenceChange(TourAnchorPreferenceKey.self)`
    // currently has the active step's target in its own view tree. Deliberately never cleared by
    // `start()`/`finish()`: an `Anchor<CGRect>` resolves its *current* live position lazily every
    // time it's looked up, so a "stale" entry for a view that's still mounted (every tab in this
    // app stays mounted for its lifetime once created) is still correct — clearing it here just
    // meant Retake Tour had nothing to show until something coincidentally re-rendered that tab.
    @Published var anchors: [TourStep: Anchor<CGRect>] = [:]

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currentStep: TourStep? {
        isActive ? TourStep.allCases[stepIndex] : nil
    }

    // Resolves the current step's anchor against whichever GeometryProxy is asking — the caller
    // is responsible for that proxy actually being a real ancestor of wherever the anchor was
    // captured (see TourOverlayView's doc comment for why that matters).
    func resolvedCutoutRect(in proxy: GeometryProxy) -> CGRect? {
        guard let currentStep else { return nil }
        return anchors[currentStep].map { proxy[$0] }
    }

    func start() {
        stepIndex = 0
        isActive = true
    }

    func advance() {
        let next = stepIndex + 1
        if next >= TourStep.allCases.count {
            finish()
        } else {
            stepIndex = next
        }
    }

    func skip() {
        finish()
    }

    private func finish() {
        isActive = false
        userDefaults.set(true, forKey: Self.tourCompletedDefaultsKey)
    }
}
