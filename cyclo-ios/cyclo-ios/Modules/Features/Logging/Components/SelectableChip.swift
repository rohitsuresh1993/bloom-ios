//
//  SelectableChip.swift
//  cyclo-ios
//
//  A single tappable pill used by both the single- and multi-select category pickers in the
//  Logging feature. Uses the app's brand colors rather than any hardcoded hex values.
//

import SwiftUI

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.cycloPrimary : Color.cycloSecondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.cycloPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
