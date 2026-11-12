import SwiftUI

// Shared spotlight overlay — mounted at three separate places (RootTabView, LogPeriodView,
// TodayLogView), each passing the subset of steps it's responsible for. Renders nothing unless
// the coordinator's current step is in that subset *and* a resolved cutout rect was passed in.
//
// Deliberately takes an already-resolved `cutoutRect: CGRect?` rather than resolving an
// `Anchor<CGRect>` itself via its own internal GeometryReader: an Anchor can only be resolved
// against a GeometryReader that is a genuine ancestor, in the live view tree, of wherever the
// anchor was captured. Mounting this view via `.overlay(...)` makes it a *sibling* of the tab/
// sheet content it's spotlighting, not an ancestor — resolving against its own GeometryReader in
// that position crashes SwiftUI's AttributeGraph. Each mount point instead wraps its real content
// in its own top-level GeometryReader, resolves the rect there (where that GeometryReader *is* a
// genuine ancestor of the tagged views), and passes the plain CGRect down to this view.
struct TourOverlayView: View {
    @EnvironmentObject private var tourCoordinator: TourCoordinator

    let allowedSteps: Set<TourStep>
    let cutoutRect: CGRect?
    let containerSize: CGSize
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        if let step = tourCoordinator.currentStep, allowedSteps.contains(step), let rect = cutoutRect {
            ZStack {
                scrim(cutout: rect)
                    .ignoresSafeArea()
                tooltip(for: step, near: rect, in: containerSize)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: step)
        }
    }

    private func scrim(cutout rect: CGRect) -> some View {
        Color.black.opacity(0.55)
            .reverseMask {
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: rect.width + 16, height: rect.height + 16)
                    .position(x: rect.midX, y: rect.midY)
            }
    }

    private func tooltip(for step: TourStep, near rect: CGRect, in size: CGSize) -> some View {
        // Puts the card on whichever side of the cutout has more room, so it never has to
        // overlap the thing it's describing.
        let showBelow = rect.midY < size.height * 0.6

        return VStack(alignment: .leading, spacing: 12) {
            Text(step.title)
                .font(.headline)
            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button("Skip", action: onSkip)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(step == TourStep.allCases.last ? "Done" : "Next", action: onNext)
                    .fontWeight(.semibold)
                    .tint(Color.bloomPrimary)
            }
        }
        .padding(16)
        .frame(width: min(size.width - 48, 320), alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .position(
            x: size.width / 2,
            y: showBelow
                ? min(rect.maxY + 110, size.height - 90)
                : max(rect.minY - 110, 90)
        )
    }
}

private extension View {
    // Standard SwiftUI "punch a hole" technique: an opaque rectangle with the cutout shape
    // layered on top via `.destinationOut`, composited as one group so the blend mode only
    // affects this mask rather than whatever's behind the view being masked.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask().blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
