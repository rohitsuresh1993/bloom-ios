import SwiftData
import SwiftUI

@main
struct BloomApp: App {
    private let modelContainer = PersistenceController.makeContainer()

    // Mirrors ProfilePage's own `@AppStorage` of the same key — set from its Appearance section.
    @AppStorage("bloom.colorSchemeOverride") private var colorSchemeOverride: String = "system"

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemeOverride {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .preferredColorScheme(resolvedColorScheme)
        }
        .modelContainer(modelContainer)
    }
}

// Branches between the Onboarding flow and the real app, based on a simple UserDefaults bool
// flag rather than a persisted model field — Onboarding flips this once it finishes
// (OnboardingViewModel.completeOnboarding).
private struct RootRouterView: View {
    @AppStorage(OnboardingViewModel.onboardingCompletedDefaultsKey) private var onboardingCompleted = false
    // Starts true on every cold launch (not persisted) — the in-app splash is meant to be seen
    // once per launch, not skipped on return visits within the same app session.
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            } else if onboardingCompleted {
                RootTabView()
                    .transition(.opacity)
            } else {
                OnboardingRootView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowingSplash)
        .task {
            try? await Task.sleep(for: .seconds(1))
            isShowingSplash = false
        }
    }
}
