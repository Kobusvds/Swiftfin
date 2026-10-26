//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

private extension GameUI {

    static let skeletonPiece = Color(hex: "#4A2290")
    static let popcorn = Color(hex: "#FFF3C4")
}

struct GameUIQuickLoadCover: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let isCompact: Bool
    let isRevealed: Bool
    let size: CGSize

    private var panel: CGRect {
        if isCompact {
            CGRect(origin: .zero, size: size)
        } else {
            CGRect(x: 22, y: 14, width: size.width - 44, height: size.height - 20)
        }
    }

    private var badgeSize: CGFloat {
        isCompact ? 150 : 240
    }

    private var center: CGPoint {
        CGPoint(x: panel.width / 2, y: panel.height * 0.55)
    }

    private var bursts: [(dx: CGFloat, dy: CGFloat, color: Color)] {
        if isCompact {
            [
                (-150, -70, GameUI.yellow), (150, -80, GameUI.green), (-130, 90, GameUI.pink), (140, 100, .white),
                (0, -120, GameUI.orange), (-180, 10, GameUI.lilac), (180, 20, GameUI.yellow), (30, 120, GameUI.green),
            ]
        } else {
            [
                (-420, -110, GameUI.yellow), (420, -120, GameUI.green), (-340, 150, GameUI.pink), (360, 160, .white),
                (0, -200, GameUI.orange), (-560, 20, GameUI.lilac), (560, 30, GameUI.yellow), (-150, 190, GameUI.green),
                (170, -190, GameUI.pink), (150, 200, GameUI.lilac),
            ]
        }
    }

    @ViewBuilder
    private func shutter(isTop: Bool) -> some View {
        GameUIShutter(isTop: isTop, isCompact: isCompact)
            .frame(width: panel.width, height: panel.height)
            .offset(y: isRevealed ? panel.height * (isTop ? -1.04 : 1.04) : 0)
            .animation(.timingCurve(0.7, 0, 0.3, 1, duration: 0.72).delay(0.42), value: isRevealed)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || isRevealed)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            ZStack(alignment: .topLeading) {
                shutter(isTop: true)

                shutter(isTop: false)

                GameUIPopcorn(isCompact: isCompact, time: time)
                    .opacity(isRevealed ? 0 : 1)
                    .animation(.easeIn(duration: 0.3).delay(0.18), value: isRevealed)
                    .position(x: center.x, y: center.y + badgeSize / 2 + (isCompact ? 18 : 26))

                GameUIBadge(size: badgeSize, isCompact: isCompact, isRevealed: isRevealed, time: time)
                    .position(center)

                ForEach(Array(bursts.enumerated()), id: \.offset) { _, burst in
                    ThemedQuickLoadBurst(
                        offset: CGSize(width: burst.dx, height: burst.dy),
                        start: 0.54,
                        isRevealed: isRevealed
                    ) {
                        GameUIStarburst()
                            .fill(burst.color)
                            .overlay {
                                GameUIStarburst()
                                    .stroke(GameUI.outline, style: StrokeStyle(lineWidth: 2.1, lineJoin: .round))
                            }
                            .frame(width: 28, height: 28)
                    }
                    .position(center)
                }
            }
            .frame(width: panel.width, height: panel.height, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: isCompact ? 0 : 20))
            .overlay {
                if !isCompact {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(GameUI.outline, lineWidth: 4)
                }
            }
            .offset(x: panel.minX, y: panel.minY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

private struct GameUIShutterShape: Shape {

    let isTop: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if isTop {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.35))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.35))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

private struct GameUIShutter: View {

    let isTop: Bool
    let isCompact: Bool

    private var stripeWidth: CGFloat {
        isCompact ? 16 : 22
    }

    private var seamWidth: CGFloat {
        isCompact ? 12 : 14
    }

    private var shineWidth: CGFloat {
        isCompact ? 5 : 6
    }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(isTop ? GameUI.pink : GameUI.orange))

            var stripes = context
            let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
            stripes.translateBy(x: size.width / 2, y: size.height / 2)
            stripes.rotate(by: .degrees(isTop ? 45 : -45))

            var x = -diagonal

            while x < diagonal {
                stripes.fill(
                    Path(CGRect(x: x, y: -diagonal, width: stripeWidth, height: diagonal * 2)),
                    with: .color(.white.opacity(0.16))
                )
                x += stripeWidth * 2
            }

            func seamLine(offset: CGFloat) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height * 0.75 + offset))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.35 + offset))
                return path
            }

            context.stroke(seamLine(offset: 0), with: .color(GameUI.outline), lineWidth: seamWidth)

            if isTop {
                context.stroke(
                    seamLine(offset: -(seamWidth / 2 + shineWidth / 2 + 3)),
                    with: .color(.white.opacity(0.5)),
                    lineWidth: shineWidth
                )
            }
        }
        .clipShape(GameUIShutterShape(isTop: isTop))
    }
}

private struct GameUIStarburst: Shape {

    func path(in rect: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = [
            (20, 1), (25, 8), (33.4, 6.6), (32, 15), (39, 20), (32, 25), (33.4, 33.4), (25, 32),
            (20, 39), (15, 32), (6.6, 33.4), (8, 25), (1, 20), (8, 15), (6.6, 6.6), (15, 8),
        ]
        let scale = rect.width / 40
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

private struct GameUIBadge: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let size: CGFloat
    let isCompact: Bool
    let isRevealed: Bool
    let time: Double

    var body: some View {
        ZStack {
            GameUIStarburst()
                .fill(GameUI.yellow)
                .overlay {
                    GameUIStarburst()
                        .stroke(GameUI.outline, style: StrokeStyle(lineWidth: 1.6 * size / 40, lineJoin: .round))
                }
                .rotationEffect(.degrees(reduceMotion ? 0 : time.truncatingRemainder(dividingBy: 8) / 8 * 360))
                .shadow(color: GameUI.outline, radius: 0, y: isCompact ? 4 : 6)

            Text(L10n.quickLoadReady.localizedUppercase)
                .font(GameUI.title(isCompact ? 30 : 46))
                .foregroundStyle(.white)
                .gameOutline(isCompact ? 2 : 3, drop: isCompact ? 2 : 3)
                .scaleEffect(isRevealed ? 0.4 : 1)
                .opacity(isRevealed ? 0 : 1)
                .animation(.easeInOut(duration: 0.24), value: isRevealed)

            Text(L10n.quickLoadGo.localizedUppercase)
                .font(GameUI.title(isCompact ? 46 : 76))
                .foregroundStyle(GameUI.green)
                .gameOutline(isCompact ? 3 : 4, drop: isCompact ? 2 : 4)
                .scaleEffect(isRevealed ? 1 : 0.01)
                .opacity(isRevealed ? 1 : 0)
                .animation(.spring(duration: 0.42, bounce: 0.55).delay(0.12), value: isRevealed)
        }
        .lineLimit(1)
        .frame(width: size, height: size)
        .scaleEffect(isRevealed ? 2.4 : 1)
        .rotationEffect(.degrees(isRevealed ? 16 : 0))
        .opacity(isRevealed ? 0 : 1)
        .animation(.easeIn(duration: 0.48).delay(0.54), value: isRevealed)
    }
}

private struct GameUIPopcornShape: Shape {

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 24
        let scaleY = rect.height / 22

        func puff(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(
                x: rect.minX + (x - radius) * scaleX,
                y: rect.minY + (y - radius) * scaleY,
                width: radius * 2 * scaleX,
                height: radius * 2 * scaleY
            ))
        }

        return puff(8, 10, 5)
            .union(puff(12.5, 7, 5.5))
            .union(puff(17, 10.5, 5))
            .union(puff(12, 15, 5.5))
    }
}

private struct GameUIPopcorn: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let isCompact: Bool
    let time: Double

    private func hop(index: Int) -> CGFloat {
        guard !reduceMotion else { return 0 }

        let height: CGFloat = isCompact ? 10 : 14
        let progress = (time - Double(index) * 0.2).truncatingRemainder(dividingBy: 0.6) / 0.6
        let phase = progress < 0 ? progress + 1 : progress

        return -height * (1 - cos(2 * .pi * phase)) / 2
    }

    var body: some View {
        HStack(spacing: isCompact ? 10 : 14) {
            ForEach(0 ..< 3, id: \.self) { index in
                GameUIPopcornShape()
                    .fill(GameUI.popcorn)
                    .overlay {
                        GameUIPopcornShape()
                            .stroke(GameUI.outline, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    }
                    .frame(width: isCompact ? 22 : 32, height: isCompact ? 20 : 29)
                    .offset(y: hop(index: index))
            }
        }
    }
}

struct GameUISkeleton: View {

    let cornerRadius: CGFloat
    let isLarge: Bool
    let sheenProgress: Double

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill((isLarge ? GameUI.well : GameUI.skeletonPiece).shadow(.inner(color: .black.opacity(0.3), radius: 0, y: 3)))
            .overlay {
                ThemedQuickLoadSheen(color: GameUI.lilac.opacity(0.5), progress: sheenProgress)
                    .clipShape(.rect(cornerRadius: cornerRadius))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(GameUI.outline, lineWidth: 3)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GameUI.outline)
                    .offset(y: 4)
            }
    }
}
