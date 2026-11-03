//
//  CategoryOptionSections.swift
//  cyclo-ios
//
//  Row-based counterparts to ChipSelectionSections.swift's SingleSelectChipSection/
//  MultiSelectChipSection — each option is its own List row (SelectableOptionRow) instead of a
//  chip in a flow layout, per the single-category Logging screens' design (CategoryLogViews.swift).
//

import SwiftUI

struct SingleSelectOptionSection<Option: LogCategoryOption>: View {
    @Binding var selection: Option?

    var body: some View {
        Section {
            ForEach(Option.allOptions, id: \.self) { option in
                SelectableOptionRow(
                    title: option.displayName,
                    systemImage: option.iconSystemName,
                    isSelected: selection == option,
                    action: {
                        selection = (selection == option) ? nil : option
                    }
                )
            }
        }
    }
}

struct MultiSelectOptionSection<Option: LogCategoryOption>: View {
    @Binding var selection: [Option]

    var body: some View {
        Section {
            ForEach(Option.allOptions, id: \.self) { option in
                SelectableOptionRow(
                    title: option.displayName,
                    systemImage: option.iconSystemName,
                    isSelected: selection.contains(option),
                    action: {
                        if let index = selection.firstIndex(of: option) {
                            selection.remove(at: index)
                        } else {
                            selection.append(option)
                        }
                    }
                )
            }
        }
    }
}
