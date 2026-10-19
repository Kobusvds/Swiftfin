//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

enum ThemedPosterKind {

    case poster
    case collection
    case person
}

extension View {

    func themedPosterGloss(_ displayType: PosterDisplayType) -> some View {
        modifier(ThemedPosterGlossModifier(displayType: displayType))
    }

    func themedPosterFrame(_ kind: ThemedPosterKind, ringIndex: Int = 0) -> some View {
        modifier(ThemedPosterFrameModifier(kind: kind, ringIndex: ringIndex))
    }
}

private struct ThemedPosterGlossModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    let displayType: PosterDisplayType

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content
        case .skeuo:
            content.overlay {
                LinearGradient.gloss115
                    .posterCornerRadius(displayType)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        case .y2k:
            content.overlay {
                (displayType == .landscape ? Y2K.glass(0.32, 0.06) : Y2K.glass(0.4, 0.1))
                    .posterCornerRadius(displayType)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        case .gameUI2:
            content.overlay {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.2), location: 0),
                        .init(color: .white.opacity(0), location: 0.4),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .posterCornerRadius(displayType)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

private struct ThemedPosterFrameModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme
    @Environment(\.isOnPosterShelf)
    private var isOnPosterShelf

    let kind: ThemedPosterKind
    var ringIndex: Int = 0

    private var ringColor: Color {
        GameUI.ringColors[ringIndex % GameUI.ringColors.count]
    }

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content.subtleShadow()
        case .skeuo:
            skeuo(content)
        case .y2k:
            y2k(content)
        case .gameUI2:
            gameUI(content)
        }
    }

    @ViewBuilder
    private func gameUI(_ content: Content) -> some View {
        switch kind {
        case .poster:
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(GameUI.outline, lineWidth: 3)
                        .allowsHitTesting(false)
                }
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GameUI.outline)
                        .offset(y: 4)
                }
        case .collection:
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(GameUI.outline, lineWidth: 3)
                        .allowsHitTesting(false)
                }
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GameUI.paleLilac)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(GameUI.outline, lineWidth: 3)
                            }
                            .offset(x: 6, y: -6)

                        RoundedRectangle(cornerRadius: 12)
                            .fill(GameUI.outline)
                            .offset(y: 4)
                    }
                }
        case .person:
            content
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: 8)
                        .overlay {
                            Circle()
                                .strokeBorder(GameUI.outline, lineWidth: 4)
                        }
                }
                .background {
                    Circle()
                        .fill(GameUI.outline)
                        .offset(y: 4)
                }
        }
    }

    @ViewBuilder
    private func y2k(_ content: Content) -> some View {
        switch kind {
        case .poster:
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white, lineWidth: 3)
                        .allowsHitTesting(false)
                }
                .shadow(color: Y2K.shadow.opacity(0.35), radius: 7, y: 6)
        case .collection:
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white, lineWidth: 3)
                        .allowsHitTesting(false)
                }
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.95))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Y2K.ring)
                        }
                        .padding(2)
                        .offset(x: 5, y: -5)
                }
                .shadow(color: Y2K.shadow.opacity(0.35), radius: 7, y: 6)
        case .person:
            content
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(LinearGradient.vertical(.white.opacity(0.7), .white.opacity(0)))
                        .frame(height: 44)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .allowsHitTesting(false)
                }
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                }
                .padding(1)
                .background(Y2K.ring, in: .circle)
                .shadow(color: Y2K.shadow.opacity(0.35), radius: 5, y: 4)
        }
    }

    @ViewBuilder
    private func skeuo(_ content: Content) -> some View {
        let framed = Group {
            switch kind {
            case .poster:
                content
                    .shadow(color: .black.opacity(0.6), radius: 5, y: 6)
            case .collection:
                content
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Skeuo.paperPage.opacity(0.28))
                                .offset(x: 6, y: -6)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Skeuo.paperPage.opacity(0.55))
                                .offset(x: 3, y: -3)
                        }
                    }
                    .shadow(color: .black.opacity(0.6), radius: 5, y: 6)
            case .person:
                content
                    .padding([.top, .horizontal], 7)
                    .padding(.bottom, 27)
                    .background(Skeuo.polaroid)
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 3)
            }
        }

        if isOnPosterShelf, kind != .person {
            framed
                .background(alignment: .bottom) {
                    SkeuoShelf()
                        .padding(.horizontal, -EdgeInsets.itemSpacing / 2)
                        .offset(y: 12)
                }
                .padding(.bottom, 12)
        } else {
            framed
        }
    }
}

struct SkeuoShelf: View {

    var body: some View {
        VStack(spacing: 0) {
            Color.white.opacity(0.75)
                .frame(height: 1)

            LinearGradient.vertical(.white.opacity(0.32), .white.opacity(0.12))
                .frame(height: 5)

            LinearGradient.vertical(
                Color(red: 222 / 255, green: 240 / 255, blue: 236 / 255).opacity(0.8),
                Color(red: 150 / 255, green: 178 / 255, blue: 174 / 255).opacity(0.7)
            )
            .frame(height: 10)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 12)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ThemedUnplayedMarker: View {

    @Environment(\.appTheme)
    private var theme

    let count: Int?

    private var title: String {
        if let count, count > 0 {
            count.description
        } else {
            L10n.new.localizedUppercase
        }
    }

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            Color.clear
                .frame(width: 36, height: 40)
                .overlay {
                    Text(title)
                        .font(Skeuo.font(9, .bold))
                        .kerning(1.1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 0, y: -1)
                        .frame(width: 84, height: 16)
                        .background(Skeuo.purple)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                        .rotationEffect(.degrees(45))
                        .fixedSize()
                }
        case .y2k:
            Text(title)
                .font(Y2K.font(10, .semibold))
                .kerning(0.6)
                .foregroundStyle(Y2K.navy)
                .padding(.horizontal, 7)
                .frame(height: 18)
                .y2kGel(Y2K.pink, edge: Y2K.pinkEdge, in: .capsule)
                .padding(6)
        case .gameUI2:
            EmptyView()
        }
    }
}

struct ThemedPlayedMarker: View {

    @Environment(\.appTheme)
    private var theme

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Skeuo.greenGel, in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
                .padding(6)
        case .y2k:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Y2K.navy)
                .frame(width: 28, height: 28)
                .y2kGel(Y2K.limeGel, edge: Y2K.limeEdge, in: .circle)
                .shadow(color: Y2K.navy.opacity(0.45), radius: 2, y: 2)
                .padding(7)
        case .gameUI2:
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))

                Text(L10n.watched)
                    .font(GameUI.title(12))
            }
            .foregroundStyle(GameUI.outline)
            .padding(.leading, 5)
            .padding(.trailing, 8)
            .frame(height: 26)
            .background(GameUI.green, in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(GameUI.outline, lineWidth: 3)
            }
            .padding(6)
        }
    }
}

extension View {

    func themedEpisodeCard(item: BaseItemDto? = nil) -> some View {
        modifier(ThemedEpisodeCardModifier(item: item))
    }

    func themedEpisodeStill(number: Int? = nil) -> some View {
        modifier(ThemedEpisodeStillModifier(number: number))
    }
}

private struct ThemedEpisodeCardModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    let item: BaseItemDto?

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content
        case .skeuo:
            content
                .padding(8)
                .background(Skeuo.paper, in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Skeuo.paperEdge)
                }
                .shadow(color: .black.opacity(0.55), radius: 3, y: 3)
                .environment(\.colorScheme, .light)
        case .y2k:
            content
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient.vertical(.white.opacity(0.96), .white.opacity(0.66)))
                        .overlay(alignment: .bottom) {
                            LinearGradient.vertical(Y2K.innerGlow.opacity(0), Y2K.innerGlow.opacity(0.2))
                                .frame(height: 22)
                        }
                        .clipShape(.rect(cornerRadius: 20))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white, lineWidth: 2)
                        .allowsHitTesting(false)
                }
                .shadow(color: Y2K.shadow.opacity(0.28), radius: 6, y: 4)
        case .gameUI2:
            content
                .padding(8)
                .gameChunky(GameUI.panel, in: RoundedRectangle(cornerRadius: 14), drop: 4)
                .overlay(alignment: .topTrailing) {
                    if let item {
                        ThemedOverhangMarker(item: item, size: 44)
                            .offset(x: 12, y: -12)
                    }
                }
        }
    }
}

private struct ThemedEpisodeStillModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    let number: Int?

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content
        case .skeuo:
            content
                .themedPosterGloss(.landscape)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Skeuo.steel)
                        .allowsHitTesting(false)
                }
        case .y2k:
            content
                .themedPosterGloss(.landscape)
        case .gameUI2:
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(GameUI.outline, lineWidth: 3)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if let number {
                        Text(number.description)
                            .font(GameUI.title(15))
                            .foregroundStyle(GameUI.outline)
                            .frame(width: 30, height: 30)
                            .background(GameUI.yellow, in: .circle)
                            .overlay {
                                Circle()
                                    .strokeBorder(GameUI.outline, lineWidth: 3)
                            }
                            .padding(6)
                            .accessibilityHidden(true)
                    }
                }
        }
    }
}

struct ThemedOverhangMarker: View {

    @Environment(\.appTheme)
    private var theme
    @Environment(\.posterConfiguration)
    private var posterConfiguration

    let item: BaseItemDto
    var size: CGFloat = 40

    private var title: String {
        if posterConfiguration.unplayedStyle == .count, let count = item.userData?.unplayedItemCount, count > 0 {
            count.description
        } else {
            L10n.new.localizedUppercase + "!"
        }
    }

    var body: some View {
        if theme == .gameUI2, item.showsUnplayedIndicator(posterConfiguration.indicators) {
            StarburstShape()
                .fill(GameUI.yellow)
                .overlay {
                    StarburstShape()
                        .stroke(GameUI.outline, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }
                .overlay {
                    Text(title)
                        .font(GameUI.title(size * 0.25))
                        .foregroundStyle(GameUI.outline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, size * 0.15)
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-12))
                .allowsHitTesting(false)
                .accessibilityLabel(L10n.unplayed)
        }
    }
}
