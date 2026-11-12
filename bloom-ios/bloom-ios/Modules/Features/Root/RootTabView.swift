//
//  RootTabView.swift
//  bloom-ios
//
//  The app's real root once onboarding is done (see BloomApp.RootRouterView) — a plain system
//  TabView, deliberately not restyled, so it automatically renders in whatever material the
//  current OS gives a tab bar (Liquid Glass on iOS 26, the standard blur before that) rather than
//  Bloom locking in one hand-picked look. Replaces the old TopBar profile/settings buttons and
//  the Profile/Settings sheets they opened — both are just tabs now.
//
//  Root entry point: present `RootTabView()` once onboarding has completed.
//

import SwiftUI

struct RootTabView: View {
    @StateObject private var tabCoordinator = AppTabCoordinator()
    @StateObject private var tourCoordinator = TourCoordinator()

    var body: some View {
        // Wraps the whole TabView so this GeometryReader is a genuine ancestor of every tour
        // target tagged inside Home/Calendar/Profile — required for `proxy[anchor]` to resolve
        // correctly (see TourOverlayView's doc comment). The overlay is a ZStack sibling *inside*
        // this same GeometryReader, not a `.overlay()` attached from outside it.
        GeometryReader { proxy in
            ZStack {
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
                .tint(Color.bloomPrimary)

                TourOverlayView(
                    allowedSteps: [
                        .cycleRing, .weekStrip, .quickLogRow, .insightsDeck,
                        .fertilityCard, .calendarDay, .profileEdit
                    ],
                    cutoutRect: tourCoordinator.resolvedCutoutRect(in: proxy),
                    containerSize: proxy.size,
                    onNext: tourCoordinator.advance,
                    onSkip: tourCoordinator.skip
                )
            }
        }
        // Must match the scrim's own .ignoresSafeArea() inside TourOverlayView — otherwise this
        // GeometryReader resolves anchors in safe-area-relative coordinates while the full-bleed
        // scrim renders in true-screen coordinates, and the cutout ends up offset from whatever
        // it's supposed to be spotlighting by roughly the status-bar/notch height.
        .ignoresSafeArea()
        .environmentObject(tabCoordinator)
        .environmentObject(tourCoordinator)
        // Collects anchors reported by any tour target currently mounted under this TabView
        // (Home/Calendar/Profile) — the two sheet-hosted steps (todayLog/logPeriod) report to
        // their own separate collection point inside LogPeriodView/TodayLogView instead, since a
        // `.sheet()`'s content is a different view tree for preference-propagation purposes.
        .onPreferenceChange(TourAnchorPreferenceKey.self) { newAnchors in
            tourCoordinator.anchors.merge(newAnchors) { _, new in new }
        }
        // TabView only creates a tab's content the first time it's selected, so the tour must
        // actively switch tabs to reach steps 7/8 (Calendar/Profile) — otherwise their anchors
        // would never be reported for a brand-new user who hasn't visited those tabs yet.
        .onChange(of: tourCoordinator.currentStep) { _, step in
            guard let step else { return }
            tabCoordinator.selectedTab = step.requiredTab
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: TourCoordinator.tourCompletedDefaultsKey) {
                tourCoordinator.start()
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
