//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// The Jellyfin playlist, collection or library whose videos play in the Music tab
struct MusicModeVideoSource: Hashable, Identifiable, Storable {

    enum Kind: String, Codable {
        case playlist
        case collection
        case library
    }

    let id: String
    let name: String
    let kind: Kind

    var systemImage: String {
        switch kind {
        case .playlist:
            "list.and.film"
        case .collection:
            "square.stack.fill"
        case .library:
            "film.stack"
        }
    }
}

/// The Apple Music library playlist that plays in the Music tab
struct MusicModePlaylist: Hashable, Identifiable, Storable {

    let id: String
    let name: String
}
