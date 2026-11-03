//
//  ChipSelectionSections.swift
//  cyclo-ios
//
//  Generic Form sections for the two picker shapes the Logging screens need:
//  - SingleSelectChipSection: exactly-zero-or-one selection (nil = not logged), used for
//    `Log`'s single-valued categories (sexDrive, vaginalDischarge, ovulationTestResult,
//    pregnancyTest, oralContraceptiveStatus, flowIntensity). Tapping the already-selected
//    chip deselects it back to nil, so "none selected" is always reachable.
//  - MultiSelectChipSection: any number of selections (nil on the model = not logged, an
//    empty array is treated the same by the call sites), used for `Log`'s array-valued
//    categories (mood, symptoms, sexualActivity, physicalActivity, digestionAndStool, other).
//
//  Both rely on `LogCategoryOption`, which the Logging feature retroactively conforms each
//  `LogCategories` enum to (see LogCategoryDisplay.swift) without modifying those model files.
//

import SwiftUI

/// A `Log` category enum, as displayed by the Logging feature's chip pickers.
protocol LogCategoryOption: Hashable {
    static var allOptions: [Self] { get }
    var displayName: String { get }
}

struct SingleSelectChipSection<Option: LogCategoryOption>: View {
    let title: String
    @Binding var selection: Option?

    var body: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(Option.allOptions, id: \.self) { option in
                    SelectableChip(
                        title: option.displayName,
                        isSelected: selection == option,
                        action: {
                            selection = (selection == option) ? nil : option
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(title)
        }
    }
}

struct MultiSelectChipSection<Option: LogCategoryOption>: View {
    let title: String
    @Binding var selection: [Option]

    var body: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(Option.allOptions, id: \.self) { option in
                    SelectableChip(
                        title: option.displayName,
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
            .padding(.vertical, 4)
        } header: {
            Text(title)
        }
    }
}
