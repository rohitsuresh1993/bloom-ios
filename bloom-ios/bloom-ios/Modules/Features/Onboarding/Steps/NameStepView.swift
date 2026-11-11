import SwiftUI

// Step 0 (first step): feeds UserRepository.updateProfile(name:dateOfBirth:knownConditions:).
// It's the very first thing a new user sees, so the field gets a larger font than the rest of
// the flow's body text.
struct NameStepView: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should we call you?")
                .font(.title2.bold())

            Text("We'll use this to personalize your experience — it's never shared.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Your name", text: $name)
                .font(.title2)
                .textInputAutocapitalization(.words)
                .textContentType(.name)
                .autocorrectionDisabled()
        }
    }
}

#Preview {
    NameStepView(name: .constant(""))
        .padding()
}
