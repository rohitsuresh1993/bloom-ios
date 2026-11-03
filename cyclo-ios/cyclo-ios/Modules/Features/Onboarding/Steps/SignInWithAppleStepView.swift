import SwiftUI

// Step 5: optional, explicitly skippable — Cyclo's core logging must never require signing in
// (see AppleSignInProviding's doc comment and ARCHITECTURE.md's "Account model"). This is the
// only step with its own dedicated skip affordance, since the root view's "Continue" button
// doubles as "Finish" everywhere else but shouldn't look like it's requiring sign-in here.
struct SignInWithAppleStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onSkip: () -> Void

    @State private var isSigningIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in with Apple?")
                .font(.title2.bold())

            Text("Completely optional. Cyclo works fully offline without it — signing in just makes it possible to carry a backup of your account across devices later. We never request your name or email.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.appleSignInState == .signedIn {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Signed in with Apple")
                }
                .padding(.top, 8)
            } else {
                Button {
                    Task {
                        isSigningIn = true
                        await viewModel.signInWithApple()
                        isSigningIn = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "applelogo")
                        Text(isSigningIn ? "Signing in..." : "Sign in with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(isSigningIn)

                Button("Skip for now", action: onSkip)
                    .padding(.top, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    SignInWithAppleStepView(viewModel: OnboardingViewModel(), onSkip: {})
        .padding()
}
