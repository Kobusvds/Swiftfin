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

/// Lists the Jellyfin playlists, collections and libraries that can be played in the Music tab
struct MusicModeVideoSourcePicker: View {

    @Binding
    var selection: MusicModeVideoSource?

    @Environment(\.dismiss)
    private var dismiss

    @Injected(\.currentUserSession)
    private var userSession

    @State
    private var playlists: [MusicModeVideoSource] = []
    @State
    private var collections: [MusicModeVideoSource] = []
    @State
    private var libraries: [MusicModeVideoSource] = []
    @State
    private var isLoading = true
    @State
    private var errorMessage: String?

    /// Libraries without videos can't be played
    private static let videoCollectionTypes: Set<CollectionType> = [
        .movies,
        .tvshows,
        .homevideos,
        .musicvideos,
        .folders,
    ]

    private func load() async {
        guard let userSession else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let playlistItems = items(of: .playlist, userSession: userSession)
            async let collectionItems = items(of: .boxSet, userSession: userSession)

            let viewsParameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
            let views = try await userSession.client.send(Paths.getUserViews(parameters: viewsParameters)).value.items ?? []

            // Audio playlists can't be played as video
            playlists = try await playlistItems
                .filter { $0.mediaType != .audio }
                .compactMap { source(for: $0, kind: .playlist) }
            collections = try await collectionItems
                .compactMap { source(for: $0, kind: .collection) }
            libraries = views
                .filter { Self.videoCollectionTypes.contains($0.collectionType ?? .folders) }
                .compactMap { source(for: $0, kind: .library) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func items(of kind: BaseItemKind, userSession: UserSession) async throws -> [BaseItemDto] {
        var parameters = Paths.GetItemsParameters()
        parameters.userID = userSession.user.id
        parameters.isRecursive = true
        parameters.includeItemTypes = [kind]
        parameters.sortBy = [.sortName]

        return try await userSession.client.send(Paths.getItems(parameters: parameters)).value.items ?? []
    }

    private func source(for item: BaseItemDto, kind: MusicModeVideoSource.Kind) -> MusicModeVideoSource? {
        guard let id = item.id else { return nil }
        return MusicModeVideoSource(id: id, name: item.displayTitle, kind: kind)
    }

    @ViewBuilder
    private func section(_ title: String, sources: [MusicModeVideoSource]) -> some View {
        if sources.isNotEmpty {
            Section(title) {
                ForEach(sources) { source in
                    Button {
                        selection = source
                        dismiss()
                    } label: {
                        HStack {
                            Label(source.name, systemImage: source.systemImage)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selection?.id == source.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if !isLoading, playlists.isEmpty, collections.isEmpty, libraries.isEmpty {
                Text("No playlists, collections or video libraries were found.")
                    .foregroundStyle(.secondary)
            }

            section(L10n.playlists, sources: playlists)
            section(L10n.collections, sources: collections)
            section("Libraries", sources: libraries)
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Videos")
        .task {
            await load()
        }
    }
}
