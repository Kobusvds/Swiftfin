//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// Groups library items into their collections (box sets), similar to Plex's
/// "Hide items in collection" behavior.
///
/// Jellyfin box sets are server wide, so for each library this determines which
/// collections contain items from that library. Each page from the server then
/// has hidden members removed and collection cards merged in using the page's sort order.
@MainActor
final class CollectionGrouping {

    struct Collection {
        let patch: ItemPatch
        /// Members of the collection that belong to the library
        let memberIDs: Set<String>

        var id: String { patch.value.id ?? "" }
    }

    private struct Index {
        let collections: [Collection]
        let date: Date
    }

    private static var indexes: [String: Index] = [:]
    private static var insertedCollectionIDs: [String: Set<String>] = [:]

    /// How long a library's collection index is reused before being fetched again
    private static let indexLifetime: TimeInterval = 300

    /// Fields required to compare collections with library items
    static let sortFields: [ItemFields] = [.sortName, .dateCreated]

    // MARK: - Applicability

    static func isSupported(parent: BaseItemDto, environment: ItemLibrary.Environment) -> Bool {
        guard parent.id != nil else { return false }
        guard parent.collectionType == .movies || parent.collectionType == .tvshows else { return false }
        guard environment.grouping == nil || environment.grouping == .series else { return false }

        // Collections can't be matched against filtered results, so only group the full library
        return !environment.filters.hasQueryableFilters
    }

    /// Whether any collection could currently be shown in the library
    static func hasVisibleCollections(libraryMode: CollectionDisplayMode) -> Bool {
        libraryMode.isCollectionVisible ||
            StoredValues[.User.collectionDisplayModes].values.contains(where: \.isCollectionVisible)
    }

    // MARK: - Applying to a page

    /// Removes hidden members from a page and merges in the collection cards that belong to it
    static func apply(
        to patches: [ItemPatch],
        parent: BaseItemDto,
        environment: ItemLibrary.Environment,
        pageState: LibraryPageState,
        isLastPage: Bool
    ) async throws -> [ItemPatch] {
        guard let libraryID = parent.id else { return patches }

        let libraryMode = environment.collectionDisplayMode
        let overrides = StoredValues[.User.collectionDisplayModes]
        let key = "\(pageState.userSession.user.id)-\(libraryID)"

        if pageState.pageOffset == 0 {
            insertedCollectionIDs[key] = []
        }

        let collections = try await collections(
            for: parent,
            environment: environment,
            key: key,
            userSession: pageState.userSession
        )

        func mode(for collection: Collection) -> CollectionDisplayMode {
            overrides[collection.id] ?? libraryMode
        }

        let hiddenMemberIDs = collections
            .filter { mode(for: $0) == .hideItems }
            .reduce(into: Set<String>()) { $0.formUnion($1.memberIDs) }

        let sortBy = environment.filters.sortBy.first ?? .sortName
        let isAscending = (environment.filters.sortOrder.first ?? .ascending) == .ascending
        let comparator = Comparator(sortBy: sortBy, isAscending: isAscending)

        var inserted = insertedCollectionIDs[key] ?? []
        let remaining = collections.filter { mode(for: $0).isCollectionVisible && !inserted.contains($0.id) }

        // Collections that sort at or before the last item of this page belong to it
        let pageCollections: [Collection] = if let comparator {
            if let last = patches.last?.value, !isLastPage {
                remaining.filter { !comparator.orders(last, before: $0.patch.value) }
            } else {
                remaining
            }
        } else {
            // Unsupported sort orders place collections at the start of the library
            pageState.pageOffset == 0 ? remaining : []
        }

        inserted.formUnion(pageCollections.map(\.id))
        insertedCollectionIDs[key] = inserted

        var result = patches

        if let comparator {
            for collection in pageCollections.sorted(by: { comparator.orders($0.patch.value, before: $1.patch.value) }) {
                let index = result.firstIndex { comparator.orders(collection.patch.value, before: $0.value) } ?? result.endIndex
                result.insert(collection.patch, at: index)
            }
        } else {
            result.insert(contentsOf: pageCollections.map(\.patch), at: 0)
        }

        return result.filter { patch in
            guard let id = patch.value.id, patch.value.type != .boxSet else { return true }
            return !hiddenMemberIDs.contains(id)
        }
    }

    /// Clears cached indexes so collections are fetched again on the next load
    static func invalidate() {
        indexes.removeAll()
    }

    // MARK: - Index

    private static func collections(
        for parent: BaseItemDto,
        environment: ItemLibrary.Environment,
        key: String,
        userSession: UserSession
    ) async throws -> [Collection] {
        if let index = indexes[key], Date.now.timeIntervalSince(index.date) < indexLifetime {
            return index.collections
        }

        guard let libraryID = parent.id else { return [] }
        let userID = userSession.user.id

        // Every item in the library, to match against collection members
        var libraryParameters = Paths.GetItemsParameters()
        libraryParameters.userID = userID
        libraryParameters.parentID = libraryID
        libraryParameters.isRecursive = true
        libraryParameters.includeItemTypes = parent.supportedItemTypes(for: environment.grouping)
        libraryParameters.enableImages = false
        libraryParameters.enableUserData = false
        libraryParameters.fields = []

        // Every collection the user can see
        var collectionParameters = Paths.GetItemsParameters()
        collectionParameters.userID = userID
        collectionParameters.includeItemTypes = [.boxSet]
        collectionParameters.isRecursive = true
        collectionParameters.enableUserData = true
        collectionParameters.fields = PosterSubtitleField.itemFields + sortFields

        let libraryRequest = Paths.getItems(parameters: libraryParameters)
        let collectionRequest = Paths.getItems(parameters: collectionParameters)

        async let libraryResponse = userSession.client.send(libraryRequest)
        async let collectionResponse = userSession.client.send(collectionRequest)

        let libraryItemIDs = try await Set((libraryResponse.value.items ?? []).compactMap(\.id))
        let collectionPatches = try await collectionResponse.patches()

        let members = try await withThrowingTaskGroup(of: (String, Set<String>).self) { group in
            for patch in collectionPatches {
                guard let collectionID = patch.value.id else { continue }

                group.addTask {
                    var parameters = Paths.GetItemsParameters()
                    parameters.userID = userID
                    parameters.parentID = collectionID
                    parameters.enableImages = false
                    parameters.enableUserData = false
                    parameters.fields = []

                    let response = try await userSession.client.send(Paths.getItems(parameters: parameters))
                    return (collectionID, Set((response.value.items ?? []).compactMap(\.id)))
                }
            }

            return try await group.reduce(into: [String: Set<String>]()) { $0[$1.0] = $1.1 }
        }

        let collections = collectionPatches.compactMap { patch -> Collection? in
            guard let id = patch.value.id else { return nil }

            let memberIDs = (members[id] ?? []).intersection(libraryItemIDs)
            guard memberIDs.isNotEmpty else { return nil }

            return Collection(patch: patch, memberIDs: memberIDs)
        }

        indexes[key] = Index(collections: collections, date: .now)
        return collections
    }
}

// MARK: - Comparator

extension CollectionGrouping {

    /// Approximates the server's ordering so collections can be placed among library items
    struct Comparator {

        private let isAscending: Bool
        private let key: (BaseItemDto) -> Key?

        private enum Key: Comparable {
            case string(String)
            case number(Double)

            static func < (lhs: Key, rhs: Key) -> Bool {
                switch (lhs, rhs) {
                case let (.string(a), .string(b)):
                    a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric]) == .orderedAscending
                case let (.number(a), .number(b)):
                    a < b
                default:
                    false
                }
            }
        }

        /// Returns `nil` for sort orders that can't be compared locally
        init?(sortBy: ItemSortBy, isAscending: Bool) {
            self.isAscending = isAscending

            switch sortBy {
            case .sortName, .name, .default:
                key = { .string(($0.sortName ?? $0.name ?? "").lowercased()) }
            case .dateCreated:
                key = { $0.dateCreated.map { .number($0.timeIntervalSince1970) } }
            case .premiereDate:
                key = { $0.premiereDate.map { .number($0.timeIntervalSince1970) } }
            case .productionYear:
                key = { $0.productionYear.map { .number(Double($0)) } }
            case .communityRating:
                key = { $0.communityRating.map { .number(Double($0)) } }
            case .criticRating:
                key = { $0.criticRating.map { .number(Double($0)) } }
            case .runtime:
                key = { $0.runTimeTicks.map { .number(Double($0)) } }
            default:
                return nil
            }
        }

        /// Whether `lhs` appears before `rhs` in the library
        func orders(_ lhs: BaseItemDto, before rhs: BaseItemDto) -> Bool {
            // Missing values sort first when ascending, matching the server
            switch (key(lhs), key(rhs)) {
            case let (a?, b?):
                isAscending ? a < b : b < a
            case (nil, _?):
                isAscending
            case (_?, nil):
                !isAscending
            case (nil, nil):
                false
            }
        }
    }
}
