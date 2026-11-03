import SwiftUI

// Step 4: self-reported conditions, multi-select, never inferred or detected from logged data —
// see ARCHITECTURE.md's "Onboarding conditions list" and MenstrualCondition's own doc comment.
// This list is kept local to this view (rather than `MenstrualCondition.allCases`) since the
// model enum doesn't declare `CaseIterable` and this feature shouldn't be the one to add it.
struct KnownConditionsStepView: View {
    @Binding var selection: Set<MenstrualCondition>

    private let allConditions: [MenstrualCondition] = [
        .pcos, .endometriosis, .thyroidDisorder, .uterineFibroids,
        .perimenopause, .onHormonalContraception, .other, .preferNotToSay
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Any of these apply to you?")
                .font(.title2.bold())

            Text("This is just what you tell us — we never diagnose or detect conditions from your logs. Select any that apply, or none.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(allConditions, id: \.self) { condition in
                        optionRow(for: condition)
                    }
                }
            }
        }
    }

    // `.other` ("Other / none of these") and `.preferNotToSay` are catch-all, mutually-exclusive
    // answers — selecting one clears every other selection (including the other catch-all),
    // and selecting any specific condition clears whichever catch-all was selected. Without this,
    // a user could end up with "Thyroid disorder" and "Prefer not to say" both checked at once,
    // which doesn't mean anything.
    private static let exclusiveConditions: Set<MenstrualCondition> = [.other, .preferNotToSay]

    private func toggle(_ condition: MenstrualCondition) {
        if selection.contains(condition) {
            selection.remove(condition)
        } else if Self.exclusiveConditions.contains(condition) {
            selection = [condition]
        } else {
            selection.subtract(Self.exclusiveConditions)
            selection.insert(condition)
        }
    }

    private func optionRow(for condition: MenstrualCondition) -> some View {
        let isSelected = selection.contains(condition)

        return Button {
            toggle(condition)
        } label: {
            HStack {
                Text(label(for: condition))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.cycloPrimary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cycloSecondary.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.3))
            )
            // Without this, an unselected row's Color.clear background doesn't participate in
            // hit-testing — only the opaque Text/Image glyphs do, so taps only register right on
            // the label text instead of anywhere in the row.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func label(for condition: MenstrualCondition) -> String {
        switch condition {
        case .pcos: return "PCOS"
        case .endometriosis: return "Endometriosis"
        case .thyroidDisorder: return "Thyroid disorder"
        case .uterineFibroids: return "Uterine fibroids"
        case .perimenopause: return "Perimenopause"
        case .onHormonalContraception: return "Currently on hormonal contraception"
        case .other: return "Other / none of these"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

#Preview {
    KnownConditionsStepView(selection: .constant([]))
        .padding()
}
