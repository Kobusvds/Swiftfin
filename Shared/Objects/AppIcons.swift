//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

enum AppIcon: String, CaseIterable, Displayable, Identifiable {

    case nextflixSunset
    case nextflixSakura
    case nextflixNeko
    case nextflixManga
    case nextflixPrism
    case nextflixGlass

    case jellyfin
    case red
    case orange
    case yellow
    case green
    case blue

    var iconName: String {
        switch self {
        case .nextflixSunset:
            "AppIcon-nextflix-sunset"
        case .nextflixSakura:
            "AppIcon-nextflix-sakura"
        case .nextflixNeko:
            "AppIcon-nextflix-neko"
        case .nextflixManga:
            "AppIcon-nextflix-manga"
        case .nextflixPrism:
            "AppIcon-nextflix-prism"
        case .nextflixGlass:
            "AppIcon-nextflix-glass"
        case .jellyfin, .red, .orange, .yellow, .green, .blue:
            "AppIcon-dark-" + rawValue
        }
    }

    var id: String {
        iconName
    }

    var isNextflix: Bool {
        rawValue.hasPrefix("nextflix")
    }

    var alternateIconName: String? {
        self == .blue ? nil : iconName
    }

    var displayTitle: String {
        switch self {
        case .nextflixSunset:
            "Sunset"
        case .nextflixSakura:
            "Sakura"
        case .nextflixNeko:
            "Neko"
        case .nextflixManga:
            "Manga"
        case .nextflixPrism:
            "Prism"
        case .nextflixGlass:
            "Glass"
        case .jellyfin:
            L10n.jellyfin
        case .red:
            L10n.red
        case .orange:
            L10n.orange
        case .yellow:
            L10n.yellow
        case .green:
            L10n.green
        case .blue:
            L10n.blue
        }
    }

    static func resolve(alternateIconName: String?) -> Self {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .blue
    }
}
