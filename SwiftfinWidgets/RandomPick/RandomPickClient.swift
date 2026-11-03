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

    /// A random movie or show from the library, avoiding the one shown last when possible
    static func randomItem(libraryID: String, imagePixelWidth: Int) async throws -> RandomPickItem? {
        let (account, accessToken) = try credentials()

        let url = account.serverURL.appending(path: "Items").appending(queryItems: [
            .init(name: "userId", value: account.userID),
            .init(name: "parentId", value: libraryID),
            .init(name: "recursive", value: "true"),
            .init(name: "includeItemTypes", value: "Movie,Series"),
            .init(name: "sortBy", value: "Random"),
            // A second item lets the dice avoid repeating the current pick
            .init(name: "limit", value: "2"),
            .init(name: "enableImageTypes", value: "Primary,Backdrop,Thumb"),
            .init(name: "imageTypeLimit", value: "1"),
        ])

        let data = try await ContinueWatchingClient.send(
            ContinueWatchingClient.request(url: url, account: account, accessToken: accessToken)
        )
        let response = try JSONDecoder().decode(ItemsResponse.self, from: data)

        let lastPickKey = "randomPick.last.\(libraryID)"
        let lastPickID = UserDefaults.standard.string(forKey: lastPickKey)

        guard let item = response.items.first(where: { $0.id != lastPickID }) ?? response.items.first else {
            return nil
        }

        UserDefaults.standard.set(item.id, forKey: lastPickKey)

        let imageData = await imageData(
            for: item,
            account: account,
            accessToken: accessToken,
            pixelWidth: imagePixelWidth
        )

        return RandomPickItem(
            id: item.id,
            title: item.name ?? "",
            subtitle: item.productionYear.map(String.init),
            imageData: imageData,
            url: WidgetSharedStore.url(account: account, destination: "item", id: item.id)
        )
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
