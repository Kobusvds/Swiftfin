//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension LinearGradient {

    static func gel(_ top: String, _ upper: String, _ lower: String, _ bottom: String) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: top), location: 0),
                .init(color: Color(hex: upper), location: 0.5),
                .init(color: Color(hex: lower), location: 0.51),
                .init(color: Color(hex: bottom), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func vertical(_ top: Color, _ bottom: Color) -> LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    static let gloss115 = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.3), location: 0),
            .init(color: .white.opacity(0.08), location: 0.4),
            .init(color: .white.opacity(0), location: 0.41),
        ],
        startPoint: UnitPoint(x: 0.05, y: 0.29),
        endPoint: UnitPoint(x: 0.95, y: 0.71)
    )
}

enum Skeuo {

    static let linen = Color(hex: "#333945")
    static let glowTop = Color(hex: "#4A5262")
    static let glowBottom = Color(hex: "#2C313B")

    static let barLeather = LinearGradient.vertical(Color(hex: "#9A6A40"), Color(hex: "#6E4526"))
    static let leather = LinearGradient.vertical(Color(hex: "#5E3A1F"), Color(hex: "#482A14"))
    static let leatherEdge = Color(hex: "#2B1A0D")
    static let stitch = Color(red: 1, green: 236 / 255, blue: 200 / 255).opacity(0.55)
    static let cream = Color(hex: "#F6E7CF")

    static let brass = LinearGradient.vertical(Color(hex: "#F3DFA2"), Color(hex: "#C9A44C"))
    static let brassEdge = Color(hex: "#5A4418")
    static let brassText = Color(hex: "#3B2A0A")
    static let brassScrew = Color(hex: "#7A5A1E")

    static let amber = LinearGradient.gel("#FFDD94", "#F7B23B", "#EE9F1C", "#E08E0A")
    static let amberText = Color(hex: "#3B2200")
    static let amberEdge = Color(hex: "#7A4A05")
    static let purple = LinearGradient.gel("#C99AF0", "#9B59D6", "#8743C7", "#7434B3")
    static let purpleEdge = Color(hex: "#3E1670")
    static let whiteGel = LinearGradient.gel("#FEFEFE", "#ECECEC", "#DADADA", "#C9C9C9")
    static let greenGel = LinearGradient.gel("#7FD45A", "#3FA51C", "#2F8F12", "#267A0C")
    static let goldText = LinearGradient(
        stops: [
            .init(color: Color(hex: "#FFF4CC"), location: 0),
            .init(color: Color(hex: "#F7C35C"), location: 0.48),
            .init(color: Color(hex: "#D98A1E"), location: 0.52),
            .init(color: Color(hex: "#FFD27A"), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let steel = Color(hex: "#55595F")
    static let ink = Color(hex: "#2B2D31")
    static let label = Color(hex: "#E4E7EC")
    static let heroText = Color(hex: "#F6EEE4")
    static let heroMeta = Color(hex: "#E9DCCB")
    static let paper = LinearGradient.vertical(.white, Color(hex: "#EFEBE2"))
    static let paperEdge = Color(hex: "#1E2127")
    static let paperPage = Color(hex: "#ECE8DE")
    static let polaroid = Color(hex: "#FBF8EF")
    static let collageGap = Color(hex: "#15171C")
    static let episodeNumber = Color(hex: "#6B6E75")
    static let episodeText = Color(hex: "#4A4D55")
    static let heroScrim = Color(red: 16 / 255, green: 8 / 255, blue: 26 / 255)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = switch weight {
        case .bold, .heavy, .black, .semibold:
            "HelveticaNeue-Bold"
        case .medium:
            "HelveticaNeue-Medium"
        default:
            "HelveticaNeue"
        }

        return .custom(name, size: size)
    }
}

enum Y2K {

    static let navy = Color(hex: "#0B1E4A")
    static let muted = Color(hex: "#3F5178")
    static let lime = Color(hex: "#C6FF4D")
    static let stripeLight = Color(hex: "#E9F0FA")
    static let stripeDark = Color(hex: "#DCE6F4")

    static let chrome = LinearGradient(
        stops: [
            .init(color: .white, location: 0),
            .init(color: Color(hex: "#DCE3EE"), location: 0.45),
            .init(color: Color(hex: "#AEB9CA"), location: 0.5),
            .init(color: Color(hex: "#D5DDE8"), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let chromeEdge = Color(hex: "#7C8AA0")
    static let chromeText = LinearGradient(
        stops: [
            .init(color: .white, location: 0),
            .init(color: Color(hex: "#E8EEF6"), location: 0.44),
            .init(color: Color(hex: "#8A96AC"), location: 0.5),
            .init(color: Color(hex: "#DCE3EE"), location: 0.7),
            .init(color: .white, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let shadow = Color(red: 40 / 255, green: 70 / 255, blue: 130 / 255)
    static let innerGlow = Color(red: 120 / 255, green: 170 / 255, blue: 1)
    static let ring = Color(hex: "#AEB9CA")

    static let silver = Color(hex: "#C3CEDD")
    static let silverEdge = Color(hex: "#6E7C94")
    static let pink = Color(hex: "#FF8FC2")
    static let pinkEdge = Color(hex: "#A8196A")
    static let pinkDeep = Color(hex: "#E0559A")
    static let limeGel = Color(hex: "#A6EE2B")
    static let limeEdge = Color(hex: "#4E8A00")
    static let yellow = Color(hex: "#FFD23F")
    static let yellowEdge = Color(hex: "#9A7A00")

    static let gloss = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.85), location: 0),
            .init(color: .white.opacity(0.3), location: 0.46),
            .init(color: .white.opacity(0), location: 0.54),
            .init(color: .white.opacity(0.3), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let darkGloss = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.28), location: 0),
            .init(color: .white.opacity(0.06), location: 0.46),
            .init(color: .white.opacity(0), location: 0.54),
            .init(color: .white.opacity(0.1), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func glass(_ top: Double, _ bottom: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(top), location: 0),
                .init(color: .white.opacity(bottom), location: 0.46),
                .init(color: .white.opacity(0), location: 0.48),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let blueOrb = RadialGradient(
        stops: [
            .init(color: .white, location: 0),
            .init(color: Color(hex: "#CDE9FF"), location: 0.3),
            .init(color: Color(hex: "#7CC0FF"), location: 0.65),
            .init(color: Color(hex: "#4FA3F5"), location: 1),
        ],
        center: UnitPoint(x: 0.5, y: 0.2),
        startRadius: 0,
        endRadius: 41
    )
    static let blueOrbEdge = Color(hex: "#1447A8")
    static let pinkOrb = RadialGradient(
        stops: [
            .init(color: .white, location: 0),
            .init(color: Color(hex: "#FFD9EC"), location: 0.3),
            .init(color: pink, location: 0.65),
            .init(color: pinkDeep, location: 1),
        ],
        center: UnitPoint(x: 0.5, y: 0.2),
        startRadius: 0,
        endRadius: 41
    )

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = switch weight {
        case .semibold, .bold, .heavy, .black:
            "Kanit-SemiBold"
        case .medium:
            "Kanit-Medium"
        default:
            "Kanit-Regular"
        }

        return .custom(name, size: size)
    }

    static func title(_ size: CGFloat) -> Font {
        .custom("Audiowide-Regular", size: size)
    }
}

extension View {

    func y2kGel<S: InsettableShape>(_ base: Color, edge: Color, in shape: S, isDark: Bool = false) -> some View {
        background {
            shape
                .fill(base)
                .overlay {
                    (isDark ? Y2K.darkGloss : Y2K.gloss)
                        .clipShape(shape)
                }
        }
        .overlay {
            shape.strokeBorder(edge)
        }
    }

    func y2kOrb(_ fill: RadialGradient, edge: Color, size: CGFloat = 44) -> some View {
        frame(width: size, height: size)
            .background(fill, in: .circle)
            .overlay {
                Circle().strokeBorder(edge)
            }
    }
}

struct SparkleShape: Shape {

    func path(in rect: CGRect) -> Path {
        let w = rect.width / 24
        let h = rect.height / 24
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + 12 * w, y: rect.minY + 2 * h))
        path.addLine(to: CGPoint(x: rect.minX + 14.2 * w, y: rect.minY + 9.8 * h))
        path.addLine(to: CGPoint(x: rect.minX + 22 * w, y: rect.minY + 12 * h))
        path.addLine(to: CGPoint(x: rect.minX + 14.2 * w, y: rect.minY + 14.2 * h))
        path.addLine(to: CGPoint(x: rect.minX + 12 * w, y: rect.minY + 22 * h))
        path.addLine(to: CGPoint(x: rect.minX + 9.8 * w, y: rect.minY + 14.2 * h))
        path.addLine(to: CGPoint(x: rect.minX + 2 * w, y: rect.minY + 12 * h))
        path.addLine(to: CGPoint(x: rect.minX + 9.8 * w, y: rect.minY + 9.8 * h))
        path.closeSubpath()

        return path
    }
}

struct StripeTexture: View {

    var body: some View {
        Canvas { context, size in
            var stripes = Path()
            for y in stride(from: 2, to: size.height, by: 4) {
                stripes.addRect(CGRect(x: 0, y: y, width: size.width, height: 2))
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Y2K.stripeLight))
            context.fill(stripes, with: .color(Y2K.stripeDark))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum GameUI {

    static let outline = Color(hex: "#220B4A")
    static let page = Color(hex: "#7A3FE0")
    static let panel = Color(hex: "#3A1878")
    static let well = Color(hex: "#2A1060")
    static let pink = Color(hex: "#FF5FA2")
    static let lilac = Color(hex: "#B58CFF")
    static let paleLilac = Color(hex: "#C9B8E8")
    static let yellow = Color(hex: "#FFD23F")
    static let orange = Color(hex: "#FF8A1F")
    static let green = Color(hex: "#4CD137")
    static let red = Color(hex: "#FF5A4D")
    static let mutedText = Color(hex: "#E2D4FF")
    static let coin = RadialGradient(
        stops: [
            .init(color: Color(hex: "#FFF3B0"), location: 0),
            .init(color: Color(hex: "#FFC531"), location: 0.6),
            .init(color: Color(hex: "#E09A00"), location: 1),
        ],
        center: UnitPoint(x: 0.35, y: 0.3),
        startRadius: 0,
        endRadius: 12
    )
    static let coinEdge = Color(hex: "#8A5A00")
    static let ringColors: [Color] = [yellow, pink, green, orange, lilac]

    static func title(_ size: CGFloat) -> Font {
        .custom("LilitaOne", size: size)
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let name = switch weight {
        case .black, .heavy:
            "Nunito-Black"
        case .bold:
            "Nunito-Bold"
        default:
            "Nunito-ExtraBold"
        }

        return .custom(name, size: size)
    }
}

extension View {

    func gameOutline(_ width: CGFloat, drop: CGFloat = 0) -> some View {
        shadow(color: GameUI.outline, radius: 0, x: -width, y: -width)
            .shadow(color: GameUI.outline, radius: 0, x: width, y: -width)
            .shadow(color: GameUI.outline, radius: 0, x: -width, y: width)
            .shadow(color: GameUI.outline, radius: 0, x: width, y: width)
            .shadow(color: GameUI.outline, radius: 0, x: 0, y: width + drop)
    }

    func gameChunky<S: InsettableShape>(
        _ fill: Color,
        in shape: S,
        outline: CGFloat = 3,
        drop: CGFloat = 4,
        isPressed: Bool = false
    ) -> some View {
        background {
            ZStack {
                if !isPressed, drop > 0 {
                    shape
                        .fill(GameUI.outline)
                        .offset(y: drop)
                }

                shape
                    .fill(fill)
                    .overlay(alignment: .top) {
                        Color.white.opacity(isPressed ? 0 : 0.45)
                            .frame(height: 2)
                            .padding(.top, outline)
                    }
                    .overlay(alignment: .top) {
                        Color.black.opacity(isPressed ? 0.25 : 0)
                            .frame(height: 3)
                            .padding(.top, outline)
                    }
                    .overlay(alignment: .bottom) {
                        Color.black.opacity(isPressed ? 0 : 0.2)
                            .frame(height: 4)
                            .padding(.bottom, outline)
                    }
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(GameUI.outline, lineWidth: outline)
                    }
            }
        }
    }
}

struct StarburstShape: Shape {

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: 20, y: 1), .init(x: 25, y: 8), .init(x: 33.4, y: 6.6), .init(x: 32, y: 15),
            .init(x: 39, y: 20), .init(x: 32, y: 25), .init(x: 33.4, y: 33.4), .init(x: 25, y: 32),
            .init(x: 20, y: 39), .init(x: 15, y: 32), .init(x: 6.6, y: 33.4), .init(x: 8, y: 25),
            .init(x: 1, y: 20), .init(x: 8, y: 15), .init(x: 6.6, y: 6.6), .init(x: 15, y: 8),
        ]
        var path = Path()

        path.addLines(points.map { point in
            CGPoint(
                x: rect.minX + point.x / 40 * rect.width,
                y: rect.minY + point.y / 40 * rect.height
            )
        })
        path.closeSubpath()

        return path
    }
}

struct DiagonalStripes: View {

    var body: some View {
        Canvas { context, size in
            var stripes = Path()
            let period: CGFloat = 48 * 2.squareRoot()
            let band: CGFloat = 24 * 2.squareRoot()
            var x: CGFloat = -size.height

            while x < size.width {
                stripes.move(to: CGPoint(x: x, y: 0))
                stripes.addLine(to: CGPoint(x: x + size.height, y: size.height))
                stripes.addLine(to: CGPoint(x: x + size.height + band, y: size.height))
                stripes.addLine(to: CGPoint(x: x + band, y: 0))
                stripes.closeSubpath()
                x += period
            }

            context.fill(stripes, with: .color(.white.opacity(0.06)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {

    func engraved(_ opacity: Double = 0.7) -> some View {
        shadow(color: .black.opacity(opacity), radius: 0, x: 0, y: -1)
    }
}

struct LinenTexture: View {

    var body: some View {
        Canvas { context, size in
            var rows = Path()
            for y in stride(from: 0, to: size.height, by: 3) {
                rows.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
            }
            context.fill(rows, with: .color(.white.opacity(0.035)))

            var columns = Path()
            for x in stride(from: 0, to: size.width, by: 3) {
                columns.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
            }
            context.fill(columns, with: .color(.black.opacity(0.08)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ThemedPageBackground: View {

    @Environment(\.appTheme)
    private var theme

    let isGlowing: Bool

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            ZStack {
                if isGlowing {
                    EllipticalGradient(
                        colors: [Skeuo.glowTop, Skeuo.glowBottom],
                        center: .top,
                        endRadiusFraction: 2
                    )
                } else {
                    Skeuo.linen
                }

                LinenTexture()
            }
            .ignoresSafeArea()
        case .y2k:
            ZStack {
                StripeTexture()

                EllipticalGradient(
                    stops: [
                        .init(color: .white.opacity(0.9), location: 0),
                        .init(color: .white.opacity(0), location: 0.55),
                    ],
                    center: UnitPoint(x: 0.5, y: -0.1),
                    endRadiusFraction: 2
                )
            }
            .ignoresSafeArea()        case .gameUI2:
            ZStack {
                GameUI.page

                DiagonalStripes()
            }
            .ignoresSafeArea()
        }
    }
}
