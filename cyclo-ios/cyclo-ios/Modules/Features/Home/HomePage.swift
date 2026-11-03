//
//  HomePage.swift
//  cyclo-ios
//
//  Created by Rohit Suresh on 9/8/25.
//

import SwiftUI
import SwiftData
import Foundation

struct HomePage: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TopBar()

                WeekStripView(days: viewModel.weekDays)

                cycleRingSection

                if let fertilityCard = viewModel.fertilityCard {
                    FertilityCardView(data: fertilityCard)
                }

                if !viewModel.patternInsights.isEmpty {
                    PatternsCardView(insights: viewModel.patternInsights)
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
        .sheet(item: $viewModel.activeSheet, onDismiss: viewModel.refresh) { kind in
            switch kind {
            case .period:
                LogPeriodView()
            case .day:
                LogDayView()
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
                        .background(Color.cycloSecondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            } else {
                ColdStartRingView()
            }
        }
    }
}

// MARK: - Week strip

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
                        .fill(day.hasPeriodFlow ? Color.cycloPrimary : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(day.isToday ? Color.cycloSecondary.opacity(0.35) : Color.clear)
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
                .stroke(Color.cycloPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let fertileRange, cycleLength > 0 {
                let startFraction = max(0, min(fertileRange.start / cycleLength, 1))
                let endFraction = max(0, min(fertileRange.end / cycleLength, 1))
                if endFraction > startFraction {
                    Circle()
                        .trim(from: startFraction, to: endFraction)
                        .stroke(Color.cycloSecondary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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

// MARK: - Fertility card

private struct FertilityCardView: View {
    let data: HomeViewModel.FertilityCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fertility")
                .font(.headline)
            Text("Fertile window: \(data.fertileWindowRangeText)")
                .font(.subheadline)
            Text("Estimated ovulation: \(data.estimatedOvulationText)")
                .font(.subheadline)
            Text(data.statusSentence)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cycloPrimary)
            if data.isConfirmedByTest {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.cycloSecondary)
                    Text("Confirmed by your ovulation test")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycloSecondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Patterns card

private struct PatternsCardView: View {
    let insights: [HomeViewModel.PatternInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you might notice today")
                .font(.headline)
            ForEach(insights) { insight in
                Text(insight.text)
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycloPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Quick-log row

private struct QuickLogRow: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack(spacing: 28) {
            QuickLogButton(
                systemImage: "drop.fill",
                label: "Period",
                isLogged: viewModel.periodLoggedToday,
                tint: .cycloPrimary,
                action: viewModel.tapPeriod
            )
            QuickLogButton(
                systemImage: "note.text",
                label: "Symptoms",
                isLogged: viewModel.symptomsLoggedToday,
                tint: .cycloSecondary,
                action: viewModel.presentSymptomsSheet
            )
            QuickLogButton(
                systemImage: "face.smiling",
                label: "Mood",
                isLogged: viewModel.moodLoggedToday,
                tint: .cycloSecondary,
                action: viewModel.presentMoodSheet
            )
            QuickLogButton(
                systemImage: "figure.walk",
                label: "Activity",
                isLogged: viewModel.activityLoggedToday,
                tint: .cycloSecondary,
                action: viewModel.presentActivitySheet
            )
        }
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
                        .background(Color.cycloSecondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    HomePage()
}
