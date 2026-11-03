import SwiftUI

// PLACEHOLDER COPY — this is not a real privacy policy. It exists so the "Privacy Policy" row in
// Settings has somewhere to go during development. Before shipping, this text needs to be
// replaced with an actual policy reviewed by counsel, covering what Cyclo actually collects/
// stores/exports (SwiftData locally, optional HealthKit export, optional Sign in with Apple —
// see ARCHITECTURE.md) and in what jurisdictions.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle.bold())

                Text("Placeholder — not yet reviewed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("""
                This is placeholder text standing in for Cyclo's privacy policy. It has not been \
                written or reviewed by legal counsel and must not be treated as a real policy.

                In its final form, this screen should describe, in plain language: what data \
                Cyclo collects (cycle logs, symptoms, and any profile details you enter), where \
                it's stored (locally on your device via SwiftData), what — if anything — is sent \
                elsewhere (an optional, user-controlled export of your data to Apple Health, and \
                an optional Sign in with Apple identifier used only to identify your device), and \
                how you can delete it (the "Delete All My Data" action in Settings).

                Replace this entire placeholder before this app ships to the App Store.
                """)
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
