import SwiftUI

// Step 1: anchors the first PeriodLog via CycleRepository.logPeriod(start:end:for:) once
// onboarding finishes — see OnboardingViewModel.completeOnboarding. Uses the same
// PeriodDayRangeCalendar as LogPeriodView (Modules/Features/Logging) so there's one period-
// logging interaction in the app, and so the very first period isn't modeled as "still in
// progress" the way a single start-date picker + `startPeriod` would (LogPeriodView would then
// show it as an open/ongoing period, which is wrong for a period that already happened).
struct LastPeriodStepView: View {
    @Binding var selectedDays: Set<Date>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When was your last period?")
                .font(.title2.bold())

            Text("Tap every day it lasted — periods vary in length, so we don't assume one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            PeriodDayRangeCalendar(selectedDays: $selectedDays)
        }
    }
}

#Preview {
    LastPeriodStepView(selectedDays: .constant([]))
        .padding()
}
