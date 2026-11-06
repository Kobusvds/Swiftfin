//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import UIKit

/// A movie or show picked at random from a library, ready to display in a widget
struct RandomPickItem: Hashable, Identifiable {

    let id: String
    let title: String
    let subtitle: String?
    /// Downsampled JPEG data, since widgets can't load remote images
    let imageData: Data?
    let url: URL?

    var image: UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }
}

/// A library the random pick widget can choose from
struct RandomPickLibrary: Hashable, Identifiable {
    let id: String
    let name: String
}

enum RandomPickClient {

    typealias ClientError = ContinueWatchingClient.ClientError

    /// Libraries containing movies or shows
    private static let supportedCollectionTypes: Set<String?> = [nil, "movies", "tvshows", "mixed"]

    /// The user's movie and show libraries, in the order set on the server
    static func libraries() async throws -> [RandomPickLibrary] {
        let (account, accessToken) = try credentials()

        let url = account.serverURL.appending(path: "UserViews").appending(queryItems: [
            .init(name: "userId", value: account.userID),
        ])

        let data = try await ContinueWatchingClient.send(
            ContinueWatchingClient.request(url: url, account: account, accessToken: accessToken)
        )
        let response = try JSONDecoder().decode(ItemsResponse.self, from: data)

        return response.items
            .filter { supportedCollectionTypes.contains($0.collectionType) }
            .map { RandomPickLibrary(id: $0.id, name: $0.name ?? "") }
    }

    /// Distinct random movies or shows from the library, avoiding the ones shown last when possible
    static func randomItems(libraryID: String, count: Int, imagePixelWidth: Int) async throws -> [RandomPickItem] {
        let (account, accessToken) = try credentials()

        let url = account.serverURL.appending(path: "Items").appending(queryItems: [
            .init(name: "userId", value: account.userID),
            .init(name: "parentId", value: libraryID),
            .init(name: "recursive", value: "true"),
            .init(name: "includeItemTypes", value: "Movie,Series"),
            .init(name: "sortBy", value: "Random"),
            // Extra items let the dice avoid repeating the current picks
            .init(name: "limit", value: "\(count * 2)"),
            .init(name: "enableImageTypes", value: "Primary,Backdrop,Thumb"),
            .init(name: "imageTypeLimit", value: "1"),
        ])

        let data = try await ContinueWatchingClient.send(
            ContinueWatchingClient.request(url: url, account: account, accessToken: accessToken)
        )
        let response = try JSONDecoder().decode(ItemsResponse.self, from: data)

        let lastPicksKey = "randomPick.lastPicks.\(libraryID)"
        let lastPickIDs = Set(UserDefaults.standard.stringArray(forKey: lastPicksKey) ?? [])

        // Prefer items that weren't just shown, topping up with repeats in small libraries
        let freshItems = response.items.filter { !lastPickIDs.contains($0.id) }
        let repeatedItems = response.items.filter { lastPickIDs.contains($0.id) }
        let pickedItems = Array((freshItems + repeatedItems).prefix(count))

        guard !pickedItems.isEmpty else { return [] }

        UserDefaults.standard.set(pickedItems.map(\.id), forKey: lastPicksKey)

        // Load artwork concurrently, keeping the picked order
        let imageData = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, item) in pickedItems.enumerated() {
                group.addTask {
                    let data = await imageData(
                        for: item,
                        account: account,
                        accessToken: accessToken,
                        pixelWidth: imagePixelWidth
                    )
                    return (index, data)
                }
            }

            var imageData = [Data?](repeating: nil, count: pickedItems.count)
            for await (index, data) in group {
                imageData[index] = data
            }
            return imageData
        }

        return zip(pickedItems, imageData).map { item, imageData in
            RandomPickItem(
                id: item.id,
                title: item.name ?? "",
                subtitle: item.productionYear.map(String.init),
                imageData: imageData,
                url: WidgetSharedStore.url(account: account, destination: "item", id: item.id)
            )
        }
    }

    // MARK: - Requests

    private static func credentials() throws -> (WidgetSharedStore.Account, String) {
        guard let account = WidgetSharedStore.account,
              let accessToken = WidgetSharedStore.accessToken
        else {
            throw ClientError.signedOut
        }

        return (account, accessToken)
    }

    private static func imageData(
        for item: ItemDto,
        account: WidgetSharedStore.Account,
        accessToken: String,
        pixelWidth: Int
    ) async -> Data? {
        guard let source = item.landscapeImageSource else { return nil }

        let url = account.serverURL
            .appending(path: "Items/\(item.id)/Images/\(source.type)")
            .appending(queryItems: [
                .init(name: "maxWidth", value: "\(pixelWidth)"),
                .init(name: "quality", value: "80"),
                .init(name: "tag", value: source.tag),
            ])

        guard let data = try? await ContinueWatchingClient.send(
            ContinueWatchingClient.request(url: url, account: account, accessToken: accessToken)
        ) else {
            return nil
        }

        return ContinueWatchingClient.downsampled(data, maxPixelSize: pixelWidth)
    }
}

// MARK: - Server Models

private struct ItemsResponse: Decodable {

    let items: [ItemDto]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

/// The subset of Jellyfin's `BaseItemDto` the widget uses
private struct ItemDto: Decodable {

    let id: String
    let name: String?
    let collectionType: String?
    let productionYear: Int?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
        case productionYear = "ProductionYear"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
    }

    /// The best wide image, preferring artwork over posters
    var landscapeImageSource: (type: String, tag: String)? {
        if let tag = backdropImageTags?.first {
            return ("Backdrop", tag)
        }
        if let tag = imageTags?["Thumb"] {
            return ("Thumb", tag)
        }
        if let tag = imageTags?["Primary"] {
            return ("Primary", tag)
        }
        return nil
    }
}
