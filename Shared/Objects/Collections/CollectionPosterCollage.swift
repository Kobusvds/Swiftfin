//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import JellyfinAPI
import SwiftUI

/// Collection (box set) artwork made from the posters of up to four of its items, similar to Plex.
///
/// - 4 or more items: a 2x2 grid
/// - 3 items: one large poster on the left, two stacked on the right
/// - 2 items: side by side
/// - 1 item: the item's poster
///
/// Shows `fallback`, such as the collection's own artwork, when no items have posters.
struct CollectionPosterCollage<Fallback: View>: View {

    @Environment(\.appTheme)
    private var theme

    @Injected(\.currentUserSession)
    private var userSession

    @State
    private var items: [BaseItemDto]?

    let collectionID: String
    let fallback: Fallback

    init(collectionID: String, @ViewBuilder fallback: () -> Fallback) {
        self.collectionID = collectionID
        self.fallback = fallback()
        self._items = State(initialValue: CollectionPosterCollageCache.items[collectionID])
    }

    var body: some View {
        Group {
            if let items, items.isNotEmpty {
                collage(items)
            } else {
                fallback
            }
        }
        .task(id: collectionID) {
            guard items == nil, let userSession else { return }
            items = await CollectionPosterCollageCache.items(for: collectionID, userSession: userSession)
        }
    }

    private var spacing: CGFloat {
        switch theme {
        case .default:
            0
        case .skeuo:
            1
        case .y2k:
            2
        case .gameUI2:
            3
        }
    }

    private var gapColor: Color {
        switch theme {
        case .default:
            .clear
        case .skeuo:
            Skeuo.collageGap
        case .y2k:
            .white
        case .gameUI2:
            GameUI.outline
        }
    }

    @ViewBuilder
    private func collage(_ items: [BaseItemDto]) -> some View {
        Group {
            layout(items)
        }
        .background(gapColor)
    }

    @ViewBuilder
    private func layout(_ items: [BaseItemDto]) -> some View {
        switch items.count {
        case 1:
            tile(items[0])
        case 2:
            HStack(spacing: spacing) {
                tile(items[0])
                tile(items[1])
            }
        case 3:
            HStack(spacing: spacing) {
                tile(items[0])

                VStack(spacing: spacing) {
                    tile(items[1])
                    tile(items[2])
                }
            }
        default:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    tile(items[0])
                    tile(items[1])
                }

                HStack(spacing: spacing) {
                    tile(items[2])
                    tile(items[3])
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: BaseItemDto) -> some View {
        Color.clear
            .overlay {
                ImageView(
                    item.imageSource(
                        .primary,
                        itemID: item.id,
                        environment: ImageSourceOptions(maxWidth: 200)
                    )
                )
                .image { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .placeholder { _ in
                    Color.secondarySystemFill
                }
                .failure {
                    Color.secondarySystemFill
                }
            }
            .clipped()
    }
}

/// Caches the items used for collection collages so posters don't refetch while scrolling
@MainActor
enum CollectionPosterCollageCache {

    /// Items with posters, keyed by collection ID
    fileprivate static var items: [String: [BaseItemDto]] = [:]
    private static var tasks: [String: Task<[BaseItemDto], Never>] = [:]

    fileprivate static func items(for collectionID: String, userSession: UserSession) async -> [BaseItemDto] {
        if let items = items[collectionID] {
            return items
        }

        // Share one request between posters of the same collection
        if let task = tasks[collectionID] {
            return await task.value
        }

        let task = Task<[BaseItemDto], Never> {
            var parameters = Paths.GetItemsParameters()
            parameters.userID = userSession.user.id
            parameters.parentID = collectionID
            parameters.sortBy = [.premiereDate, .sortName]
            parameters.sortOrder = [.ascending]
            parameters.enableImageTypes = [.primary]
            parameters.imageTypeLimit = 1
            parameters.enableUserData = false
            parameters.fields = []
            // Fetch a few extra in case some items have no poster
            parameters.limit = 8

            let request = Paths.getItems(parameters: parameters)
            let response = try? await userSession.client.send(request)

            return Array(
                (response?.value.items ?? [])
                    .filter { $0.imageTags?[ImageType.primary.rawValue] != nil }
                    .prefix(4)
            )
        }

        tasks[collectionID] = task
        let result = await task.value
        tasks[collectionID] = nil
        items[collectionID] = result

        return result
    }

    /// Clears cached items, such as after a collection's contents change
    static func invalidate() {
        items.removeAll()
    }
}
