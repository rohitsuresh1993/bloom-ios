import SwiftData
import SwiftUI

@main
struct CycloApp: App {
    private let modelContainer = PersistenceController.makeContainer()
    private let appLockManager: AppLockManaging = AppLockManager()

    // Mirrors SettingsView's own `@AppStorage` of the same key — set from the Appearance section.
    @AppStorage("cyclo.colorSchemeOverride") private var colorSchemeOverride: String = "system"

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemeOverride {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            AppLockGateView(appLockManager: appLockManager) {
                RootRouterView()
            }
            .preferredColorScheme(resolvedColorScheme)
        }
        .modelContainer(modelContainer)
    }
}

// Branches between the Onboarding flow and the real app, based on the same simple
// UserDefaults-bool-flag pattern AppLockManager already uses for "cyclo.appLockEnabled" (see
// Modules/Security/AppLockManager.swift) rather than a persisted model field — Onboarding flips
// this once it finishes (OnboardingViewModel.completeOnboarding).
private struct RootRouterView: View {
    @AppStorage(OnboardingViewModel.onboardingCompletedDefaultsKey) private var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            HomePage()
        } else {
            OnboardingRootView()
        }
    }
}
