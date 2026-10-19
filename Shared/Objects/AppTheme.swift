//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

enum AppTheme: String, CaseIterable, Displayable, Identifiable {

    case `default`
    case skeuo
    case y2k
    case gameUI2

    static let storageKey = "appTheme"

    var id: String {
        rawValue
    }

    var displayTitle: String {
        switch self {
        case .default:
            L10n.default
        case .skeuo:
            L10n.skeuo
        case .y2k:
            L10n.y2k
        case .gameUI2:
            L10n.gameUI2
        }
    }

    var isThemed: Bool {
        self != .default
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .default:
            nil
        case .skeuo:
            .dark
        case .y2k:
            .light
        case .gameUI2:
            .dark
        }
    }
}

extension EnvironmentValues {

    @Entry
    var appTheme: AppTheme = .default

    @Entry
    var isOnPosterShelf: Bool = false
}
