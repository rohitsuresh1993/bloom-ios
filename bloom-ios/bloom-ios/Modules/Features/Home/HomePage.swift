//
//  HomePage.swift
//  bloom-ios
//
//  Created by Rohit Suresh on 9/8/25.
//

import SwiftUI
import SwiftData
import Foundation

struct HomePage: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tabCoordinator: AppTabCoordinator
    @EnvironmentObject private var tourCoordinator: TourCoordinator
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 24) {
                    TopBar()

                    WeekCarouselView(weeks: viewModel.weeks, currentWeekID: viewModel.currentWeekID)
                        .tourAnchor(.weekStrip)
                        .id(TourStep.weekStrip)

                    cycleRingSection
                        .tourAnchor(.cycleRing)
                        .id(TourStep.cycleRing)

                    QuickLogRow(viewModel: viewModel)
                        .tourAnchor(.quickLogRow)
                        .id(TourStep.quickLogRow)

                    insightsSection
                        .tourAnchor(.insightsDeck)
                        .id(TourStep.insightsDeck)

                    if let fertilityCard = viewModel.fertilityCard {
                        FertilityCardView(data: fertilityCard)
                            .tourAnchor(.fertilityCard)
                            .id(TourStep.fertilityCard)
                    } else if tourCoordinator.currentStep == .fertilityCard {
                        // A brand-new user has no real fertility window yet (needs ≥3 observed
                        // cycles) — show a staged example rather than skipping the step outright,
                        // so the tour can still explain what this card is for.
                        FertilityCardView(data: Self.stagedFertilityCard)
                            .tourAnchor(.fertilityCard)
                            .id(TourStep.fertilityCard)
                    }
                }
                .padding()
            }
            // Brings whichever step is currently spotlighted into view — without this, a target
            // further down the page (the fertility card, say) could be scrolled out of frame
            // entirely while its cutout tries to point at it.
            .onChange(of: tourCoordinator.currentStep) { _, step in
                guard let step, step.requiredTab == .home else { return }
                withAnimation {
                    scrollProxy.scrollTo(step, anchor: .center)
                }
            }
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
        // Drives the two sheet-hosted tour steps. fertilityCard/insightsDeck/cycleRing don't need
        // handling here — the body above shows a staged preview for each one when the real data
        // isn't there yet, instead of skipping the step.
        .onChange(of: tourCoordinator.currentStep) { _, step in
            switch step {
            case .todayLog:
                viewModel.presentMoreSheet()
            case .logPeriod:
                viewModel.tapPeriod()
            default:
                break
            }
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

    // Staged examples the tour shows in place of real data for a brand-new user who hasn't
    // logged enough yet to have any of it — illustrative only, never written anywhere. Each one
    // mirrors the exact view the real data would otherwise render, just with made-up numbers.
    private static let stagedFertilityCard = HomeViewModel.FertilityCardData(
        fertileWindowRangeText: "Jun 12 – 17",
        estimatedOvulationText: "Jun 15",
        statusSentence: "High — you're in your fertile window",
        isConfirmedByTest: false
    )
    private static let stagedMoodInsights: [HomeViewModel.PatternInsight] = [
        HomeViewModel.PatternInsight(
            shortLabel: "Calm", icon: "leaf.fill", verbPhrase: "feel calm",
            text: "Common during this phase.", source: .population
        ),
        HomeViewModel.PatternInsight(
            shortLabel: "Irritated", icon: "exclamationmark.triangle.fill", verbPhrase: "feel irritated",
            text: "Common during this phase.", source: .population
        )
    ]
    private static let stagedSymptomInsights: [HomeViewModel.PatternInsight] = [
        HomeViewModel.PatternInsight(
            shortLabel: "Cramps", icon: "bolt.heart.fill", verbPhrase: "feel some cramps",
            text: "Common during this phase.", source: .population
        ),
        HomeViewModel.PatternInsight(
            shortLabel: "Fatigue", icon: "zzz", verbPhrase: "feel fatigued",
            text: "Common during this phase.", source: .population
        )
    ]

    @ViewBuilder
    private var insightsSection: some View {
        if viewModel.moodInsights.isEmpty && viewModel.symptomInsights.isEmpty {
            PredictedInsightsSection(
                moodInsights: Self.stagedMoodInsights,
                symptomInsights: Self.stagedSymptomInsights
            )
        } else {
            PredictedInsightsSection(
                moodInsights: viewModel.moodInsights,
                symptomInsights: viewModel.symptomInsights
            )
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
            } else if tourCoordinator.currentStep == .cycleRing {
                // No period logged at all yet (hasCycleData false) — show a staged ring rather
                // than the "log your first period" placeholder, so the tour can still explain
                // what this ring means once it's populated.
                CyclePhaseRingView(
                    cycleLength: 28,
                    periodLengthDays: 5,
                    fertileRange: HomeViewModel.DayRange(start: 11, end: 16),
                    markerFraction: 0.5,
                    centerTitle: "Day 14",
                    centerSubtitle: "OVULATION"
                )

                VStack(spacing: 6) {
                    Text("Next period: around Jun 24 – 28")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Text("High confidence")
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
        // Double-tap anywhere on the strip jumps back to today's week — a quick way back after
        // swiping off into past/future weeks, without needing a separate "Today" button.
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollPosition = currentWeekID
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

// MARK: - Card chrome (gradient background + icon chip, used by the Fertility card)

// Placeholder visual tokens — flat tints of the existing bloomPrimary/bloomSecondary brand
// colors rather than a real design-system gradient/icon set, per the "placeholder tokens for
// now" direction. Swap `CardGradient`'s color pairs and `CardIconView`'s tints for real tokens
// once a proper palette exists.
// Light-mode opacities read fine against a near-white background but nearly disappear against
// dark mode's near-black background — this boosts dark mode's opacity to compensate.
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
    let systemImage: String
    let tint: Color
    let background: Color

    var body: some View {
        ZStack {
            Circle().fill(background)
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
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
                CardIconView(systemImage: "drop.fill", tint: .bloomPrimary, background: Color.bloomPrimary.opacity(0.18))
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

// MARK: - Predicted mood/symptom badges

// Replaces the old swipe-carousel-of-tap-to-cycle-circles: every predicted mood and symptom is
// shown at once as a short badge, wrapping via FlowLayout (same wrap mechanic the Logging
// feature's chip pickers already use) rather than hiding insights one at a time behind a tap or
// a swipe. Capped at `collapsedLimit` with a "+N more" badge for overflow, so a phase with many
// confident predictions still can't push the quick-log row below the fold by default — expanding
// is an explicit tap, not something that happens just by having more data.
private struct PredictedInsightsSection: View {
    let moodInsights: [HomeViewModel.PatternInsight]
    let symptomInsights: [HomeViewModel.PatternInsight]

    // Index (into `entries`) of whichever insight is currently on top of the stack.
    @State private var topIndex = 0
    // Live drag feedback for the front card only — back cards stay put until the drag commits.
    @State private var dragTranslation: CGFloat = 0

    // Matches MoodInsightsCardView's old placeholder tint — bloomSecondary itself is too pale to
    // read as icon/text color.
    private static let moodTint = Color(red: 0.353, green: 0.388, blue: 0.769)
    private static let cardHeight: CGFloat = 92
    // How far each card above/below the front one peeks out.
    private static let peekOffset: CGFloat = 8
    // Rolodex look: a sliver above the current card as well as below it, not just below.
    private static let aboveDepth = 1
    private static let belowDepth = 2
    private static let advanceThreshold: CGFloat = 50
    // Room reserved around the stack purely for the front card's shadow to blur into — without
    // this, clipping the stack to exactly its content height sliced the shadow off in a flat
    // line instead of letting it fade out following the card's rounded shape.
    private static let shadowMargin: CGFloat = 14
    // How far a drag can move the front card — small enough to stay inside shadowMargin at all
    // times, so the safety clip below never actually has to cut into normal interaction.
    private static let maxDragTravel: CGFloat = 16

    private struct Entry: Identifiable {
        let insight: HomeViewModel.PatternInsight
        let isMood: Bool
        var id: UUID { insight.id }
    }

    private var entries: [Entry] {
        moodInsights.map { Entry(insight: $0, isMood: true) }
            + symptomInsights.map { Entry(insight: $0, isMood: false) }
    }

    var body: some View {
        let allEntries = entries
        if !allEntries.isEmpty {
            let count = allEntries.count
            // Capped so a short deck never renders the same entry twice in two different slots.
            let above = min(Self.aboveDepth, count - 1)
            let below = min(Self.belowDepth, max(count - 1 - above, 0))

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Insights")
                    .font(.headline)

                ZStack {
                    // Furthest-from-front slivers added first so nearer ones (and finally the
                    // front card) render on top, without needing an explicit zIndex.
                    ForEach(Array(stride(from: below, through: 1, by: -1)), id: \.self) { offset in
                        stackSliver(allEntries, relativeOffset: offset)
                    }
                    ForEach(Array(stride(from: -above, through: -1, by: 1)), id: \.self) { offset in
                        stackSliver(allEntries, relativeOffset: offset)
                    }
                    frontCard(allEntries)
                }
                .frame(height: Self.cardHeight + CGFloat(above + below) * Self.peekOffset + Self.shadowMargin * 2)
                // shadowMargin only widened the *frame*, not the clip boundary itself —
                // .clipped() clips flush to the frame on every edge, including left/right, where
                // there was never any margin at all, which is what sliced the shadow into a flat
                // vertical line there. Padding out before clipping, then pulling the same amount
                // back with negative padding, gives the clip room on all four sides without
                // changing this section's actual width among its siblings (quick-log row,
                // fertility card, etc).
                .padding(.horizontal, Self.shadowMargin)
                .clipped()
                .padding(.horizontal, -Self.shadowMargin)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard count > 1 else { return }
                            dragTranslation = max(-Self.maxDragTravel, min(Self.maxDragTravel, value.translation.height))
                        }
                        .onEnded { value in
                            guard count > 1 else { return }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                // Rolodex: either swipe direction sends the current card to the
                                // back of the deck — there's no separate "go back" direction,
                                // since both the above and below slivers are just neighbors in
                                // the same loop.
                                if abs(value.translation.height) > Self.advanceThreshold {
                                    topIndex = (topIndex + 1) % count
                                }
                                dragTranslation = 0
                            }
                        }
                )
                .onTapGesture {
                    guard count > 1 else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        topIndex = (topIndex + 1) % count
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stackSliver(_ allEntries: [Entry], relativeOffset: Int) -> some View {
        let count = allEntries.count
        let index = ((topIndex + relativeOffset) % count + count) % count
        let entry = allEntries[index]
        let background = entry.isMood ? Color.bloomSecondary.opacity(0.18) : Color.bloomPrimary.opacity(0.1)
        let depthFromFront = abs(relativeOffset)

        // Plain color slivers, not full cards with their own text — the peek gap is too thin for
        // a second independent text block to ever sit there legibly next to the front card's.
        RoundedRectangle(cornerRadius: 14)
            .opaqueTint(background)
            .frame(height: Self.cardHeight)
            .scaleEffect(1 - CGFloat(depthFromFront) * 0.04)
            .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
            .offset(y: CGFloat(relativeOffset) * Self.peekOffset)
            .allowsHitTesting(false)
    }

    private func frontCard(_ allEntries: [Entry]) -> some View {
        let entry = allEntries[topIndex]
        let tint = entry.isMood ? Self.moodTint : Color.bloomPrimary
        let background = entry.isMood ? Color.bloomSecondary.opacity(0.18) : Color.bloomPrimary.opacity(0.1)

        return PredictedInsightCard(
            icon: entry.insight.icon,
            title: "You may \(entry.insight.verbPhrase)",
            detail: entry.insight.text,
            tint: tint,
            background: background
        )
        .frame(height: Self.cardHeight)
        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
        .offset(y: dragTranslation)
        // Without a distinct id, advancing topIndex just updates this same view slot's
        // properties in place — so only the text/icon appeared to change while the card "shell"
        // stayed static the whole time. Keying on the insight's own id makes each one a genuinely
        // different view, so SwiftUI actually removes the old card and inserts the new one.
        .id(entry.id)
        // A directional .move() transition travels the full stack-container height, which here
        // is barely taller than the card itself — not enough room for a slide to read as
        // deliberate before it collides with the quick-log row right above. A scale+opacity
        // crossfade stays in place instead of traveling anywhere, so it can't collide with
        // anything outside the card's own bounds.
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }
}

// One page of the vertical-paging carousel above — icon chip leading, title + hedged detail
// text filling the rest. No dismiss affordance: every insight stays swipeable-to any time, so
// there's nothing to re-surface later and no hidden state to track.
private struct PredictedInsightCard: View {
    let icon: String?
    let title: String
    let detail: String
    let tint: Color
    let background: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.18))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        // Different SF Symbols have different intrinsic shapes — without a
                        // distinct id, SwiftUI tries to geometrically morph the old icon into
                        // the new one when the front card changes, which is what let it
                        // overflow the circle mid-animation instead of just cross-fading.
                        .id(icon)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        // Order matters: the tint goes behind the content, and the opaque system background
        // goes behind *that* — so the bottommost layer is opaque, with the translucent tint
        // layered on top of it rather than on top of whatever's behind this card in the stack.
        .background(background)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private extension Shape {
    // `background` colors here are a translucent tint (e.g. Color.bloomPrimary.opacity(0.1)),
    // which if composited directly onto whatever sits behind it in the stack lets the entire
    // stack show through everywhere, not just at the peeking edge. Filling an opaque system
    // background first, then the tint on top of that, keeps the tint's soft look while making
    // the shape itself fully occlude anything behind it.
    func opaqueTint(_ tint: Color) -> some View {
        ZStack {
            self.fill(Color(.systemBackground))
            self.fill(tint)
        }
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

#Preview {
    HomePage()
        .environmentObject(AppTabCoordinator())
        .environmentObject(TourCoordinator())
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
