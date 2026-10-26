//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

enum ThemedQuickLoadPhase: Equatable {

    case loading
    case revealing
    case loaded
}

extension EnvironmentValues {

    @Entry
    var themedQuickLoadPhase: ThemedQuickLoadPhase = .loaded
}

extension AppTheme {

    var supportsQuickLoad: Bool {
        isThemed
    }

    fileprivate var quickLoadSkeletonFade: (start: Double, duration: Double) {
        switch self {
        case .y2k:
            (0.36, 0.36)
        case .gameUI2:
            (0.54, 0.3)
        default:
            (0.36, 0.42)
        }
    }

    fileprivate var quickLoadRevealDuration: Double {
        switch self {
        case .default:
            0
        case .skeuo, .y2k:
            2.04
        case .gameUI2:
            2.22
        }
    }

    fileprivate var quickLoadEntranceStart: Double {
        switch self {
        case .gameUI2:
            0.6
        default:
            0.42
        }
    }

    fileprivate var quickLoadHeroZoom: (scale: CGFloat, start: Double, duration: Double) {
        switch self {
        case .default:
            (1, 0, 0)
        case .skeuo:
            (1.16, 0.36, 1.56)
        case .y2k:
            (1.18, 0.36, 1.68)
        case .gameUI2:
            (1.18, 0.54, 1.68)
        }
    }
}

enum ThemedQuickLoadStagger {

    static let actionRow: (compact: Double, regular: Double) = (0, 0.35)
    static let badges: (compact: Double, regular: Double) = (0.07, 0.38)
    static let description: (compact: Double, regular: Double) = (0.14, 0.38)
    static let title: (compact: Double, regular: Double) = (0.3, 0.3)

    static func group(index: Int, isCompact: Bool) -> Double {
        if isCompact {
            return index <= 1 ? 0.2 : 0.26 + 0.1 * Double(index - 1)
        }

        return index <= 1 ? 0.14 : 0.6 + 0.06 * Double(index - 2)
    }
}

extension View {

    func themedQuickLoad(
        isEnabled: Bool,
        isReady: Bool,
        isFailed: Bool,
        isCompact: Bool,
        title: String
    ) -> some View {
        modifier(
            ThemedQuickLoadModifier(
                isEnabled: isEnabled,
                isReady: isReady,
                isFailed: isFailed,
                isCompact: isCompact,
                title: title
            )
        )
    }

    func themedQuickLoadEntrance(_ delay: (compact: Double, regular: Double)) -> some View {
        modifier(ThemedQuickLoadEntranceModifier(compactDelay: delay.compact, regularDelay: delay.regular, isEnabled: true))
    }

    func themedQuickLoadEntrance(_ delay: Double?) -> some View {
        modifier(ThemedQuickLoadEntranceModifier(compactDelay: delay ?? 0, regularDelay: delay ?? 0, isEnabled: delay != nil))
    }

    func themedQuickLoadHeroZoom() -> some View {
        modifier(ThemedQuickLoadHeroZoomModifier())
    }
}

private struct ThemedQuickLoadModifier: ViewModifier {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.appTheme)
    private var theme
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @State
    private var phase: ThemedQuickLoadPhase = .loading
    @State
    private var startDate = Date.now
    @State
    private var isDataReady = false

    let isEnabled: Bool
    let isReady: Bool
    let isFailed: Bool
    let isCompact: Bool
    let title: String

    private let minimumDuration: Double = 4
    private let minimumImageWait: Double = 0.6

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .environment(\.themedQuickLoadPhase, phase)
                .scrollDisabled(phase != .loaded)
                .overlay(alignment: .top) {
                    if phase != .loaded {
                        ThemedQuickLoadOverlay(
                            phase: phase,
                            isCompact: isCompact,
                            title: title
                        )
                        .ignoresSafeArea(
                            edges: theme.overlaysItemTopBar(in: horizontalSizeClass) ? .all : [.horizontal, .bottom]
                        )
                        .allowsHitTesting(false)
                    }
                }
                .onAppear {
                    startDate = .now
                    isDataReady = isReady
                }
                .onChange(of: isReady) { _, newValue in
                    if newValue {
                        isDataReady = true
                    }
                }
                .onChange(of: isFailed) { _, newValue in
                    if newValue {
                        phase = .loaded
                    }
                }
                .task(id: isDataReady) {
                    await reveal()
                }
        } else {
            content
        }
    }

    private func reveal() async {
        guard isDataReady, phase == .loading else { return }

        let remaining = minimumDuration - Date.now.timeIntervalSince(startDate)
        try? await Task.sleep(for: .seconds(max(remaining, minimumImageWait)))

        guard !Task.isCancelled, phase == .loading else { return }

        phase = .revealing

        try? await Task.sleep(for: .seconds(reduceMotion ? 0.25 : theme.quickLoadRevealDuration))

        guard !Task.isCancelled else { return }

        phase = .loaded
    }
}

private struct ThemedQuickLoadOverlay: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.appTheme)
    private var theme

    let phase: ThemedQuickLoadPhase
    let isCompact: Bool
    let title: String

    private var isRevealed: Bool {
        phase != .loading
    }

    private func heroHeight(for width: CGFloat) -> CGFloat {
        isCompact ? width / 1.6 : width * 0.375
    }

    @ViewBuilder
    private func cover(size: CGSize) -> some View {
        switch theme {
        case .skeuo:
            SkeuoQuickLoadCover(
                title: title,
                isCompact: isCompact,
                isRevealed: isRevealed && !reduceMotion,
                size: size
            )
        case .y2k:
            Y2KQuickLoadCover(
                isCompact: isCompact,
                isRevealed: isRevealed && !reduceMotion,
                size: size
            )
        case .gameUI2:
            GameUIQuickLoadCover(
                isCompact: isCompact,
                isRevealed: isRevealed && !reduceMotion,
                size: size
            )
        default:
            EmptyView()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let heroSize = CGSize(width: width, height: heroHeight(for: width))

            ZStack(alignment: .topLeading) {
                ThemedQuickLoadSkeletons(
                    blocks: ThemedQuickLoadSkeletonLayout.blocks(
                        theme: theme,
                        width: width,
                        heroHeight: heroSize.height,
                        isCompact: isCompact
                    )
                )
                .opacity(isRevealed && !reduceMotion ? 0 : 1)
                .animation(
                    .easeInOut(duration: theme.quickLoadSkeletonFade.duration).delay(theme.quickLoadSkeletonFade.start),
                    value: isRevealed
                )

                cover(size: heroSize)

                if theme == .y2k, !isCompact {
                    Y2KQuickLoadInfoCard(
                        width: width,
                        heroHeight: heroSize.height,
                        isRevealed: isRevealed && !reduceMotion
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .opacity(reduceMotion && isRevealed ? 0 : 1)
        .animation(.easeInOut(duration: 0.25), value: reduceMotion && isRevealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.loadingItem(title))
    }
}

struct ThemedQuickLoadSkeletonBlock: Identifiable {

    enum Kind {

        case bar
        case card
        case avatar
    }

    let id: Int
    let rect: CGRect
    let cornerRadius: CGFloat
    let kind: Kind
}

enum ThemedQuickLoadSkeletonLayout {

    static func blocks(theme: AppTheme, width: CGFloat, heroHeight: CGFloat, isCompact: Bool) -> [ThemedQuickLoadSkeletonBlock] {
        var rects: [(CGRect, CGFloat, ThemedQuickLoadSkeletonBlock.Kind)] = []

        func add(
            _ x: CGFloat,
            _ y: CGFloat,
            _ width: CGFloat,
            _ height: CGFloat,
            _ radius: CGFloat,
            _ kind: ThemedQuickLoadSkeletonBlock.Kind = .bar
        ) {
            rects.append((CGRect(x: x, y: heroHeight + y, width: width, height: height), radius, kind))
        }

        let isY2K = theme == .y2k

        if theme == .gameUI2 {
            if isCompact {
                let playWidth = max(width - 244, 80)

                add(12, 16, playWidth, 52, 14)

                for index in 0 ..< 4 {
                    add(12 + playWidth + 7 + CGFloat(index) * 55, 18, 48, 48, 13)
                }

                add(12, 94, width - 24, 121, 14, .card)
                add(24, 79, 64, 24, 8)

                add(14, 229, 120, 26, 8)
                add(width - 108, 229, 94, 24, 12)

                var cardX: CGFloat = 14
                while cardX < width {
                    add(cardX, 266, 214, 194, 14, .card)
                    cardX += 228
                }
            } else {
                add(24, 44, 140, 28, 8)

                var cardX: CGFloat = 24
                while cardX < width {
                    add(cardX, 96, 236, 244, 14, .card)
                    cardX += 254
                }

                add(24, 356, 170, 28, 8)

                var avatarX: CGFloat = 28
                while avatarX < width {
                    add(avatarX, 396, 112, 112, 56, .avatar)
                    avatarX += 134
                }
            }
        } else if isCompact {
            let playWidth = max(width - 248, 80)
            let badgeRadius: CGFloat = isY2K ? 12 : 4
            let badgeHeight: CGFloat = isY2K ? 24 : 22

            add(16, 12, playWidth, 50, 25)

            for index in 0 ..< 4 {
                add(16 + playWidth + 8 + CGFloat(index) * 54, 14, 46, 46, 23)
            }

            add(16, 74, 46, badgeHeight, badgeRadius)
            add(68, 74, 52, badgeHeight, badgeRadius)
            add(126, 74, 32, badgeHeight, badgeRadius)
            add(168, 79, 96, 12, 6)

            add(16, 110, width - 32, 11, 6)
            add(16, 130, width - 32, 11, 6)
            add(16, 150, (width - 32) * 0.65, 11, 6)

            add(16, 178, isY2K ? 120 : 104, isY2K ? 18 : 20, isY2K ? 9 : 6)
            add(width - 88, 182, 72, 13, isY2K ? 7 : 6)

            var cardX: CGFloat = 16
            while cardX < width {
                add(cardX, 212, 214, 206, isY2K ? 18 : 8, .card)
                cardX += 226
            }
        } else {
            add(24, 41, isY2K ? 140 : 110, 22, isY2K ? 11 : 6)

            var cardX: CGFloat = 24
            while cardX < width {
                add(cardX, 78, 236, 244, isY2K ? 20 : 8, .card)
                cardX += 254
            }

            add(24, 343, isY2K ? 150 : 140, 20, isY2K ? 10 : 6)

            var avatarX: CGFloat = isY2K ? 28 : 24
            while avatarX < width {
                if isY2K {
                    add(avatarX, 378, 116, 116, 58, .avatar)
                    avatarX += 138
                } else {
                    add(avatarX, 378, 116, 150, 2, .avatar)
                    avatarX += 134
                }
            }
        }

        return rects.enumerated().map { index, entry in
            ThemedQuickLoadSkeletonBlock(
                id: index,
                rect: entry.0,
                cornerRadius: entry.1,
                kind: entry.2
            )
        }
    }
}

private struct ThemedQuickLoadSkeletons: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.appTheme)
    private var theme

    let blocks: [ThemedQuickLoadSkeletonBlock]

    private var sheenPeriod: Double {
        switch theme {
        case .y2k:
            1.2
        case .gameUI2:
            1.1
        default:
            1.3
        }
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let progress = reduceMotion
                ? -1
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: sheenPeriod) / sheenPeriod

            ZStack(alignment: .topLeading) {
                ForEach(blocks) { block in
                    skeleton(block, sheenProgress: progress)
                        .frame(width: block.rect.width, height: block.rect.height)
                        .offset(x: block.rect.minX, y: block.rect.minY)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func skeleton(_ block: ThemedQuickLoadSkeletonBlock, sheenProgress: Double) -> some View {
        switch theme {
        case .skeuo:
            SkeuoSkeleton(cornerRadius: block.cornerRadius, sheenProgress: sheenProgress)
        case .y2k:
            Y2KSkeleton(
                cornerRadius: block.cornerRadius,
                isFramed: block.kind != .bar,
                sheenProgress: sheenProgress
            )
        case .gameUI2:
            GameUISkeleton(
                cornerRadius: block.cornerRadius,
                isLarge: block.kind == .card,
                sheenProgress: sheenProgress
            )
        default:
            EmptyView()
        }
    }
}

struct ThemedQuickLoadSheen: View {

    let color: Color
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            LinearGradient(
                stops: [
                    .init(color: color.opacity(0), location: 0),
                    .init(color: color, location: 0.5),
                    .init(color: color.opacity(0), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.75)
            .offset(x: progress < 0 ? -width * 2 : -width * 1.375 + progress * width * 3)
        }
        .allowsHitTesting(false)
    }
}

private struct ThemedQuickLoadBurstValue {

    var progress: CGFloat = 0
    var scale: CGFloat = 0
    var rotation: Double = 0
    var opacity: Double = 0
}

struct ThemedQuickLoadBurst<Content: View>: View {

    let offset: CGSize
    let start: Double
    let isRevealed: Bool
    @ViewBuilder
    let content: Content

    var body: some View {
        content
            .keyframeAnimator(initialValue: ThemedQuickLoadBurstValue(), trigger: isRevealed) { content, value in
                content
                    .scaleEffect(value.scale)
                    .rotationEffect(.degrees(value.rotation))
                    .offset(x: offset.width * value.progress, y: offset.height * value.progress)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.progress) {
                    LinearKeyframe(0, duration: start)
                    CubicKeyframe(0.35, duration: 0.24)
                    CubicKeyframe(1, duration: 0.96)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0, duration: start)
                    CubicKeyframe(1.2, duration: 0.24)
                    CubicKeyframe(0, duration: 0.96)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(0, duration: start)
                    CubicKeyframe(60, duration: 0.24)
                    CubicKeyframe(200, duration: 0.96)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: start)
                    LinearKeyframe(1, duration: 0.24)
                    CubicKeyframe(0, duration: 0.96)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct ThemedQuickLoadEntranceModifier: ViewModifier {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.appTheme)
    private var theme
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    @Environment(\.themedQuickLoadPhase)
    private var phase

    let compactDelay: Double
    let regularDelay: Double
    let isEnabled: Bool

    private var isHidden: Bool {
        isEnabled && phase == .loading
    }

    private var delay: Double {
        horizontalSizeClass == .regular ? regularDelay : compactDelay
    }

    private var animation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.25)
        }

        switch theme {
        case .y2k:
            return .spring(duration: 0.6, bounce: 0.45).delay(theme.quickLoadEntranceStart + delay)
        case .gameUI2:
            return .spring(duration: 0.66, bounce: 0.4).delay(theme.quickLoadEntranceStart + delay)
        default:
            return .easeOut(duration: 0.48).delay(theme.quickLoadEntranceStart + delay)
        }
    }

    private var hiddenOffset: CGFloat {
        guard !reduceMotion else { return 0 }

        switch theme {
        case .y2k:
            return 0
        case .gameUI2:
            return -28
        default:
            return 18
        }
    }

    private var hiddenScale: CGFloat {
        guard !reduceMotion else { return 1 }

        switch theme {
        case .y2k:
            return 0.6
        case .gameUI2:
            return 0.92
        default:
            return 1
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? 0 : 1)
            .scaleEffect(isHidden ? hiddenScale : 1)
            .offset(y: isHidden ? hiddenOffset : 0)
            .animation(animation, value: isHidden)
    }
}

private struct ThemedQuickLoadHeroZoomModifier: ViewModifier {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.appTheme)
    private var theme
    @Environment(\.themedQuickLoadPhase)
    private var phase

    func body(content: Content) -> some View {
        let zoom = theme.quickLoadHeroZoom
        let isZoomed = phase == .loading && !reduceMotion

        content
            .scaleEffect(isZoomed ? zoom.scale : 1)
            .animation(.easeOut(duration: zoom.duration).delay(zoom.start), value: isZoomed)
    }
}
