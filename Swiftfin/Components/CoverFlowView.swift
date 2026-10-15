//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct CoverFlowCover: Identifiable {
    let id: AnyHashable
    let poster: AnyPoster
    let select: () -> Void
}

/// A classic Cover Flow carousel: the centered cover faces forward, with the
/// remaining covers angled and stacked on either side above a reflective floor.
///
/// A bar along the bottom shows the centered cover's title between the leading and trailing controls.
struct CoverFlowView<Leading: View, Trailing: View>: View {

    typealias Cover = CoverFlowCover

    private static var barHeight: CGFloat {
        52
    }

    /// Layout values derived from the available size
    private struct Metrics {

        static var topPadding: CGFloat {
            24
        }

        let coverSize: CGSize
        let reflectionHeight: CGFloat

        /// Distance from the centered cover to the first cover of either stack
        var centerGap: CGFloat {
            coverSize.width * 0.66
        }

        /// Distance between covers within a stack
        var stackSpacing: CGFloat {
            coverSize.width * 0.2
        }

        /// Horizontal drag distance that moves one cover
        var dragDistancePerCover: CGFloat {
            coverSize.width * 0.4
        }

        init(size: CGSize, bottomReserve: CGFloat, aspectRatio: CGFloat) {
            let availableHeight = max(size.height - Self.topPadding - bottomReserve, 0)

            // Leave a sliver of reflection above the bar, the rest fades out behind it
            var height = availableHeight / 1.08
            var width = height * aspectRatio

            // Keep wide covers from overwhelming the stacks
            let maxWidth = size.width * 0.34
            if width > maxWidth {
                width = maxWidth
                height = width / aspectRatio
            }

            self.coverSize = CGSize(width: width, height: height)
            self.reflectionHeight = height * 0.25
        }
    }

    let covers: [Cover]
    let displayType: PosterDisplayType
    let onApproachingEnd: () -> Void

    private let leading: Leading
    private let trailing: Trailing

    @Binding
    private var selectedIndex: Int

    /// The fractional index of the cover at the center, which moves continuously while dragging
    @State
    private var position: CGFloat = 0
    @State
    private var dragStartPosition: CGFloat?

    init(
        covers: [Cover],
        displayType: PosterDisplayType,
        selectedIndex: Binding<Int>,
        onApproachingEnd: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.covers = covers
        self.displayType = displayType
        self._selectedIndex = selectedIndex
        self.onApproachingEnd = onApproachingEnd
        self.leading = leading()
        self.trailing = trailing()
    }

    @Environment(\.colorScheme)
    private var colorScheme

    /// A black floor in dark mode, and a white to silver floor in light mode
    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            [.black, Color(white: 0.12), .black]
        } else {
            [.white, Color(white: 0.93), Color(white: 0.82)]
        }
    }

    /// Opaque, so stacked covers never show through each other while loading
    private var coverBackingColor: Color {
        colorScheme == .dark ? .black : Color(white: 0.85)
    }

    private var aspectRatio: CGFloat {
        switch displayType {
        case .landscape:
            1.77
        case .portrait:
            2 / 3
        case .square:
            1
        }
    }

    private var lastIndex: Int {
        max(covers.count - 1, 0)
    }

    private var centeredIndex: Int {
        clampedIndex(Int(position.rounded()))
    }

    private func clampedIndex(_ index: Int) -> Int {
        min(max(index, 0), lastIndex)
    }

    private func move(to index: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            position = CGFloat(clampedIndex(index))
        }
    }

    var body: some View {
        GeometryReader { safeAreaProxy in
            let bottomReserve = Self.barHeight + safeAreaProxy.safeAreaInsets.bottom

            // Covers use the whole screen, edge to edge
            GeometryReader { proxy in
                let metrics = Metrics(size: proxy.size, bottomReserve: bottomReserve, aspectRatio: aspectRatio)

                ZStack {
                    ForEach(visibleIndices(width: proxy.size.width, metrics: metrics), id: \.self) { index in
                        coverView(at: index, metrics: metrics)
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: metrics.coverSize.height + metrics.reflectionHeight,
                    alignment: .top
                )
                .padding(.top, Metrics.topPadding)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .contentShape(.rect)
                .gesture(dragGesture(metrics: metrics))
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .bottom) {
            bottomBar
        }
        .background {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .sensoryFeedback(.selection, trigger: centeredIndex)
        .onAppear {
            position = CGFloat(clampedIndex(selectedIndex))
        }
        .onChange(of: centeredIndex) {
            selectedIndex = centeredIndex

            if centeredIndex >= covers.count - 10 {
                onApproachingEnd()
            }
        }
        .onChange(of: covers.count) {
            // Keep the position valid when the covers change, such as from a new filter
            if position > CGFloat(lastIndex) {
                position = CGFloat(lastIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(covers.indices.contains(centeredIndex) ? covers[centeredIndex].poster.displayTitle : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                move(to: centeredIndex + 1)
            case .decrement:
                move(to: centeredIndex - 1)
            @unknown default:
                break
            }
        }
        .accessibilityAction {
            if covers.indices.contains(centeredIndex) {
                covers[centeredIndex].select()
            }
        }
    }

    // MARK: - Covers

    /// Only covers that can be on screen are built
    private func visibleIndices(width: CGFloat, metrics: Metrics) -> [Int] {
        guard covers.isNotEmpty, metrics.stackSpacing > 0 else { return [] }

        let reach = Int(((width / 2 - metrics.centerGap) / metrics.stackSpacing).rounded(.up)) + 2
        let center = clampedIndex(Int(position.rounded()))
        let lower = clampedIndex(center - reach)
        let upper = clampedIndex(center + reach)

        return Array(lower ... upper)
    }

    @ViewBuilder
    private func coverView(at index: Int, metrics: Metrics) -> some View {
        let cover = covers[index]

        // Signed distance from the center, in covers
        let offset = CGFloat(index) - position
        let progress = min(max(offset, -1), 1)

        let x = progress * metrics.centerGap + (offset - progress) * metrics.stackSpacing

        VStack(spacing: 2) {
            coverImage(cover, metrics: metrics)

            // Mirror the bottom of the cover onto the floor
            coverImage(cover, metrics: metrics)
                .scaleEffect(x: 1, y: -1)
                .frame(height: metrics.reflectionHeight, alignment: .top)
                .clipped()
                .mask {
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .rotation3DEffect(
            .degrees(-progress * 62),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.45
        )
        .scaleEffect(1 - abs(progress) * 0.12)
        // Shade covers as they turn away, more subtly on a light floor
        .brightness(-abs(progress) * (colorScheme == .dark ? 0.15 : 0.06))
        .offset(x: x)
        .zIndex(-abs(offset))
        .onTapGesture {
            if index == centeredIndex {
                cover.select()
            } else {
                move(to: index)
            }
        }
    }

    private func coverImage(_ cover: Cover, metrics: Metrics) -> some View {
        PosterImage(item: cover.poster, type: displayType, size: .medium)
            .background {
                coverBackingColor
                    .posterCornerRadius(displayType)
            }
            .frame(width: metrics.coverSize.width, height: metrics.coverSize.height)
    }

    private var bottomBar: some View {
        ZStack {
            titleView
                .padding(.horizontal, 140)

            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .frame(height: Self.barHeight)
        // Keep clear of the rounded screen corners
        .padding(.horizontal, 28)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var titleView: some View {
        if covers.indices.contains(centeredIndex) {
            let poster = covers[centeredIndex].poster

            VStack(spacing: 2) {
                Text(poster.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let subtitle = poster.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .id(centeredIndex)
            .transition(.opacity)
            .animation(.linear(duration: 0.15), value: centeredIndex)
        }
    }

    // MARK: - Dragging

    private func dragGesture(metrics: Metrics) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let start = dragStartPosition ?? position
                dragStartPosition = start

                let target = start - value.translation.width / metrics.dragDistancePerCover
                position = rubberBanded(target)
            }
            .onEnded { value in
                let start = dragStartPosition ?? position
                dragStartPosition = nil

                // Continue with the drag's momentum, then settle on a cover
                let predicted = start - value.predictedEndTranslation.width / metrics.dragDistancePerCover
                move(to: Int(predicted.rounded()))
            }
    }

    /// Resists dragging past the first and last covers
    private func rubberBanded(_ position: CGFloat) -> CGFloat {
        let upperBound = CGFloat(lastIndex)

        if position < 0 {
            return position / 3
        } else if position > upperBound {
            return upperBound + (position - upperBound) / 3
        }

        return position
    }
}

extension View {

    /// The background for controls floating over Cover Flow
    @ViewBuilder
    func coverFlowControlBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.ultraThinMaterial, in: .capsule)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    @Previewable @State
    var selectedIndex = 3

    CoverFlowView(
        covers: Array(1 ... 20).map { (index: Int) in
            CoverFlowCover(
                id: AnyHashable(index),
                poster: AnyPoster(BaseItemPerson(id: "\(index)", name: "Cover \(index)"))
            ) {}
        },
        displayType: .portrait,
        selectedIndex: $selectedIndex
    ) {} leading: {
        Image(systemName: "film")
            .font(.title3)
            .frame(width: 44, height: 44)
            .coverFlowControlBackground()
    } trailing: {
        Image(systemName: "ellipsis")
            .font(.title3)
            .frame(width: 44, height: 44)
            .coverFlowControlBackground()
    }
}
