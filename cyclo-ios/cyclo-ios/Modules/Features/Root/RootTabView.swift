//
//  RootTabView.swift
//  cyclo-ios
//
//  The app's real root once onboarding is done (see CycloApp.RootRouterView) — a plain system
//  TabView, deliberately not restyled, so it automatically renders in whatever material the
//  current OS gives a tab bar (Liquid Glass on iOS 26, the standard blur before that) rather than
//  Cyclo locking in one hand-picked look. Replaces the old TopBar profile/settings buttons and
//  the Profile/Settings sheets they opened — both are just tabs now.
//
//  Root entry point: present `RootTabView()` once onboarding has completed.
//

import SwiftUI

struct RootTabView: View {
    @StateObject private var tabCoordinator = AppTabCoordinator()

    var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            HomePage()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            CalendarPage()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)

            ProfilePage()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .tint(Color.cycloPrimary)
        .environmentObject(tabCoordinator)
    }
}

#Preview {
    RootTabView()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
