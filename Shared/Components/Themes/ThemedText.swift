//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

enum ThemedTextRole {

    case posterTitle
    case sectionHeader
    case sectionAccessory
    case heroBody
    case heroMeta
    case episodeLocator
    case episodeTitle
    case episodeBody
}

extension View {

    func themedText(_ role: ThemedTextRole, defaultFont: Font) -> some View {
        modifier(ThemedTextModifier(role: role, defaultFont: defaultFont))
    }
}

private struct ThemedTextModifier: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    let role: ThemedTextRole
    let defaultFont: Font

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content.font(defaultFont)
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
        switch role {
        case .posterTitle:
            content
                .font(GameUI.font(13, .semibold))
                .foregroundStyle(.white)
                .shadow(color: GameUI.outline, radius: 0, y: 2)
        case .sectionHeader:
            content
                .font(GameUI.title(28))
                .foregroundStyle(GameUI.yellow, GameUI.yellow)
                .gameOutline(2, drop: 2)
        case .sectionAccessory:
            content
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(GameUI.yellow, GameUI.yellow)
                .shadow(color: GameUI.outline, radius: 0, y: 2)
        case .heroBody:
            content
                .font(GameUI.font(14.5))
                .foregroundStyle(.white)
        case .heroMeta:
            content
                .font(GameUI.font(14, .semibold))
                .foregroundStyle(GameUI.mutedText)
        case .episodeLocator:
            content
                .font(GameUI.font(12, .semibold))
                .foregroundStyle(GameUI.yellow)
        case .episodeTitle:
            content
                .font(GameUI.font(16, .black))
                .foregroundStyle(.white)
        case .episodeBody:
            content
                .font(GameUI.font(12.5))
                .foregroundStyle(GameUI.mutedText)
        }
    }

    @ViewBuilder
    private func y2k(_ content: Content) -> some View {
        switch role {
        case .posterTitle:
            content
                .font(Y2K.font(13, .medium))
                .foregroundStyle(Y2K.navy)
        case .sectionHeader:
            HStack(spacing: 8) {
                SparkleShape()
                    .fill(Y2K.pinkDeep)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                content
                    .font(Y2K.title(22))
                    .kerning(0.44)
                    .foregroundStyle(Y2K.navy, Y2K.navy)
            }
        case .sectionAccessory:
            content
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Y2K.pinkDeep, Y2K.pinkDeep)
        case .heroBody:
            content
                .font(Y2K.font(14.5))
                .foregroundStyle(Y2K.navy)
        case .heroMeta:
            content
                .font(Y2K.font(14))
                .foregroundStyle(Y2K.muted)
        case .episodeLocator:
            content
                .font(Y2K.font(12))
                .foregroundStyle(Y2K.muted)
        case .episodeTitle:
            content
                .font(Y2K.font(16, .semibold))
                .foregroundStyle(Y2K.navy)
        case .episodeBody:
            content
                .font(Y2K.font(12.5))
                .foregroundStyle(Y2K.muted)
        }
    }

    @ViewBuilder
    private func skeuo(_ content: Content) -> some View {
        switch role {
        case .posterTitle:
            content
                .font(Skeuo.font(13, .bold))
                .foregroundStyle(Skeuo.label)
                .engraved(0.7)
        case .sectionHeader, .sectionAccessory:
            content
                .font(Skeuo.font(22, .bold))
                .foregroundStyle(Skeuo.label, Skeuo.label)
                .engraved(0.75)
        case .heroBody:
            content
                .font(Skeuo.font(15))
                .foregroundStyle(Skeuo.heroText)
                .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
        case .heroMeta:
            content
                .font(Skeuo.font(14))
                .foregroundStyle(Skeuo.heroMeta)
                .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
        case .episodeLocator:
            content
                .font(Skeuo.font(12))
                .foregroundStyle(Skeuo.episodeNumber)
        case .episodeTitle:
            content
                .font(Skeuo.font(16, .bold))
                .foregroundStyle(Skeuo.ink)
        case .episodeBody:
            content
                .font(Skeuo.font(12.5))
                .foregroundStyle(Skeuo.episodeText)
        }
    }
}
