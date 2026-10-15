//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// How a collection (box set) and its items appear in library grids
enum CollectionDisplayMode: String, CaseIterable, Displayable, Hashable, Storable {

    /// Shows only the collection card in place of its items
    case hideItems
    /// Shows the collection card alongside its items
    case showCollectionAndItems
    /// Shows only the items, which is the standard library behavior
    case hideCollection

    var displayTitle: String {
        switch self {
        case .hideItems:
            "Hide Items in Collection"
        case .showCollectionAndItems:
            "Show Collection and Items"
        case .hideCollection:
            "Hide Collection"
        }
    }

    var isCollectionVisible: Bool {
        self != .hideCollection
    }
}

extension Dictionary: Storable where Key == String, Value: Storable {}

extension StoredValues.Keys.User {

    /// The collection display mode for a library when a collection has no override
    static func libraryCollectionDisplayMode(parentID: String?) -> StoredValues.Key<CollectionDisplayMode> {
        StoredValues.Keys.CurrentUserKey(
            parentID,
            field: "setting-libraryCollectionDisplayMode",
            default: .hideItems
        )
    }

    /// Per-collection display modes, keyed by collection ID
    static var collectionDisplayModes: StoredValues.Key<[String: CollectionDisplayMode]> {
        StoredValues.Keys.CurrentUserKey(
            "collectionDisplayModes",
            field: "setting-collectionDisplayModes",
            default: [:]
        )
    }
}
