//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI
import WidgetKit

/// Keeps the data in `WidgetSharedStore` in sync with the app
@MainActor
enum WidgetSync {

    /// Publishes the session the widgets load content for, or clears it when signed out
    static func update(session: UserSession?) {
        guard let session else {
            WidgetSharedStore.clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let configuration = JellyfinClient.Configuration.swiftfinConfiguration(
            url: session.server.effectiveServerURL
        )

        let account = WidgetSharedStore.Account(
            serverID: session.server.id,
            serverURL: configuration.url,
            userID: session.user.id,
            client: configuration.client,
            deviceName: configuration.deviceName,
            deviceID: configuration.deviceID,
            version: configuration.version
        )
        let accessToken = session.user.accessToken

        if WidgetSharedStore.account != account {
            WidgetSharedStore.account = account
        }
        if WidgetSharedStore.accessToken != accessToken {
            WidgetSharedStore.accessToken = accessToken
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Publishes the main navigation tabs, used by the libraries widget
    static func update(tabs: [NavigationTab]) {
        let tabs = (tabs.isEmpty ? NavigationTab.defaultTabs : tabs).map { tab in
            let isLibrary = if case .library = tab.kind { true } else { false }

            return WidgetSharedStore.Tab(
                id: tab.id,
                title: tab.displayTitle,
                systemImage: tab.systemImage,
                isLibrary: isLibrary
            )
        }

        guard WidgetSharedStore.tabs != tabs else { return }

        WidgetSharedStore.tabs = tabs
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.WidgetKind.libraries)
    }
}
