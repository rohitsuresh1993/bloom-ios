import Foundation
import SwiftData

// Owns the onboarding flow's in-progress answers and the one-time writes that land them in
// Repositories/UserDefaults once the flow finishes. UI-agnostic about *what* it persists to
// (repositories, UserDefaults) but not about presentation — unlike Prediction/Auth, this is a
// feature view model, not a cross-cutting module, so it's fine for it to own that.
@MainActor
final class OnboardingViewModel: ObservableObject {
    static let cycleLengthBucketDefaultsKey = "bloom.selfReportedCycleLengthBucket"
    static let onboardingCompletedDefaultsKey = "bloom.onboardingCompleted"

    @Published var name: String = ""
    @Published var lastPeriodDays: Set<Date> = []
    @Published var cycleLengthBucket: SelfReportedCycleLengthBucket?
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var knownConditions: Set<MenstrualCondition> = []
    @Published var appleSignInState: AppleSignInState = .signedOut
    @Published var errorMessage: String?

    let appleSignInManager: AppleSignInProviding
    private let userDefaults: UserDefaults

    init(
        appleSignInManager: AppleSignInProviding = AppleSignInManager(
            presentationAnchorProvider: OnboardingPresentationAnchorProvider()
        ),
        userDefaults: UserDefaults = .standard
    ) {
        self.appleSignInManager = appleSignInManager
        self.userDefaults = userDefaults
    }

    // Optional and skippable — a failed or declined sign-in is never treated as fatal to
    // onboarding. Bloom's core logging must never require signing in.
    func signInWithApple() async {
        do {
            _ = try await appleSignInManager.signIn()
            appleSignInState = .signedIn
            errorMessage = nil
        } catch {
            // Swallow the specific error: the user can always retry from Settings later, and
            // this step is explicitly non-blocking.
            errorMessage = "Sign in with Apple didn't complete. You can try again later from Settings."
        }
    }

    // Anchors the first PeriodLog (as an already-ended historical period, not an open/ongoing
    // one — using `logPeriod` with the full day selection's start/end, not `startPeriod`, since
    // this period already happened), writes the self-reported profile, stashes the cold-start
    // cycle-length bucket, and flips the onboarding-completed flag — in that order, so the flag
    // only flips once everything else has actually saved.
    func completeOnboarding(modelContext: ModelContext) throws {
        let userRepository = UserRepository(modelContext: modelContext)
        let cycleRepository = CycleRepository(modelContext: modelContext)

        let user = try userRepository.currentUser()
        if let start = lastPeriodDays.min(), let end = lastPeriodDays.max() {
            _ = try cycleRepository.logPeriod(start: start, end: end, for: user)
        }
        _ = try userRepository.updateProfile(
            name: name,
            dateOfBirth: dateOfBirth,
            knownConditions: Array(knownConditions)
        )

        if let cycleLengthBucket {
            userDefaults.set(cycleLengthBucket.rawValue, forKey: Self.cycleLengthBucketDefaultsKey)
        }

        userDefaults.set(true, forKey: Self.onboardingCompletedDefaultsKey)
    }
}
