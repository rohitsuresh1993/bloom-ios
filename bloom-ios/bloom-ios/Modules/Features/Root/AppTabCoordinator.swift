//
//  AppTabCoordinator.swift
//  bloom-ios
//
//  Shared across RootTabView's three tabs via @EnvironmentObject, mainly so a tab whose data can
//  go stale from editing in another tab (Home's prediction depends on Profile's age/conditions;
//  Calendar's history depends on logs made from Home) can refresh itself when the user switches
//  back to it. TabView keeps every tab's view alive once created, so there's no dismiss-callback
//  to hook into the way the old Profile/Settings sheets had — this replaces that.
//

import SwiftUI

enum AppTab {
    case home
    case calendar
    case profile
}

@MainActor
final class AppTabCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .home
}
