//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

private extension Skeuo {

    static let velvetFold = Gradient(stops: [
        .init(color: Color(hex: "#2A0845"), location: 0),
        .init(color: Color(hex: "#5A1F86"), location: 0.294),
        .init(color: Color(hex: "#8E44C9"), location: 0.5),
        .init(color: Color(hex: "#5A1F86"), location: 0.706),
        .init(color: Color(hex: "#2A0845"), location: 1),
    ])
    static let rope = LinearGradient.vertical(Color(hex: "#FFE9A8"), Color(hex: "#B07A1A"))
    static let fringeLight = Color(hex: "#FFD27A")
    static let fringeDark = Color(hex: "#B07A1A")
    static let plaqueBrass = LinearGradient(
        stops: [
            .init(color: Color(hex: "#FFE9A8"), location: 0),
            .init(color: Color(hex: "#E3B04A"), location: 0.45),
            .init(color: Color(hex: "#B07A1A"), location: 0.55),
            .init(color: Color(hex: "#F2C76A"), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let plaqueEdge = Color(hex: "#5A3A0A")
    static let bulbGlow = Color(hex: "#FFC870")
    static let marqueeText = Color(hex: "#F7C35C")
    static let reelSilver = Color(hex: "#D5D9E0")
    static let reelHole = Color(hex: "#1C0A2E")
    static let spotlight = Color(red: 1, green: 222 / 255, blue: 150 / 255)
}

struct SkeuoQuickLoadCover: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let title: String
    let isCompact: Bool
    let isRevealed: Bool
    let size: CGSize

    private var curve: Animation {
        .timingCurve(0.65, 0, 0.35, 1, duration: 0.96)
    }

    private var panelWidth: CGFloat {
        size.width / 2
    }

    private var pelmetHeight: CGFloat {
        isCompact ? 60 + 4 + 16 : 50 + 5 + 19
    }

    private var fringeHeight: CGFloat {
        isCompact ? 14 + 5 : 18 + 6
    }

    @ViewBuilder
    private func curtain(isLeading: Bool) -> some View {
        SkeuoCurtainPanel(isLeading: isLeading, isCompact: isCompact)
            .frame(width: panelWidth, height: size.height)
            .scaleEffect(x: isRevealed ? 0.6 : 1, y: 1, anchor: isLeading ? .leading : .trailing)
            .offset(x: isRevealed ? panelWidth * (isLeading ? -1.04 : 1.04) : 0)
            .animation(curve.delay(0.24), value: isRevealed)
    }

    var body: some View {
        ZStack(alignment: .top) {
            SkeuoSpotlight(isRevealed: isRevealed)

            HStack(spacing: 0) {
                curtain(isLeading: true)
                curtain(isLeading: false)
            }

            SkeuoPelmet(isCompact: isCompact)
                .offset(y: isRevealed ? -pelmetHeight * 1.1 : 0)
                .animation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.72).delay(0.36), value: isRevealed)

            SkeuoMarquee(title: title, isCompact: isCompact)
                .opacity(isRevealed ? 0 : 1)
                .scaleEffect(isRevealed ? 0.8 : 1)
                .animation(.easeInOut(duration: 0.36), value: isRevealed)
                .position(
                    x: size.width / 2,
                    y: pelmetHeight + (size.height - pelmetHeight - fringeHeight) / 2
                )
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
    }
}

private struct SkeuoSpotlight: View {

    let isRevealed: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            RadialGradient(
                stops: [
                    .init(color: Skeuo.spotlight.opacity(0.6), location: 0),
                    .init(color: Skeuo.spotlight.opacity(0.18), location: 0.45),
                    .init(color: Skeuo.spotlight.opacity(0), location: 0.75),
                ],
                center: .top,
                startRadius: 0,
                endRadius: size.height * 0.9
            )
            .scaleEffect(x: size.width * 0.7 / max(size.height * 0.9, 1), y: 1, anchor: .top)
        }
        .keyframeAnimator(initialValue: 0.0, trigger: isRevealed) { content, opacity in
            content
                .opacity(opacity)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(0, duration: 0.48)
                CubicKeyframe(1, duration: 0.48)
                CubicKeyframe(0, duration: 1.08)
            }
        }
    }
}

private struct SkeuoCurtainPanel: View {

    let isLeading: Bool
    let isCompact: Bool

    private var foldWidth: CGFloat {
        isCompact ? 34 : 48
    }

    private var seamShadow: CGFloat {
        isCompact ? 10 : 14
    }

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0

            while x < size.width {
                let rect = CGRect(x: x, y: 0, width: foldWidth, height: size.height)
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Skeuo.velvetFold,
                        startPoint: CGPoint(x: rect.minX, y: 0),
                        endPoint: CGPoint(x: rect.maxX, y: 0)
                    )
                )
                x += foldWidth
            }
        }
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .black.opacity(0), location: 0.28),
                    .init(color: .black.opacity(0), location: 0.78),
                    .init(color: .black.opacity(0.4), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: isLeading ? .trailing : .leading) {
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0)],
                startPoint: isLeading ? .trailing : .leading,
                endPoint: isLeading ? .leading : .trailing
            )
            .frame(width: seamShadow * 2)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Skeuo.rope
                    .frame(height: isCompact ? 5 : 6)

                SkeuoStripes(stripeWidth: 2)
                    .frame(height: isCompact ? 14 : 18)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: isCompact ? 5 : 7, x: isLeading ? 4 : -4)
    }
}

private struct SkeuoStripes: View {

    let stripeWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Skeuo.fringeDark))

            var x: CGFloat = 0

            while x < size.width {
                context.fill(
                    Path(CGRect(x: x, y: 0, width: stripeWidth, height: size.height)),
                    with: .color(Skeuo.fringeLight)
                )
                x += stripeWidth * 2
            }
        }
    }
}

private struct SkeuoPelmet: View {

    let isCompact: Bool

    private var scallopWidth: CGFloat {
        isCompact ? 28 : 34
    }

    private var scallopDepth: CGFloat {
        isCompact ? 16 : 19
    }

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#1C0430"), location: 0),
                    .init(color: Color(hex: "#4A1570"), location: 0.7),
                    .init(color: Color(hex: "#5A1F86"), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .bottom) {
                Color.white.opacity(0.15)
                    .frame(height: 1)
            }
            .frame(height: isCompact ? 60 : 50)

            Skeuo.rope
                .frame(height: isCompact ? 4 : 5)

            Canvas { context, size in
                let radius = scallopWidth / 2
                var path = Path()
                var x: CGFloat = 0

                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addArc(
                        center: CGPoint(x: x + radius, y: 0),
                        radius: min(radius, size.height),
                        startAngle: .degrees(180),
                        endAngle: .zero,
                        clockwise: true
                    )
                    path.closeSubpath()
                    x += scallopWidth
                }

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: "#5A1F86"), Color(hex: "#4A1570")]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
            .frame(height: scallopDepth)
            .shadow(color: .black.opacity(0.55), radius: 1.5, y: 3)
        }
    }
}

private struct SkeuoMarquee: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let title: String
    let isCompact: Bool

    private var width: CGFloat {
        isCompact ? 244 : 400
    }

    private var bulbCount: Int {
        isCompact ? 11 : 15
    }

    private var bulbSize: CGFloat {
        isCompact ? 8 : 11
    }

    private var cornerRadius: CGFloat {
        isCompact ? 12 : 16
    }

    private var innerCornerRadius: CGFloat {
        isCompact ? 6 : 8
    }

    private var labelSize: CGFloat {
        isCompact ? 10 : 13
    }

    @ViewBuilder
    private var bulbs: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: reduceMotion)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.4)

            HStack(spacing: 0) {
                ForEach(0 ..< bulbCount, id: \.self) { index in
                    if index > 0 {
                        Spacer(minLength: 0)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: Color(hex: "#FFFDE8"), location: 0),
                                    .init(color: Color(hex: "#FFD27A"), location: 0.45),
                                    .init(color: Color(hex: "#E08E0A"), location: 1),
                                ],
                                center: UnitPoint(x: 0.4, y: 0.35),
                                startRadius: 0,
                                endRadius: bulbSize * 0.65
                            )
                        )
                        .frame(width: bulbSize, height: bulbSize)
                        .shadow(color: Skeuo.bulbGlow, radius: isCompact ? 3 : 4)
                        .opacity(reduceMotion || (tick + index).isMultiple(of: 2) ? 1 : 0.25)
                }
            }
            .padding(.horizontal, isCompact ? 3 : 4)
            .frame(height: isCompact ? 10 : 14)
        }
    }

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: isCompact ? 6 : 10) {
            Text(L10n.nowShowing.localizedUppercase)
                .font(Skeuo.font(labelSize, .bold))
                .kerning(labelSize * (isCompact ? 0.32 : 0.4))
                .foregroundStyle(Skeuo.marqueeText)
                .shadow(color: .black, radius: 0, y: 1)

            Text(title.localizedUppercase)
                .font(ThemeFont.custom("CinzelDecorative-Black", size: isCompact ? 22 : 38))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Skeuo.goldText)

            HStack(spacing: isCompact ? 7 : 9) {
                SkeuoFilmReel(size: isCompact ? 18 : 24)

                Text(L10n.raisingTheCurtain)
                    .font(Skeuo.font(isCompact ? 11 : 14, .semibold))
                    .foregroundStyle(Skeuo.reelSilver)
            }
        }
        .lineLimit(1)
        .padding(.top, isCompact ? 10 : 18)
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.bottom, isCompact ? 9 : 16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: innerCornerRadius)
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#4A1A6E"), Color(hex: "#1C0A2E")],
                        center: .top,
                        startRadius: 0,
                        endRadius: width * 0.6
                    )
                    .shadow(.inner(color: .black.opacity(0.8), radius: isCompact ? 3 : 4, y: isCompact ? 2 : 3))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: innerCornerRadius)
                .strokeBorder(Skeuo.plaqueEdge)
        }
    }

    var body: some View {
        VStack(spacing: isCompact ? 6 : 9) {
            bulbs

            panel

            bulbs
        }
        .padding(.vertical, isCompact ? 7 : 10)
        .padding(.horizontal, isCompact ? 9 : 12)
        .frame(width: width)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Skeuo.plaqueBrass.shadow(.inner(color: .white.opacity(0.7), radius: 0, y: 1)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Skeuo.plaqueEdge)
        }
        .shadow(color: .black.opacity(0.7), radius: isCompact ? 8 : 11, y: isCompact ? 8 : 10)
        .shadow(color: Skeuo.bulbGlow.opacity(0.4), radius: isCompact ? 17 : 25)
    }
}

private struct SkeuoFilmReel: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let size: CGFloat

    private let holes: [CGPoint] = [
        CGPoint(x: 20, y: 9),
        CGPoint(x: 30.5, y: 16.6),
        CGPoint(x: 26.5, y: 29),
        CGPoint(x: 13.5, y: 29),
        CGPoint(x: 9.5, y: 16.6),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1

            Canvas { graphics, canvasSize in
                let scale = canvasSize.width / 40

                func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
                    Path(ellipseIn: CGRect(
                        x: (center.x - radius) * scale,
                        y: (center.y - radius) * scale,
                        width: radius * 2 * scale,
                        height: radius * 2 * scale
                    ))
                }

                let body = circle(CGPoint(x: 20, y: 20), 18)
                graphics.fill(body, with: .color(Skeuo.reelSilver))
                graphics.stroke(body, with: .color(Skeuo.steel), lineWidth: 2 * scale)

                for hole in holes {
                    graphics.fill(circle(hole, 5), with: .color(Skeuo.reelHole))
                }

                graphics.fill(circle(CGPoint(x: 20, y: 20), 3), with: .color(Skeuo.steel))
            }
            .rotationEffect(.degrees(reduceMotion ? 0 : turn * 360))
        }
        .frame(width: size, height: size)
    }
}

struct SkeuoSkeleton: View {

    let cornerRadius: CGFloat
    let sheenProgress: Double

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.26).shadow(.inner(color: .black.opacity(0.55), radius: 1.5, y: 2)))
            .overlay {
                ThemedQuickLoadSheen(color: .white.opacity(0.1), progress: sheenProgress)
                    .clipShape(.rect(cornerRadius: cornerRadius))
            }
            .shadow(color: .white.opacity(0.1), radius: 0, y: 1)
    }
}
