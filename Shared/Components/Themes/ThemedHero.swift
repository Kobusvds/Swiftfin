//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

enum ThemedHeroLayout {

    static let y2kInset: CGFloat = 22
    static let y2kStripInset: CGFloat = 14
}

extension AppTheme {

    var heroActionHeight: CGFloat {
        switch self {
        case .default:
            44
        case .skeuo:
            68
        case .y2k:
            54
        case .gameUI2:
            60
        }
    }

    var heroActionSpacing: CGFloat {
        switch self {
        case .default:
            8
        case .skeuo, .y2k, .gameUI2:
            10
        }
    }

    var heroColumnWidth: CGFloat {
        switch self {
        case .gameUI2:
            440
        default:
            300
        }
    }
}

struct ThemedHeroButtonLabel: View {

    @Environment(\.appTheme)
    private var theme
    @Environment(\.isSelected)
    private var isSelected

    let configuration: LabelStyleConfiguration
    let isPrimary: Bool
    let isFavorite: Bool
    let activeColor: Color?

    private var iconColor: Color {
        if isSelected, let activeColor {
            return activeColor
        }

        return Skeuo.ink
    }

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            let size: CGFloat = isPrimary ? 68 : 54

            Label(configuration)
                .labelStyle(.iconOnly)
                .font(.system(size: isPrimary ? 26 : 20, weight: .bold))
                .foregroundStyle(isPrimary ? .white : iconColor)
                .shadow(color: .black.opacity(isPrimary ? 0.35 : 0), radius: 0, y: -1)
                .frame(maxWidth: size, maxHeight: size)
                .background(isPrimary ? Skeuo.purple : Skeuo.whiteGel, in: .circle)
                .overlay(alignment: .top) {
                    Circle()
                        .trim(from: 0.6, to: 0.9)
                        .stroke(.white.opacity(isPrimary ? 0.6 : 1), lineWidth: 1)
                        .padding(1)
                }
                .overlay {
                    Circle()
                        .strokeBorder(isPrimary ? Skeuo.purpleEdge : Skeuo.steel)
                }
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(isPrimary ? 0.6 : 0.55), radius: 3.5, y: 2)
                .contentShape(.circle)
        case .y2k:
            if isPrimary {
                HStack(spacing: 8) {
                    configuration.icon
                        .font(.system(size: 18, weight: .heavy))

                    configuration.title
                        .font(Y2K.font(18, .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Y2K.navy)
                .shadow(color: .white.opacity(0.6), radius: 0, y: 1)
                .padding(.leading, 20)
                .padding(.trailing, 26)
                .frame(height: 54)
                .y2kGel(Y2K.limeGel, edge: Y2K.limeEdge, in: .capsule)
                .shadow(color: Y2K.shadow.opacity(0.4), radius: 3, y: 2)
                .fixedSize()
                .contentShape(.capsule)
            } else {
                Label(configuration)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(isSelected && !isFavorite ? (activeColor ?? Y2K.navy) : Y2K.navy)
                    .frame(width: 50, height: 50)
                    .y2kGel(
                        isFavorite ? Y2K.pink : Y2K.silver,
                        edge: isFavorite ? Y2K.pinkEdge : Y2K.silverEdge,
                        in: .circle
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: Y2K.shadow.opacity(0.35), radius: 2.5, y: 2)
                    .contentShape(.circle)
            }
        case .gameUI2:
            if isPrimary {
                HStack(spacing: 8) {
                    configuration.icon
                        .font(.system(size: 20, weight: .black))
                        .gameOutline(1)

                    HStack(spacing: 0) {
                        configuration.title
                        Text(verbatim: "!")
                    }
                    .font(GameUI.title(24))
                    .lineLimit(1)
                    .gameOutline(1, drop: 1)
                }
                .foregroundStyle(.white)
                .padding(.leading, 18)
                .padding(.trailing, 24)
                .frame(height: 56)
                .gameChunky(GameUI.orange, in: RoundedRectangle(cornerRadius: 14), drop: 5)
                .fixedSize()
                .contentShape(.rect(cornerRadius: 14))
            } else {
                Label(configuration)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(isSelected && !isFavorite ? (activeColor ?? GameUI.outline) : GameUI.outline)
                    .frame(width: 54, height: 52)
                    .gameChunky(isFavorite ? GameUI.pink : GameUI.lilac, in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(.rect(cornerRadius: 14))
            }
        }
    }
}

struct ThemedBadgeLabel: View {

    @Environment(\.appTheme)
    private var theme

    let configuration: LabelStyleConfiguration
    let isFilled: Bool
    var isRating: Bool = false

    private var gameColor: Color {
        if isFilled {
            GameUI.orange
        } else if isRating {
            GameUI.yellow
        } else {
            GameUI.paleLilac
        }
    }

    private var y2kColors: (fill: Color, edge: Color) {
        if isFilled {
            (Y2K.limeGel, Y2K.limeEdge)
        } else if isRating {
            (Y2K.yellow, Y2K.yellowEdge)
        } else {
            (Y2K.silver, Y2K.silverEdge)
        }
    }

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            HStack(spacing: 4) {
                configuration.icon
                    .foregroundStyle(isFilled ? Skeuo.amberText : Color(hex: "#E08E0A"))

                configuration.title
            }
            .font(Skeuo.font(12, .bold))
            .foregroundStyle(isFilled ? Skeuo.amberText : Skeuo.ink)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(isFilled ? Skeuo.amber : Skeuo.whiteGel, in: .rect(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isFilled ? Skeuo.amberEdge : Skeuo.steel)
            }
        case .y2k:
            HStack(spacing: 4) {
                configuration.icon

                configuration.title
            }
            .font(Y2K.font(12.5, .semibold))
            .foregroundStyle(Y2K.navy)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .y2kGel(y2kColors.fill, edge: y2kColors.edge, in: .capsule)
        case .gameUI2:
            HStack(spacing: 5) {
                if isRating {
                    Circle()
                        .fill(GameUI.coin)
                        .overlay {
                            Circle()
                                .strokeBorder(GameUI.coinEdge, lineWidth: 2)
                        }
                        .frame(width: 18, height: 18)
                } else {
                    configuration.icon
                }

                configuration.title
            }
            .font(GameUI.title(14))
            .foregroundStyle(GameUI.outline)
            .padding(.leading, isRating ? 4 : 10)
            .padding(.trailing, 10)
            .frame(height: 26)
            .background(gameColor, in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(GameUI.outline, lineWidth: 2)
            }
        }
    }
}

struct ThemedHeroTitle: View {

    @Environment(\.appTheme)
    private var theme

    let title: String

    var body: some View {
        switch theme {
        case .default:
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
        case .skeuo:
            Text(title.localizedUppercase)
                .font(.custom("CinzelDecorative-Black", size: 54))
                .lineSpacing(-8)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Skeuo.goldText)
                .shadow(color: Color(hex: "#4A1A10"), radius: 0, y: 2)
                .shadow(color: .black.opacity(0.6), radius: 5, y: 6)
        case .y2k:
            Text(title.localizedUppercase)
                .font(Y2K.title(56))
                .kerning(3)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Y2K.chromeText)
                .shadow(color: Y2K.navy, radius: 0, y: 2)
                .shadow(color: Y2K.pink.opacity(0.7), radius: 6)
        case .gameUI2:
            Text(title)
                .font(GameUI.title(76))
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.leading)
                .foregroundStyle(GameUI.yellow)
                .gameOutline(3, drop: 4)
        }
    }
}

extension View {

    func themedHeroArtwork(bottomColor: Color) -> some View {
        modifier(ThemedHeroArtworkModifier(bottomColor: bottomColor))
    }
}

private struct ThemedHeroArtworkModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    let bottomColor: Color

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content
                .bottomEdgeGradient(bottomColor: bottomColor)
        case .skeuo:
            content
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: Skeuo.heroScrim.opacity(0), location: 0.5),
                            .init(color: Skeuo.heroScrim.opacity(0.78), location: 0.78),
                            .init(color: Skeuo.heroScrim.opacity(0.96), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .top) {
                    LinearGradient.vertical(.black.opacity(0.5), .clear)
                        .frame(height: 10)
                }
                .clipped()
                .shadow(color: .black.opacity(0.6), radius: 4, y: 3)
        case .y2k:
            content
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.22), location: 0),
                            .init(color: .white.opacity(0.04), location: 0.48),
                            .init(color: .white.opacity(0), location: 0.5),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        case .gameUI2:
            content
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: GameUI.outline.opacity(0), location: 0.55),
                            .init(color: GameUI.outline.opacity(0.55), location: 0.8),
                            .init(color: GameUI.outline.opacity(0.8), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }
}

extension View {

    func themedHeroPanel() -> some View {
        modifier(ThemedHeroPanelModifier())
    }

    func themedHeroStrip() -> some View {
        modifier(ThemedHeroStripModifier())
    }

    func themedHeroDetails() -> some View {
        modifier(ThemedHeroDetailsModifier())
    }
}

private struct ThemedHeroDetailsModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    func body(content: Content) -> some View {
        switch theme {
        case .gameUI2:
            content
                .padding(.top, 16)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .gameChunky(GameUI.well, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    Text(L10n.story)
                        .font(GameUI.title(14))
                        .foregroundStyle(GameUI.outline)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(GameUI.yellow, in: .rect(cornerRadius: 9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(GameUI.outline, lineWidth: 3)
                        }
                        .offset(x: 14, y: -16)
                        .accessibilityHidden(true)
                }
                .padding(.top, 16)
        default:
            content
        }
    }
}

private struct ThemedHeroPanelModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    func body(content: Content) -> some View {
        switch theme {
        case .y2k:
            content
                .clipShape(.rect(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.white, lineWidth: 3)
                }
                .shadow(color: Y2K.shadow.opacity(0.35), radius: 11, y: 8)
                .padding(.horizontal, ThemedHeroLayout.y2kInset)
                .padding(.top, 12)
        case .gameUI2:
            content
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(GameUI.outline, lineWidth: 4)
                }
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(GameUI.outline)
                        .offset(y: 6)
                }
                .padding(.horizontal, ThemedHeroLayout.y2kInset)
                .padding(.top, 14)
                .padding(.bottom, 6)
        default:
            content
        }
    }
}

private struct ThemedHeroStripModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    func body(content: Content) -> some View {
        switch theme {
        case .y2k:
            content
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(minHeight: 124)
                .background {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            LinearGradient.vertical(.white.opacity(0.86), .white.opacity(0.66))
                        }
                        .overlay(alignment: .bottom) {
                            LinearGradient.vertical(Y2K.innerGlow.opacity(0), Y2K.innerGlow.opacity(0.2))
                                .frame(height: 22)
                        }
                        .clipShape(.rect(cornerRadius: 22))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.white.opacity(0.95), lineWidth: 2)
                        .allowsHitTesting(false)
                }
                .shadow(color: Y2K.shadow.opacity(0.28), radius: 6, y: 4)
        default:
            content
        }
    }
}
