//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import ImageIO
import UIKit

/// An item the user can resume, ready to display in a widget
struct ContinueWatchingItem: Codable, Hashable, Identifiable {

    let id: String
    let title: String
    let subtitle: String?
    /// Playback progress, from 0 to 1
    let progress: Double
    let remainingSeconds: Int?
    /// Downsampled JPEG data, since widgets can't load remote images
    let imageData: Data?
    let url: URL?

    var image: UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }
}

enum ContinueWatchingClient {

    enum ClientError: Error {
        case signedOut
        case badResponse
    }

    /// Loads the user's resumable videos, falling back to the last loaded items when the server can't be reached
    static func items(limit: Int, imagePixelWidth: Int) async throws -> [ContinueWatchingItem] {
        guard let account = WidgetSharedStore.account,
              let accessToken = WidgetSharedStore.accessToken
        else {
            throw ClientError.signedOut
        }

        do {
            let items = try await fetchItems(
                account: account,
                accessToken: accessToken,
                limit: limit,
                imagePixelWidth: imagePixelWidth
            )
            Cache.save(items, userID: account.userID)
            return items
        } catch {
            guard let cached = Cache.load(userID: account.userID) else { throw error }
            return Array(cached.prefix(limit))
        }
    }

    // MARK: - Requests

    private static func fetchItems(
        account: WidgetSharedStore.Account,
        accessToken: String,
        limit: Int,
        imagePixelWidth: Int
    ) async throws -> [ContinueWatchingItem] {
        let url = account.serverURL.appending(path: "UserItems/Resume").appending(queryItems: [
            .init(name: "userId", value: account.userID),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "mediaTypes", value: "Video"),
            .init(name: "enableUserData", value: "true"),
            .init(name: "enableImageTypes", value: "Primary,Backdrop,Thumb"),
            .init(name: "imageTypeLimit", value: "1"),
        ])

        let data = try await send(request(url: url, account: account, accessToken: accessToken))
        let response = try JSONDecoder().decode(ItemsResponse.self, from: data)

        // Load the images concurrently, keeping the server's order
        return try await withThrowingTaskGroup(of: (Int, ContinueWatchingItem).self) { group in
            for (index, item) in response.items.prefix(limit).enumerated() {
                group.addTask {
                    let imageData = await imageData(
                        for: item,
                        account: account,
                        accessToken: accessToken,
                        pixelWidth: imagePixelWidth
                    )
                    return (index, item.widgetItem(account: account, imageData: imageData))
                }
            }

            var items: [(Int, ContinueWatchingItem)] = []
            for try await item in group {
                items.append(item)
            }

            return items
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    private static func imageData(
        for item: ItemDto,
        account: WidgetSharedStore.Account,
        accessToken: String,
        pixelWidth: Int
    ) async -> Data? {
        guard let source = item.landscapeImageSource else { return nil }

        var queryItems: [URLQueryItem] = [
            .init(name: "maxWidth", value: "\(pixelWidth)"),
            .init(name: "quality", value: "80"),
        ]
        if let tag = source.tag {
            queryItems.append(.init(name: "tag", value: tag))
        }

        let url = account.serverURL
            .appending(path: "Items/\(source.itemID)/Images/\(source.type)")
            .appending(queryItems: queryItems)

        guard let data = try? await send(request(url: url, account: account, accessToken: accessToken)) else {
            return nil
        }

        return downsampled(data, maxPixelSize: pixelWidth)
    }

    private static func request(
        url: URL,
        account: WidgetSharedStore.Account,
        accessToken: String
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)

        let authorization = [
            "Client": account.client,
            "Device": account.deviceName,
            "DeviceId": account.deviceID,
            "Version": account.version,
            "Token": accessToken,
        ]
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\"\($0.value)\"" }
        .joined(separator: ", ")

        request.setValue("MediaBrowser \(authorization)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
            throw ClientError.badResponse
        }

        return data
    }

    /// Widgets have a small memory budget, so keep only a small JPEG
    private static func downsampled(_ data: Data, maxPixelSize: Int) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        return UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Cache

private enum Cache {

    private struct Contents: Codable {
        let userID: String
        let items: [ContinueWatchingItem]
    }

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appending(path: "continue-watching.json")
    }

    static func save(_ items: [ContinueWatchingItem], userID: String) {
        guard let fileURL, let data = try? JSONEncoder().encode(Contents(userID: userID, items: items)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load(userID: String) -> [ContinueWatchingItem]? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let contents = try? JSONDecoder().decode(Contents.self, from: data),
              contents.userID == userID
        else { return nil }

        return contents.items
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

    struct UserData: Decodable {

        let playbackPositionTicks: Int?
        let playedPercentage: Double?

        enum CodingKeys: String, CodingKey {
            case playbackPositionTicks = "PlaybackPositionTicks"
            case playedPercentage = "PlayedPercentage"
        }
    }

    let id: String
    let name: String?
    let type: String?
    let seriesName: String?
    let parentIndexNumber: Int?
    let indexNumber: Int?
    let productionYear: Int?
    let runTimeTicks: Int?
    let userData: UserData?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?
    let parentBackdropItemID: String?
    let parentBackdropImageTags: [String]?
    let parentThumbItemID: String?
    let parentThumbImageTag: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case seriesName = "SeriesName"
        case parentIndexNumber = "ParentIndexNumber"
        case indexNumber = "IndexNumber"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case userData = "UserData"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case parentBackdropItemID = "ParentBackdropItemId"
        case parentBackdropImageTags = "ParentBackdropImageTags"
        case parentThumbItemID = "ParentThumbItemId"
        case parentThumbImageTag = "ParentThumbImageTag"
    }

    private static let ticksPerSecond = 10_000_000

    var isEpisode: Bool {
        type == "Episode"
    }

    /// The best wide image, preferring artwork of the item or its series over posters
    var landscapeImageSource: (itemID: String, type: String, tag: String?)? {
        if let tag = imageTags?["Thumb"] {
            return (id, "Thumb", tag)
        }
        if let parentThumbItemID, let parentThumbImageTag {
            return (parentThumbItemID, "Thumb", parentThumbImageTag)
        }
        if let tag = backdropImageTags?.first {
            return (id, "Backdrop", tag)
        }
        if let parentBackdropItemID, let tag = parentBackdropImageTags?.first {
            return (parentBackdropItemID, "Backdrop", tag)
        }
        if let tag = imageTags?["Primary"] {
            return (id, "Primary", tag)
        }
        return nil
    }

    func widgetItem(account: WidgetSharedStore.Account, imageData: Data?) -> ContinueWatchingItem {
        let title: String
        let subtitle: String?

        if isEpisode {
            title = seriesName ?? name ?? ""

            let episodeLabel: String? = if let parentIndexNumber, let indexNumber {
                "S\(parentIndexNumber), E\(indexNumber)"
            } else {
                nil
            }
            subtitle = [episodeLabel, name]
                .compactMap(\.self)
                .joined(separator: " · ")
        } else {
            title = name ?? ""
            subtitle = productionYear.map(String.init)
        }

        var progress = (userData?.playedPercentage ?? 0) / 100
        var remainingSeconds: Int?

        if let runTimeTicks, runTimeTicks > 0, let position = userData?.playbackPositionTicks {
            progress = Double(position) / Double(runTimeTicks)
            remainingSeconds = max(0, runTimeTicks - position) / Self.ticksPerSecond
        }

        return ContinueWatchingItem(
            id: id,
            title: title,
            subtitle: subtitle,
            progress: min(max(progress, 0), 1),
            remainingSeconds: remainingSeconds,
            imageData: imageData,
            url: WidgetSharedStore.url(account: account, destination: "item", id: id)
        )
    }
}
