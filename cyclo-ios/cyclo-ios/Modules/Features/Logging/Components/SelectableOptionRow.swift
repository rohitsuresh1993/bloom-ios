//
//  SelectableOptionRow.swift
//  cyclo-ios
//
//  A single tappable List row used by the per-category Logging screens (CategoryOptionSections,
//  CategoryLogViews) — each option gets its own full-width row with a leading icon slot and a
//  trailing checkmark when selected, rather than the chip/pill layout ChipSelectionSections
//  uses. `systemImage` is nil until each LogCategoryOption case is given a real icon.
//

import SwiftUI

struct SelectableOptionRow: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.cycloPrimary)
                        .frame(width: 24)
                }
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.cycloPrimary)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
