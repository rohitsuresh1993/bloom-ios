//
//  HomePage.swift
//  bloom-ios
//
//  Created by Rohit Suresh on 9/8/25.
//

import SwiftUI
import SwiftData
import Foundation

// Pages of the Home carousel — the cycle ring is always first; Mood/Symptoms only join once
// there's something to show, same "empty => render nothing" rule each card already followed on
// its own.
private enum HomeCarouselPage: Hashable {
    case cycle
    case mood
    case symptoms
}

struct HomePage: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tabCoordinator: AppTabCoordinator
    @StateObject private var viewModel = HomeViewModel()
    @State private var carouselScrollPosition: HomeCarouselPage?

    // Fixed so every page (the ring is the tallest) lays out consistently in the shared
    // horizontal ScrollView — shorter pages (Mood/Symptoms) are then vertically centered in it
    // rather than stretching their card to match.
    private let carouselHeight: CGFloat = 320

    private var carouselPages: [HomeCarouselPage] {
        var pages: [HomeCarouselPage] = [.cycle]
        if !viewModel.moodInsights.isEmpty { pages.append(.mood) }
        if !viewModel.symptomInsights.isEmpty { pages.append(.symptoms) }
        return pages
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TopBar()

                WeekCarouselView(weeks: viewModel.weeks, currentWeekID: viewModel.currentWeekID)

                insightsCarousel

                if let fertilityCard = viewModel.fertilityCard {
                    FertilityCardView(data: fertilityCard)
                }

                QuickLogRow(viewModel: viewModel)

                if !viewModel.todaysChips.isEmpty {
                    TodaysChipsStrip(chips: viewModel.todaysChips)
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.configure(
                cycleRepository: CycleRepository(modelContext: modelContext),
                logRepository: LogRepository(modelContext: modelContext),
                userRepository: UserRepository(modelContext: modelContext)
            )
        }
        // TabView keeps every tab alive once created, so there's no sheet-dismiss callback to
        // refresh on anymore when the Profile tab edits something Home's prediction depends on
        // (age, known conditions) — this re-runs `refresh()` whenever Home becomes the active
        // tab again instead.
        .onChange(of: tabCoordinator.selectedTab) { _, newValue in
            guard newValue == .home else { return }
            viewModel.refresh()
        }
        .sheet(item: $viewModel.activeSheet, onDismiss: viewModel.refresh) { kind in
            switch kind {
            case .period:
                LogPeriodView()
            case .today:
                TodayLogView(scrollTarget: viewModel.logScrollTarget)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in if !isPresented { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // Horizontally-paging carousel — reuses the same ScrollView+LazyHStack+paging pattern as
    // WeekCarouselView above, rather than TabView(.page), for consistency with it. Pages are
    // heterogeneous (ring vs. insight cards), so `carouselPageView(for:)` switches on
    // `HomeCarouselPage` instead of ForEach-ing over one view type directly.
    private var insightsCarousel: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(carouselPages, id: \.self) { page in
                        carouselPageView(for: page)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $carouselScrollPosition)
            .frame(height: carouselHeight)
            .onAppear {
                if carouselScrollPosition == nil {
                    carouselScrollPosition = carouselPages.first
                }
            }

            if carouselPages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(carouselPages, id: \.self) { page in
                        Circle()
                            .fill(
                                page == (carouselScrollPosition ?? carouselPages.first)
                                    ? Color.bloomPrimary
                                    : Color.bloomPrimary.opacity(0.25)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func carouselPageView(for page: HomeCarouselPage) -> some View {
        switch page {
        case .cycle:
            cycleRingSection
        case .mood:
            MoodInsightsCardView(insights: viewModel.moodInsights)
        case .symptoms:
            SymptomInsightsCardView(insights: viewModel.symptomInsights)
        }
    }

    @ViewBuilder
    private var cycleRingSection: some View {
        VStack(spacing: 12) {
            if viewModel.hasCycleData {
                CyclePhaseRingView(
                    cycleLength: viewModel.predictedCycleLength,
                    periodLengthDays: viewModel.periodArcLengthDays,
                    fertileRange: viewModel.fertileArcRange,
                    markerFraction: viewModel.ringMarkerFraction,
                    centerTitle: viewModel.ringCenterTitle,
                    centerSubtitle: viewModel.ringCenterSubtitle
                )

                VStack(spacing: 6) {
                    Text(viewModel.nextPeriodRangeText)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Text(viewModel.confidenceLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.bloomSecondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            } else {
                ColdStartRingView()
            }
        }
    }
}

// MARK: - Week strip

// Horizontally-paging carousel of weeks (8 back, 1 forward, from HomeViewModel.buildWeeks) —
// swiping goes somewhere, rather than always showing just the current calendar week.
private struct WeekCarouselView: View {
    let weeks: [HomeViewModel.WeekItem]
    let currentWeekID: HomeViewModel.WeekItem.ID?
    @State private var scrollPosition: HomeViewModel.WeekItem.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(weeks) { week in
                    WeekStripView(days: week.days)
                        .containerRelativeFrame(.horizontal)
                        .id(week.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = currentWeekID
            }
        }
        .onChange(of: currentWeekID) { _, newValue in
            if scrollPosition == nil {
                scrollPosition = newValue
            }
        }
    }
}

private struct WeekStripView: View {
    let days: [HomeViewModel.WeekDayItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    Text(day.letter)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(day.number)")
                        .font(.subheadline.weight(day.isToday ? .bold : .regular))
                    Circle()
                        .fill(day.hasPeriodFlow ? Color.bloomPrimary : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(day.isToday ? Color.bloomSecondary.opacity(0.35) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Cycle-phase ring

private struct CyclePhaseRingView: View {
    let cycleLength: Double
    let periodLengthDays: Double
    let fertileRange: HomeViewModel.DayRange?
    let markerFraction: Double
    let centerTitle: String
    let centerSubtitle: String

    private let lineWidth: CGFloat = 18
    private let diameter: CGFloat = 220

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: cycleLength > 0 ? min(periodLengthDays / cycleLength, 1) : 0)
                .stroke(Color.bloomPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let fertileRange, cycleLength > 0 {
                let startFraction = max(0, min(fertileRange.start / cycleLength, 1))
                let endFraction = max(0, min(fertileRange.end / cycleLength, 1))
                if endFraction > startFraction {
                    Circle()
                        .trim(from: startFraction, to: endFraction)
                        .stroke(Color.bloomSecondary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }

            GeometryReader { proxy in
                let radius = min(proxy.size.width, proxy.size.height) / 2
                let angle = Angle.degrees(markerFraction * 360 - 90)
                Circle()
                    .fill(Color.primary)
                    .frame(width: 10, height: 10)
                    .position(
                        x: proxy.size.width / 2 + radius * cos(angle.radians),
                        y: proxy.size.height / 2 + radius * sin(angle.radians)
                    )
            }

            VStack(spacing: 4) {
                Text(centerTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(centerSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .padding()
    }
}

private struct ColdStartRingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .frame(width: 180, height: 180)
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.secondary)
            }
            Text("No cycle data yet — log your first period to get started.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Card chrome (gradient background + icon chip, shared by all three insight cards)

// Placeholder visual tokens — flat tints of the existing bloomPrimary/bloomSecondary brand
// colors rather than a real design-system gradient/icon set, per the "placeholder tokens for
// now" direction. Swap `CardGradient`'s color pairs and `CardIconView`'s tints for real tokens
// once a proper palette exists.
// Light-mode opacities read fine against a near-white background but nearly disappear against
// dark mode's near-black background — shared by CardGradient (Fertility's rectangular card) and
// CircularInsightCardView (the Mood/Symptoms circles) so both boost consistently.
private func resolvedCardOpacity(_ lightOpacity: Double, colorScheme: ColorScheme) -> Double {
    colorScheme == .dark ? min(lightOpacity * 2.5, 0.55) : lightOpacity
}

private struct CardGradient: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    // Each stop is a base color plus the opacity it should render at in light mode.
    let stops: [(color: Color, lightOpacity: Double)]

    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: stops.map { $0.color.opacity(resolvedCardOpacity($0.lightOpacity, colorScheme: colorScheme)) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private extension View {
    func cardGradient(_ stops: [(Color, Double)]) -> some View {
        modifier(CardGradient(stops: stops.map { (color: $0.0, lightOpacity: $0.1) }))
    }
}

private struct CardIconView: View {
    enum Glyph {
        case systemImage(String)
        case emoji(String)
    }

    let glyph: Glyph
    let tint: Color
    let background: Color

    var body: some View {
        ZStack {
            Circle().fill(background)
            switch glyph {
            case .systemImage(let name):
                Image(systemName: name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            case .emoji(let value):
                Text(value)
                    .font(.system(size: 15))
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Fertility card

private struct FertilityCardView: View {
    let data: HomeViewModel.FertilityCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                CardIconView(glyph: .systemImage("drop.fill"), tint: .bloomPrimary, background: Color.bloomPrimary.opacity(0.18))
                Text("Fertility")
                    .font(.headline)
            }
            Text(data.statusSentence)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.bloomPrimary)
            Text("Fertile window: \(data.fertileWindowRangeText)")
                .font(.subheadline)
            Text("Estimated ovulation: \(data.estimatedOvulationText)")
                .font(.subheadline)
            if data.isConfirmedByTest {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.bloomSecondary)
                    Text("Confirmed by your ovulation test")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardGradient([(Color.bloomPrimary, 0.14), (Color.bloomSecondary, 0.10)])
    }
}

// MARK: - Mood / Symptoms insight circles

// Matches the cycle ring's circular shape and 220pt diameter for visual consistency within the
// carousel — both cards share this layout, only the title/icon/colors and the insights feeding
// them differ. Tapping still cycles one insight at a time, same mechanic as the old rectangular
// stacked-card version, just via a crossfade in place of peeking card edges: a stack of
// rectangular cards peeking out doesn't read well clipped to a circle.
private struct CircularInsightCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let icon: CardIconView.Glyph
    let iconTint: Color
    let iconBackground: Color
    let gradientStops: [(Color, Double)]
    let accentColor: Color
    let insights: [HomeViewModel.PatternInsight]

    @State private var frontIndex = 0

    private let diameter: CGFloat = 220

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientStops.map {
                                $0.0.opacity(resolvedCardOpacity($0.1, colorScheme: colorScheme))
                            },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        CardIconView(glyph: icon, tint: iconTint, background: iconBackground)
                        Text(title)
                            .font(.headline)
                    }

                    Text(currentInsightText)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .id(frontIndex)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .padding(.horizontal, 28)
                }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .onTapGesture {
                guard insights.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    frontIndex = (frontIndex + 1) % insights.count
                }
            }

            if insights.count > 1 {
                HStack(spacing: 4) {
                    ForEach(insights.indices, id: \.self) { index in
                        Circle()
                            .fill(index == frontIndex ? accentColor : accentColor.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
    }

    private var currentInsightText: String {
        guard insights.indices.contains(frontIndex) else { return "" }
        return insights[frontIndex].text
    }
}

private struct MoodInsightsCardView: View {
    let insights: [HomeViewModel.PatternInsight]

    // Placeholder darker-lavender icon tint — bloomSecondary itself is too pale to read as an
    // icon glyph; there's no separate design token for this yet, so this is a one-off literal
    // until a real icon-tint token exists.
    private static let iconTint = Color(red: 0.353, green: 0.388, blue: 0.769)

    var body: some View {
        CircularInsightCardView(
            title: "Mood",
            icon: .systemImage("face.smiling"),
            iconTint: Self.iconTint,
            iconBackground: Color.bloomSecondary.opacity(0.3),
            gradientStops: [(Color.bloomSecondary, 0.3), (Color.bloomSecondary, 0.1)],
            accentColor: Self.iconTint,
            insights: insights
        )
    }
}

private struct SymptomInsightsCardView: View {
    let insights: [HomeViewModel.PatternInsight]

    var body: some View {
        CircularInsightCardView(
            title: "Symptoms",
            icon: .emoji("💢"),
            iconTint: .bloomPrimary,
            iconBackground: Color.bloomPrimary.opacity(0.16),
            gradientStops: [(Color.bloomPrimary, 0.26), (Color.bloomPrimary, 0.08)],
            accentColor: .bloomPrimary,
            insights: insights
        )
    }
}

// MARK: - Quick-log row

// Just three entry points onto Home now: Period (its own calendar screen), a generic "+" that
// opens the unified TodayLogView at the top (everything else — Mood/Symptoms/Activity/etc. live
// there now, not as their own buttons), and Flow, kept as its own button since it's checked daily
// most often. Centered rather than a scrolling row, since three buttons fit without scrolling.
private struct QuickLogRow: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack(spacing: 32) {
            QuickLogButton(
                systemImage: "drop.fill",
                label: "Period",
                isLogged: viewModel.periodLoggedToday,
                tint: .bloomPrimary,
                action: viewModel.tapPeriod
            )
            QuickLogButton(
                systemImage: "plus",
                label: "Log",
                isLogged: viewModel.moreLoggedToday,
                tint: .bloomSecondary,
                action: viewModel.presentMoreSheet
            )
            QuickLogButton(
                systemImage: "chart.bar.fill",
                label: "Flow",
                isLogged: viewModel.flowLoggedToday,
                tint: .bloomSecondary,
                action: viewModel.presentFlowSheet
            )
        }
        .frame(maxWidth: .infinity)
        // The "logged today" badge sits in the top-trailing corner of each 56pt circle, offset
        // further outward — without this top padding it gets clipped by the row's natural
        // (badge-less) height.
        .padding(.top, 6)
    }
}

private struct QuickLogButton: View {
    let systemImage: String
    let label: String
    let isLogged: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: systemImage)
                                .font(.system(size: 22))
                                .foregroundStyle(tint)
                        )
                    if isLogged {
                        Circle()
                            .fill(tint)
                            .frame(width: 12, height: 12)
                            .offset(x: 2, y: -2)
                    }
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today's log chip strip

private struct TodaysChipsStrip: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bloomSecondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    HomePage()
        .environmentObject(AppTabCoordinator())
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
