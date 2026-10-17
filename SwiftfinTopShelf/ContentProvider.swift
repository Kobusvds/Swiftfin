//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import TVServices

/// Shows Continue Watching, Up Next, and Recently Added rows in the Apple TV top shelf
class ContentProvider: TVTopShelfContentProvider {

    private static let itemLimit = 12

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        // Signed out, so the system shows the static top shelf image
        guard let content = try? await TopShelfClient.content(limit: Self.itemLimit) else { return nil }

        let sections = [
            section(
                title: String(localized: "Continue Watching"),
                items: content.continueWatching,
                shape: .hdtv
            ),
            section(
                title: String(localized: "Up Next"),
                items: content.nextUp,
                shape: .hdtv
            ),
            section(
                title: String(localized: "Recently Added"),
                items: content.recentlyAdded,
                shape: .poster
            ),
        ]
        .compactMap(\.self)

        guard sections.isNotEmpty else { return nil }

        return TVTopShelfSectionedContent(sections: sections)
    }

    private func section(
        title: String,
        items: [TopShelfItem],
        shape: TVTopShelfSectionedItem.ImageShape
    ) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        guard items.isNotEmpty else { return nil }

        let collection = TVTopShelfItemCollection(
            items: items.map { sectionedItem(for: $0, shape: shape) }
        )
        collection.title = title
        return collection
    }

    private func sectionedItem(
        for item: TopShelfItem,
        shape: TVTopShelfSectionedItem.ImageShape
    ) -> TVTopShelfSectionedItem {
        let sectionedItem = TVTopShelfSectionedItem(identifier: item.id)
        sectionedItem.title = item.title
        sectionedItem.imageShape = shape

        if let progress = item.progress {
            sectionedItem.playbackProgress = progress
        }

        if let imageURLs = item.imageURLs {
            sectionedItem.setImageURL(imageURLs.oneX, for: .screenScale1x)
            sectionedItem.setImageURL(imageURLs.twoX, for: .screenScale2x)
        }

        // Selecting the item opens its page; the Play button starts playback
        if let displayURL = item.displayURL {
            sectionedItem.displayAction = TVTopShelfAction(url: displayURL)
        }
        if let playURL = item.playURL {
            sectionedItem.playAction = TVTopShelfAction(url: playURL)
        }

        return sectionedItem
    }
}

private extension Collection {

    var isNotEmpty: Bool {
        !isEmpty
    }
}
