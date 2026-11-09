//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct SettingsBarButton: View {

    let server: ServerState
    let user: UserState
    let action: () -> Void

    private var profileImage: some View {
        AlternateLayoutView {
            // Seems necessary for button layout
            Image(systemName: "gearshape.fill")
        } content: {
            UserProfileImage(
                userID: user.id,
                source: user.profileImageSource(
                    client: server.client
                ),
                pipeline: .Swiftfin.local
            )
        }
    }

    var body: some View {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // A title is needed for when the toolbar collapses
            // this button into an overflow menu on Mac
            Button(action: action) {
                Label {
                    Text(L10n.settings)
                } icon: {
                    profileImage
                }
                .labelStyle(.iconOnly)
            }
        } else {
            Button(action: action) {
                profileImage
            }
            .accessibilityLabel(L10n.settings)
        }
    }
}
