//
//  LogCategoryKind.swift
//  bloom-ios
//
//  One case per category card on TodayLogView. Used both to scroll the unified log screen to a
//  specific card when opened from one of Home's quick-log buttons (HomeViewModel.logScrollTarget)
//  and as each card's `.id(_:)` for that scroll. `.sexAndSexDrive` covers two Log properties
//  (sexualActivity, sexDrive) because they render as one combined card, matching the reference
//  design's "Sex and sex drive" card.
//
enum LogCategoryKind: Hashable {
    case mood
    case symptoms
    case physicalActivity
    case flowIntensity
    case sexAndSexDrive
    case vaginalDischarge
    case ovulationTestResult
    case pregnancyTest
    case oralContraceptiveStatus
    case digestionAndStool
    case other
}
