import SwiftUI

// Step 2: a rough self-reported cycle-length bucket, stored in UserDefaults (not a persisted
// model field — see PriorTable.SelfReportedCycleLengthBucket's doc comment) and used only to
// nudge the cold-start prior before the user has their own cycle history.
struct CycleLengthBucketStepView: View {
    @Binding var selection: SelfReportedCycleLengthBucket?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Roughly how long are your cycles?")
                .font(.title2.bold())

            Text("Just a rough idea — this only matters for the first few predictions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(SelfReportedCycleLengthBucket.allCases, id: \.self) { bucket in
                    optionRow(for: bucket)
                }
            }
        }
    }

    private func optionRow(for bucket: SelfReportedCycleLengthBucket) -> some View {
        Button {
            selection = bucket
        } label: {
            HStack {
                Text(label(for: bucket))
                Spacer()
                if selection == bucket {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.cycloPrimary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selection == bucket ? Color.cycloSecondary.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func label(for bucket: SelfReportedCycleLengthBucket) -> String {
        switch bucket {
        case .typical: return "~28 days"
        case .shorter: return "Shorter than that"
        case .longer: return "Longer than that"
        case .notSure: return "Not sure"
        }
    }
}

#Preview {
    CycleLengthBucketStepView(selection: .constant(.typical))
        .padding()
}
