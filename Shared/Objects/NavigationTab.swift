//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// A user configurable tab in the main navigation
struct NavigationTab: Displayable, Hashable, Identifiable, Storable, SystemImageable {

    enum Kind: Hashable, Codable {

        case home
        case search
        case media
        case library(
            id: String,
            name: String,
            collectionType: CollectionType?,
            itemType: BaseItemKind?
        )
    }

    let kind: Kind
    var systemImage: String

    init(kind: Kind, systemImage: String? = nil) {
        self.kind = kind
        self.systemImage = systemImage ?? Self.defaultSystemImage(for: kind)
    }

    /// Creates a tab for a user view (media library)
    init?(library: BaseItemDto) {
        guard let id = library.id else { return nil }

        self.init(
            kind: .library(
                id: id,
                name: library.displayTitle,
                collectionType: library.collectionType,
                itemType: library.type
            )
        )
    }

    var id: String {
        switch kind {
        case .home:
            "home"
        case .search:
            // Must match `TabItem.search.id` so the tab keeps the search role
            "search"
        case .media:
            "media"
        case let .library(id, _, _, _):
            "library-\(id)"
        }
    }

    var displayTitle: String {
        switch kind {
        case .home:
            L10n.home
        case .search:
            L10n.search
        case .media:
            L10n.media
        case let .library(_, name, _, _):
            name
        }
    }

    var defaultSystemImage: String {
        Self.defaultSystemImage(for: kind)
    }

    static let defaultTabs: [NavigationTab] = [
        .init(kind: .home),
        .init(kind: .search),
        .init(kind: .media),
    ]

    static func defaultSystemImage(for kind: Kind) -> String {
        switch kind {
        case .home:
            "house.fill"
        case .search:
            "magnifyingglass"
        case .media:
            "rectangle.stack.fill"
        case let .library(_, _, collectionType, _):
            switch collectionType {
            case .movies:
                "film"
            case .tvshows:
                "tv"
            case .music:
                "music.note"
            case .musicvideos:
                "music.note.tv"
            case .livetv:
                "play.tv"
            case .boxsets:
                "square.stack.fill"
            case .books:
                "book.fill"
            case .homevideos:
                "video.fill"
            case .photos:
                "photo.fill"
            default:
                "folder.fill"
            }
        }
    }

    /// Symbols offered when choosing a tab icon
    static let availableSystemImages: [String] = [
        "house.fill",
        "magnifyingglass",
        "rectangle.stack.fill",
        "film",
        "film.stack",
        "movieclapper",
        "popcorn.fill",
        "tv",
        "play.tv",
        "play.rectangle.fill",
        "play.circle.fill",
        "sparkles.tv",
        "theatermasks.fill",
        "video.fill",
        "music.note",
        "music.note.tv",
        "music.mic",
        "headphones",
        "book.fill",
        "books.vertical.fill",
        "photo.fill",
        "camera.fill",
        "figure.and.child.holdinghands",
        "figure.2.and.child.holdinghands",
        "teddybear.fill",
        "balloon.2.fill",
        "gamecontroller.fill",
        "graduationcap.fill",
        "globe",
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flame.fill",
        "leaf.fill",
        "pawprint.fill",
        "sportscourt.fill",
        "trophy.fill",
        "crown.fill",
        "square.stack.fill",
        "folder.fill",
        "archivebox.fill",
        "tray.full.fill",
        "bookmark.fill",
        "tag.fill",
        "clock.fill",
        "calendar",
        // Custom genre symbols, from the asset catalog
        "genre.scifi",
        "genre.space",
        "genre.fantasy",
        "genre.darkfantasy",
        "genre.fairytale",
        "genre.isekai",
        "genre.gameworld",
        "genre.superhero",
        "genre.supernatural",
        "genre.horror",
        "genre.thriller",
        "genre.spy",
        "genre.ninja",
        "genre.war",
        "genre.western",
        "genre.history",
        "genre.historical",
        "genre.sitcom",
    ]
}
