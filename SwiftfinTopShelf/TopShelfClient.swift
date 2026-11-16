//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// An item ready to display in the top shelf
struct TopShelfItem {

    let id: String
    let title: String
    /// Playback progress, from 0 to 1
    let progress: Double?
    /// The image at 1x and 2x scale
    let imageURLs: (oneX: URL, twoX: URL)?
    let displayURL: URL?
    let playURL: URL?
}

/// Loads top shelf content from the signed in user's server
enum TopShelfClient {

    enum ClientError: Error {
        case signedOut
        case badResponse
    }

    enum ImageShape {
        /// 16:9 artwork, used for items the user is watching
        case landscape
        /// 2:3 artwork
        case poster

        /// Image width in pixels at 1x scale
        var pixelWidth: Int {
            switch self {
            case .landscape: 548
            case .poster: 404
            }
        }
    }

    struct Content {
        let continueWatching: [TopShelfItem]
        /// Dice posters opening a random pick, one per library tab in tab order
        let randomPicks: [TopShelfItem]
    }

    static func content(continueWatchingLimit: Int) async throws -> Content {
        guard let account = WidgetSharedStore.account,
              let accessToken = WidgetSharedStore.accessToken
        else {
            throw ClientError.signedOut
        }

        let client = Client(account: account, accessToken: accessToken)

        // A failing request shouldn't hide the dice posters
        let resumeItems = (try? await client.items(
            path: "UserItems/Resume",
            queryItems: [
                .init(name: "limit", value: "\(continueWatchingLimit)"),
                .init(name: "mediaTypes", value: "Video"),
            ]
        )) ?? []

        return Content(
            continueWatching: resumeItems.map { client.topShelfItem(for: $0, shape: .poster, showsProgress: true) },
            randomPicks: WidgetSharedStore.tabs.compactMap { client.randomPickItem(for: $0) }
        )
    }
}

// MARK: - Client

private struct Client {

    let account: WidgetSharedStore.Account
    let accessToken: String

    func items(path: String, queryItems: [URLQueryItem]) async throws -> [ItemDto] {
        let data = try await send(path: path, queryItems: queryItems)
        return try JSONDecoder().decode(ItemsResponse.self, from: data).items
    }

    private func send(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        let url = account.serverURL
            .appending(path: path)
            .appending(queryItems: queryItems + [
                .init(name: "userId", value: account.userID),
                .init(name: "enableUserData", value: "true"),
                .init(name: "enableImageTypes", value: "Primary,Backdrop,Thumb"),
                .init(name: "imageTypeLimit", value: "1"),
            ])

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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
            throw TopShelfClient.ClientError.badResponse
        }

        return data
    }

    // MARK: - Items

    func topShelfItem(for item: ItemDto, shape: TopShelfClient.ImageShape, showsProgress: Bool) -> TopShelfItem {
        // Episodes open their show's page, like selecting the show in a library
        let displayURL = WidgetSharedStore.url(
            account: account,
            destination: "item",
            id: item.isEpisode ? (item.seriesID ?? item.id) : item.id
        )

        return TopShelfItem(
            id: item.id,
            title: item.displayTitle,
            progress: showsProgress ? item.progress : nil,
            imageURLs: imageURLs(for: item, shape: shape),
            displayURL: displayURL,
            // Series and other folders open their page instead
            playURL: item.isPlayable
                ? WidgetSharedStore.url(account: account, destination: "play", id: item.id)
                : displayURL
        )
    }

    /// A dice poster for a library tab, opening a random movie or show from it
    func randomPickItem(for tab: WidgetSharedStore.Tab) -> TopShelfItem? {
        guard tab.isLibrary else { return nil }

        // Tabs saved before `libraryID` existed only have it in their ID
        let prefix = "library-"
        guard let libraryID = tab.libraryID ?? (tab.id.hasPrefix(prefix) ? String(tab.id.dropFirst(prefix.count)) : nil)
        else { return nil }

        let url = WidgetSharedStore.url(account: account, destination: "random", id: libraryID)

        return TopShelfItem(
            id: "random-\(libraryID)",
            title: tab.title,
            progress: nil,
            imageURLs: TopShelfRandomTile.imageURLs(libraryID: libraryID, title: tab.title),
            displayURL: url,
            playURL: url
        )
    }

    /// Jellyfin serves images without authentication, so the system can load these directly
    private func imageURLs(for item: ItemDto, shape: TopShelfClient.ImageShape) -> (oneX: URL, twoX: URL)? {
        let source = switch shape {
        case .landscape: item.landscapeImageSource
        case .poster: item.posterImageSource
        }

        guard let source else { return nil }

        func url(scale: Int) -> URL {
            var queryItems: [URLQueryItem] = [
                .init(name: "fillWidth", value: "\(shape.pixelWidth * scale)"),
                .init(name: "quality", value: "90"),
            ]
            if let tag = source.tag {
                queryItems.append(.init(name: "tag", value: tag))
            }

            return account.serverURL
                .appending(path: "Items/\(source.itemID)/Images/\(source.type)")
                .appending(queryItems: queryItems)
        }

        return (url(scale: 1), url(scale: 2))
    }
}

// MARK: - Server Models

private struct ItemsResponse: Decodable {

    let items: [ItemDto]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

/// The subset of Jellyfin's `BaseItemDto` the top shelf uses
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
    let seriesID: String?
    let seriesName: String?
    let seriesPrimaryImageTag: String?
    let parentIndexNumber: Int?
    let indexNumber: Int?
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
        case seriesID = "SeriesId"
        case seriesName = "SeriesName"
        case seriesPrimaryImageTag = "SeriesPrimaryImageTag"
        case parentIndexNumber = "ParentIndexNumber"
        case indexNumber = "IndexNumber"
        case runTimeTicks = "RunTimeTicks"
        case userData = "UserData"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case parentBackdropItemID = "ParentBackdropItemId"
        case parentBackdropImageTags = "ParentBackdropImageTags"
        case parentThumbItemID = "ParentThumbItemId"
        case parentThumbImageTag = "ParentThumbImageTag"
    }

    var isEpisode: Bool {
        type == "Episode"
    }

    var isPlayable: Bool {
        ["Movie", "Episode", "Video", "MusicVideo"].contains(type)
    }

    var displayTitle: String {
        guard isEpisode else { return name ?? "" }

        let episodeLabel: String? = if let parentIndexNumber, let indexNumber {
            "S\(parentIndexNumber), E\(indexNumber)"
        } else {
            name
        }

        return [seriesName, episodeLabel]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    var progress: Double {
        if let runTimeTicks, runTimeTicks > 0, let position = userData?.playbackPositionTicks {
            return min(max(Double(position) / Double(runTimeTicks), 0), 1)
        }
        return min(max((userData?.playedPercentage ?? 0) / 100, 0), 1)
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

    /// The poster, using the series poster for episodes
    var posterImageSource: (itemID: String, type: String, tag: String?)? {
        if isEpisode, let seriesID, let seriesPrimaryImageTag {
            return (seriesID, "Primary", seriesPrimaryImageTag)
        }
        if let tag = imageTags?["Primary"] {
            return (id, "Primary", tag)
        }
        return nil
    }
}
