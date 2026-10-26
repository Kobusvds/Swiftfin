//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

private extension Y2K {

    static let holo: [Color] = ["#FFB3E6", "#C7B3FF", "#B3E5FF", "#B3FFE4", "#FFE29A", "#FFC2A8", "#FFB3E6"]
        .map { Color(hex: $0) }
    static let rainbow: [Color] = [
        "#FFB3E6", "#C7B3FF", "#B3E5FF", "#B3FFE4", "#E4FF9E", "#FFE29A", "#FFC2A8",
        "#FFB3E6", "#D7B3FF", "#B3F0FF", "#C6FF4D", "#FFE29A", "#FFB3E6",
    ]
    .map { Color(hex: $0) }
    static let skeleton: [Color] = ["#FFD6F0", "#E0D6FF", "#D6ECFF", "#D9FFF0"].map { Color(hex: $0) }
    static let aqua = Color(hex: "#7CC0FF")
    static let statusShade = Color(red: 59 / 255, green: 21 / 255, blue: 86 / 255)

    static func orb(_ light: String, _ mid: String, _ deep: String) -> RadialGradient {
        RadialGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: Color(hex: light), location: 0.3),
                .init(color: Color(hex: mid), location: 0.65),
                .init(color: Color(hex: deep), location: 1),
            ],
            center: UnitPoint(x: 0.5, y: 0.22),
            startRadius: 0,
            endRadius: 16
        )
    }
}

struct Y2KQuickLoadCover: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let isCompact: Bool
    let isRevealed: Bool
    let size: CGSize

    private var discSize: CGFloat {
        isCompact ? 120 : 200
    }

    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: min(isCompact ? 150 : 180, size.height * 0.46))
    }

    private var irisRadius: CGFloat {
        let dx = max(center.x, size.width - center.x)
        let dy = max(center.y, size.height - center.y)

        return max(isCompact ? 560 : 900, (dx * dx + dy * dy).squareRoot() + 20)
    }

    private var bursts: [(dx: CGFloat, dy: CGFloat, color: String)] {
        if isCompact {
            [
                (-150, -60, "#FF8FC2"), (150, -70, "#A6EE2B"), (-120, 90, "#7CC0FF"), (130, 100, "#FFD23F"),
                (0, -130, "#FFFFFF"), (-180, 20, "#C7B3FF"), (180, 30, "#FF8FC2"), (20, 140, "#B3FFE4"),
            ]
        } else {
            [
                (-380, -90, "#FF8FC2"), (380, -100, "#A6EE2B"), (-300, 140, "#7CC0FF"), (320, 150, "#FFD23F"),
                (0, -170, "#FFFFFF"), (-520, 30, "#C7B3FF"), (520, 40, "#FF8FC2"), (-140, 170, "#B3FFE4"),
                (160, -160, "#FFE29A"), (140, 180, "#FFFFFF"),
            ]
        }
    }

    @ViewBuilder
    private func coverLayer(time: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Y2KHoloBackground(isCompact: isCompact, time: time)

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .white.opacity(0.95), location: 0),
                            .init(color: Color(red: 1, green: 214 / 255, blue: 236 / 255).opacity(0.55), location: 0.45),
                            .init(color: .white.opacity(0), location: 0.7),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: (isCompact ? 170 : 290) / 2
                    )
                )
                .frame(width: isCompact ? 170 : 290, height: isCompact ? 170 : 290)
                .position(center)

            ZStack {
                Y2KDisc(size: discSize, rotation: .degrees(time.truncatingRemainder(dividingBy: 0.7) / 0.7 * 360))

                Y2KOrbit(isCompact: isCompact, rotation: .degrees(time.truncatingRemainder(dividingBy: 1.6) / 1.6 * 360))
            }
            .keyframeAnimator(initialValue: 1.0, trigger: isRevealed) { content, scale in
                content
                    .scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.22, duration: 0.36)
                    CubicKeyframe(0.3, duration: 0.48)
                }
            }
            .opacity(isRevealed ? 0 : 1)
            .animation(.easeIn(duration: 0.48).delay(0.36), value: isRevealed)
            .position(center)

            Y2KStatusPill(isCompact: isCompact, time: time)
                .opacity(isRevealed ? 0 : 1)
                .animation(.easeIn(duration: 0.3).delay(0.36), value: isRevealed)
                .position(x: center.x, y: center.y + discSize / 2 + (isCompact ? 37 : 48))
        }
        .frame(width: size.width, height: size.height)
        .mask {
            Y2KIrisHole(radius: isRevealed ? irisRadius : 0, center: center)
                .fill(style: FillStyle(eoFill: true))
                .animation(.timingCurve(0.7, 0, 0.3, 1, duration: 0.84).delay(0.36), value: isRevealed)
        }
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || isRevealed)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            ZStack(alignment: .topLeading) {
                coverLayer(time: time)

                Y2KRing(diameter: isCompact ? 760 : 1400, lineWidth: isCompact ? 8 : 10, isRevealed: isRevealed)
                    .position(center)

                ForEach(Array(bursts.enumerated()), id: \.offset) { _, burst in
                    Y2KSparkle(
                        color: Color(hex: burst.color),
                        offset: CGSize(width: burst.dx, height: burst.dy),
                        isRevealed: isRevealed
                    )
                    .position(center)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

private struct Y2KIrisHole: Shape {

    var radius: CGFloat
    let center: CGPoint

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path
    }
}

private struct Y2KHoloBackground: View {

    let isCompact: Bool
    let time: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 2
            let slide = time.truncatingRemainder(dividingBy: 3) / 3

            HStack(spacing: 0) {
                LinearGradient(colors: Y2K.holo, startPoint: .leading, endPoint: .trailing)
                    .frame(width: width)

                LinearGradient(colors: Y2K.holo, startPoint: .leading, endPoint: .trailing)
                    .frame(width: width)
            }
            .offset(x: -slide * width)
        }
        .overlay {
            Canvas { context, size in
                func dots(spacing: CGSize, origin: CGPoint, radius: CGFloat, opacity: Double) {
                    var y = origin.y

                    while y < size.height {
                        var x = origin.x

                        while x < size.width {
                            context.fill(
                                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                with: .color(.white.opacity(opacity))
                            )
                            x += spacing.width
                        }
                        y += spacing.height
                    }
                }

                dots(spacing: CGSize(width: 38, height: 41), origin: CGPoint(x: 19, y: 20), radius: 1.7, opacity: 0.95)
                dots(spacing: CGSize(width: 53, height: 47), origin: CGPoint(x: 43, y: 46), radius: 1.2, opacity: 0.7)
            }
        }
        .overlay(alignment: .top) {
            if isCompact {
                GeometryReader { proxy in
                    LinearGradient.vertical(Y2K.statusShade.opacity(0.85), Y2K.statusShade.opacity(0))
                        .frame(height: proxy.size.height * 0.34)
                }
            }
        }
        .clipped()
    }
}

private struct Y2KDisc: View {

    let size: CGFloat
    let rotation: Angle

    private var hubSize: CGFloat {
        size / 3
    }

    var body: some View {
        ZStack {
            ZStack {
                AngularGradient(colors: Y2K.rainbow, center: .center)

                Canvas { context, canvasSize in
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    var radius: CGFloat = 3.5

                    while radius < canvasSize.width / 2 {
                        context.stroke(
                            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                            with: .color(.white.opacity(0.18)),
                            lineWidth: 1
                        )
                        radius += 4
                    }
                }
            }
            .rotationEffect(rotation)

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.75), location: 0),
                    .init(color: .white.opacity(0), location: 0.32),
                    .init(color: .white.opacity(0), location: 0.58),
                    .init(color: .white.opacity(0.45), location: 0.7),
                    .init(color: .white.opacity(0), location: 0.84),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: "#E3EBF7"), location: 0),
                            .init(color: Color(hex: "#E3EBF7"), location: 0.35),
                            .init(color: Y2K.chromeEdge, location: 0.4),
                            .init(color: .white.opacity(0.92), location: 0.45),
                            .init(color: Color(red: 220 / 255, green: 227 / 255, blue: 238 / 255).opacity(0.8), location: 0.95),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: hubSize / 2
                    )
                    .shadow(.inner(color: Y2K.navy.opacity(0.25), radius: 2, y: 2))
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color(red: 110 / 255, green: 124 / 255, blue: 148 / 255).opacity(0.7))
                }
                .frame(width: hubSize, height: hubSize)
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.95), lineWidth: 2)
                .padding(-1)
        }
        .overlay {
            Circle()
                .stroke(Y2K.ring, lineWidth: 1)
                .padding(-2.5)
        }
        .shadow(color: Y2K.shadow.opacity(0.4), radius: 11, y: 10)
    }
}

private struct Y2KOrbit: View {

    let isCompact: Bool
    let rotation: Angle

    private var diameter: CGFloat {
        isCompact ? 170 : 280
    }

    @ViewBuilder
    private func orb(_ gradient: RadialGradient, edge: Color, size: CGFloat) -> some View {
        Circle()
            .fill(gradient)
            .overlay {
                Circle()
                    .strokeBorder(edge)
            }
            .frame(width: size, height: size)
    }

    var body: some View {
        ZStack {
            orb(Y2K.orb("#FFD9EC", "#FF8FC2", "#E0559A"), edge: Y2K.pinkEdge, size: isCompact ? 22 : 28)
                .offset(y: -diameter / 2)

            orb(Y2K.orb("#E9FFC2", "#A6EE2B", "#6DB200"), edge: Y2K.limeEdge, size: isCompact ? 18 : 24)
                .offset(y: diameter / 2)

            if !isCompact {
                orb(Y2K.orb("#CDE9FF", "#7CC0FF", "#4FA3F5"), edge: Y2K.blueOrbEdge, size: 20)
                    .offset(x: -diameter / 2)
            }
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(rotation)
    }
}

private struct Y2KStatusPill: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let isCompact: Bool
    let time: Double

    private func dotOpacity(delay: Double) -> Double {
        guard !reduceMotion else { return 1 }

        let progress = (time - delay).truncatingRemainder(dividingBy: 0.9) / 0.9
        let phase = progress < 0 ? progress + 1 : progress

        return phase < 0.4 ? 0.2 + 0.8 * (phase / 0.4) : 1 - 0.8 * ((phase - 0.4) / 0.6)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(L10n.spinningUp.localizedUppercase)
                .font(Y2K.title(isCompact ? 12 : 15))
                .foregroundStyle(Y2K.navy)
                .lineLimit(1)

            ForEach(Array([Y2K.pink, Y2K.limeGel, Y2K.aqua].enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: isCompact ? 5 : 6, height: isCompact ? 5 : 6)
                    .opacity(dotOpacity(delay: Double(index) * 0.15))
            }
        }
        .frame(width: isCompact ? 156 : 220, height: isCompact ? 30 : 36)
        .background(LinearGradient.vertical(.white.opacity(0.9), .white.opacity(0.6)), in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.95), lineWidth: 2)
        }
        .shadow(color: Y2K.shadow.opacity(0.3), radius: 5, y: 4)
    }
}

private struct Y2KRing: View {

    let diameter: CGFloat
    let lineWidth: CGFloat
    let isRevealed: Bool

    var body: some View {
        Circle()
            .stroke(.white, lineWidth: lineWidth)
            .overlay {
                Circle()
                    .stroke(Y2K.aqua, lineWidth: lineWidth * 0.6)
                    .blur(radius: lineWidth * 0.6)
                    .padding(lineWidth)
            }
            .shadow(color: Y2K.pink, radius: lineWidth)
            .frame(width: diameter, height: diameter)
            .scaleEffect(isRevealed ? 1 : 0.001)
            .animation(.easeOut(duration: 0.96).delay(0.36), value: isRevealed)
            .keyframeAnimator(initialValue: 0.0, trigger: isRevealed) { content, opacity in
                content
                    .opacity(opacity)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 0.36)
                    LinearKeyframe(1, duration: 0.12)
                    CubicKeyframe(0, duration: 0.84)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct Y2KSparkleShape: Shape {

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 24
        let points: [(CGFloat, CGFloat)] = [
            (12, 0), (14.5, 9.5), (24, 12), (14.5, 14.5), (12, 24), (9.5, 14.5), (0, 12), (9.5, 9.5),
        ]
        var path = Path()

        for (index, point) in points.enumerated() {
            let location = CGPoint(x: rect.minX + point.0 * scale, y: rect.minY + point.1 * scale)

            if index == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct Y2KSparkle: View {

    let color: Color
    let offset: CGSize
    let isRevealed: Bool

    var body: some View {
        ThemedQuickLoadBurst(offset: offset, start: 0.36, isRevealed: isRevealed) {
            Y2KSparkleShape()
                .fill(color)
                .shadow(color: .white.opacity(0.8), radius: 3)
                .frame(width: 26, height: 26)
        }
    }
}

struct Y2KQuickLoadInfoCard: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let width: CGFloat
    let heroHeight: CGFloat
    let isRevealed: Bool

    private let height: CGFloat = 124

    private var cardWidth: CGFloat {
        width - 72
    }

    @ViewBuilder
    private var skeletons: some View {
        TimelineView(.animation(paused: reduceMotion || isRevealed)) { context in
            let sheen = reduceMotion
                ? -1
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
            let barsX: CGFloat = 400
            let barsWidth = max(cardWidth - barsX - 22, 80)

            ZStack(alignment: .topLeading) {
                block(x: 22, y: 35, width: 110, height: 54, radius: 27, sheen: sheen)

                ForEach(0 ..< 4, id: \.self) { index in
                    block(x: 142 + CGFloat(index) * 60, y: 37, width: 50, height: 50, radius: 25, sheen: sheen)
                }

                block(x: barsX, y: 18, width: barsWidth, height: 12, radius: 6, sheen: sheen)
                block(x: barsX, y: 39, width: barsWidth, height: 12, radius: 6, sheen: sheen)
                block(x: barsX, y: 60, width: barsWidth * 0.65, height: 12, radius: 6, sheen: sheen)

                block(x: barsX, y: 87, width: 60, height: 24, radius: 12, sheen: sheen)
                block(x: barsX + 68, y: 87, width: 74, height: 24, radius: 12, sheen: sheen)
                block(x: barsX + 150, y: 87, width: 40, height: 24, radius: 12, sheen: sheen)
                block(x: barsX + 204, y: 93, width: 96, height: 13, radius: 7, sheen: sheen)
            }
        }
    }

    private func block(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, sheen: Double) -> some View {
        Y2KSkeleton(cornerRadius: radius, isFramed: false, sheenProgress: sheen)
            .frame(width: width, height: height)
            .offset(x: x, y: y)
    }

    var body: some View {
        Color.clear
            .frame(width: cardWidth - 44, height: height - 28)
            .themedHeroStrip()
            .opacity(isRevealed ? 0 : 1)
            .animation(.easeInOut(duration: 0.3).delay(0.9), value: isRevealed)
            .overlay(alignment: .topLeading) {
                skeletons
                    .opacity(isRevealed ? 0 : 1)
                    .animation(.easeInOut(duration: 0.36).delay(0.36), value: isRevealed)
            }
            .offset(x: 36, y: heroHeight - 14 - height)
            .accessibilityHidden(true)
    }
}

struct Y2KSkeleton: View {

    let cornerRadius: CGFloat
    let isFramed: Bool
    let sheenProgress: Double

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(colors: Y2K.skeleton, startPoint: .leading, endPoint: .trailing)
                    .shadow(.inner(color: Y2K.navy.opacity(isFramed ? 0 : 0.18), radius: 1, y: 1))
            )
            .overlay {
                ThemedQuickLoadSheen(color: .white.opacity(0.95), progress: sheenProgress)
                    .clipShape(.rect(cornerRadius: cornerRadius))
            }
            .overlay {
                if isFramed {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.white, lineWidth: 2)
                }
            }
            .shadow(color: isFramed ? Y2K.shadow.opacity(0.28) : .clear, radius: 6, y: 4)
    }
}
