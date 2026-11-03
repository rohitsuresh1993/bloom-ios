import SwiftUI

// Step 1: anchors the first PeriodLog via CycleRepository.startPeriod(on:for:) once onboarding
// finishes — see OnboardingViewModel.completeOnboarding.
struct LastPeriodStepView: View {
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When did your last period start?")
                .font(.title2.bold())

            Text("This gives us a starting point for your next predicted period.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DatePicker(
                "Last period start date",
                selection: $date,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
    }
}

#Preview {
    LastPeriodStepView(date: .constant(Date()))
        .padding()
}
