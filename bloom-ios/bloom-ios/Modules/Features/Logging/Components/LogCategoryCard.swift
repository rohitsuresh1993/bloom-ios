//
//  LogCategoryCard.swift
//  bloom-ios
//
//  White rounded card with a title, used by every category section on TodayLogView — the page
//  itself sits on a light gray grouped background, matching the reference design's stacked-card
//  look (as opposed to the old per-category screens' plain Form/List rows).
//

import SwiftUI

/// A `Log` category enum, as displayed by the Logging feature's pickers. Each `LogCategories`
/// enum (Modules/Core/Models/LogCategories/*) is retroactively conformed to this in
/// LogCategoryDisplay.swift, without modifying those model files.
protocol LogCategoryOption: Hashable {
    static var allOptions: [Self] { get }
    var displayName: String { get }
    var iconSystemName: String? { get }
}

extension LogCategoryOption {
    var iconSystemName: String? { nil }
}

struct LogCategoryCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Selection flows

// Non-Form counterparts to the old ChipSelectionSections' Section-based pickers — TodayLogView
// renders cards directly in a ScrollView, not a Form, so these just produce a FlowLayout of
// IconOptionChip, filtered by `query` (TodayLogView's search field). `onChange` is called after
// every toggle so the caller can autosave immediately, matching this app's "every control
// applies immediately" Settings convention rather than a separate Save step.
struct MultiSelectChipFlow<Option: LogCategoryOption>: View {
    let query: String
    @Binding var selection: [Option]
    let onChange: () -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Self.filteredOptions(query: query), id: \.self) { option in
                IconOptionChip(
                    title: option.displayName,
                    systemImage: option.iconSystemName,
                    isSelected: selection.contains(option),
                    action: {
                        if let index = selection.firstIndex(of: option) {
                            selection.remove(at: index)
                        } else {
                            selection.append(option)
                        }
                        onChange()
                    }
                )
            }
        }
    }

    static func filteredOptions(query: String) -> [Option] {
        guard !query.isEmpty else { return Option.allOptions }
        return Option.allOptions.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    static func matchesQuery(_ query: String) -> Bool { !filteredOptions(query: query).isEmpty }
}

struct SingleSelectChipFlow<Option: LogCategoryOption>: View {
    let query: String
    @Binding var selection: Option?
    let onChange: () -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Self.filteredOptions(query: query), id: \.self) { option in
                IconOptionChip(
                    title: option.displayName,
                    systemImage: option.iconSystemName,
                    isSelected: selection == option,
                    action: {
                        selection = (selection == option) ? nil : option
                        onChange()
                    }
                )
            }
        }
    }

    static func filteredOptions(query: String) -> [Option] {
        guard !query.isEmpty else { return Option.allOptions }
        return Option.allOptions.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    static func matchesQuery(_ query: String) -> Bool { !filteredOptions(query: query).isEmpty }
}
