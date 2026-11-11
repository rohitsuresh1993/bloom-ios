import SwiftUI

// Step 3: feeds UserRepository.updateProfile(name:dateOfBirth:knownConditions:), which is also
// the age-bucket lookup key for PriorTable. Range mirrors UserRepository's own validation
// (not in the future, not more than 120 years ago) so the picker can't produce a value the
// repository would reject.
struct DateOfBirthStepView: View {
    @Binding var date: Date

    private var dateRange: ClosedRange<Date> {
        let now = Date()
        let earliest = Calendar.current.date(byAdding: .year, value: -120, to: now) ?? .distantPast
        return earliest...now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When were you born?")
                .font(.title2.bold())

            Text("Cycle length and variability both shift with age, so this helps us start with a more accurate estimate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DatePicker(
                "Date of birth",
                selection: $date,
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
        }
    }
}

#Preview {
    DateOfBirthStepView(date: .constant(Date()))
        .padding()
}
