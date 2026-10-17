//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI
import TVServices

/// Keeps the data in `WidgetSharedStore` in sync for the top shelf extension
@MainActor
enum TopShelfSync {

    /// Publishes the session the top shelf loads content for, or clears it when signed out
    static func update(session: UserSession?) {
        defer {
            // Also picks up playback progress, since this runs when the app goes to the background
            TVTopShelfContentProvider.topShelfContentDidChange()
        }

        guard let session else {
            WidgetSharedStore.clear()
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
    }
}
