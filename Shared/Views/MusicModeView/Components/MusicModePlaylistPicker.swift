//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import MusicKit
import SwiftUI

/// Lists the playlists in the user's Apple Music library
struct MusicModePlaylistPicker: View {

    @Binding
    var selection: MusicModePlaylist?

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var playlists: [Playlist] = []
    @State
    private var isLoading = true
    @State
    private var errorMessage: String?

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            playlists = try await MusicModeMusicController.libraryPlaylists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func row(_ playlist: Playlist) -> some View {
        Button {
            selection = MusicModePlaylist(id: playlist.id.rawValue, name: playlist.name)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if let artwork = playlist.artwork {
                    ArtworkImage(artwork, width: UIDevice.isTV ? 80 : 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "music.note.list")
                        .frame(width: UIDevice.isTV ? 80 : 44)
                }

                Text(playlist.name)
                    .foregroundStyle(.primary)

                Spacer()

                if selection?.id == playlist.id.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if !isLoading, playlists.isEmpty {
                Text("There are no playlists in your Apple Music library.")
                    .foregroundStyle(.secondary)
            }

            ForEach(playlists) { playlist in
                row(playlist)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Apple Music")
        .task {
            await load()
        }
    }
}
