//
//  IconOptionChip.swift
//  cyclo-ios
//
//  A single tappable icon+label pill used by TodayLogView's category cards. Replaces the old
//  text-only SelectableChip now that every LogCategoryOption case has an iconSystemName (see
//  LogCategoryDisplay.swift).
//

import SwiftUI
import UIKit

struct IconOptionChip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            // Same light-impact convention PeriodDayRangeCalendar uses for its day taps — fires
            // on both select and deselect, since either is "picking" a badge.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.25) : Color.cycloSecondary.opacity(0.25))
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.cycloPrimary)
                    }
                    .frame(width: 26, height: 26)
                }
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.leading, systemImage != nil ? 4 : 14)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(isSelected ? Color.cycloPrimary : Color.cycloSecondary.opacity(0.14))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
