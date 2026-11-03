import SwiftData
import SwiftUI

// A fixed, manual step sequence rather than a NavigationStack — onboarding is linear with no
// deep-linkable destinations, so a simple switch over an ordered enum is the least machinery
// that does the job.
enum OnboardingStep: Int, CaseIterable {
    case name
    case lastPeriodStart
    case cycleLengthBucket
    case dateOfBirth
    case knownConditions
    case signInWithApple
}

struct OnboardingRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var step: OnboardingStep = .name

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(step.rawValue + 1), total: Double(OnboardingStep.allCases.count))
                .tint(.cycloPrimary)

            Spacer(minLength: 0)

            Group {
                switch step {
                case .name:
                    NameStepView(name: $viewModel.name)
                case .lastPeriodStart:
                    LastPeriodStepView(selectedDays: $viewModel.lastPeriodDays)
                case .cycleLengthBucket:
                    CycleLengthBucketStepView(selection: $viewModel.cycleLengthBucket)
                case .dateOfBirth:
                    DateOfBirthStepView(date: $viewModel.dateOfBirth)
                case .knownConditions:
                    KnownConditionsStepView(selection: $viewModel.knownConditions)
                case .signInWithApple:
                    SignInWithAppleStepView(viewModel: viewModel, onSkip: finish)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage = viewModel.errorMessage, step != .signInWithApple {
                // The sign-in step renders its own error inline (it's non-fatal to that step);
                // every other step's errors are completion-time failures surfaced here instead.
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack {
                if step != .name {
                    Button("Back", action: goBack)
                }

                Spacer()

                Button(step == .signInWithApple ? "Finish" : "Continue", action: goNext)
                    .buttonStyle(.borderedProminent)
                    .tint(.cycloPrimary)
                    .disabled(!canContinue)
            }
        }
        .padding()
    }

    private var canContinue: Bool {
        switch step {
        case .name:
            return !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .lastPeriodStart:
            return !viewModel.lastPeriodDays.isEmpty
        case .cycleLengthBucket:
            return viewModel.cycleLengthBucket != nil
        case .dateOfBirth, .knownConditions, .signInWithApple:
            return true
        }
    }

    private func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    private func goNext() {
        guard step != .signInWithApple else {
            finish()
            return
        }
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func finish() {
        do {
            try viewModel.completeOnboarding(modelContext: modelContext)
        } catch {
            viewModel.errorMessage = "Something went wrong saving your info. Please try again."
        }
    }
}

#Preview {
    OnboardingRootView()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
