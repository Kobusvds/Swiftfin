//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// The always visible strip with the current and next video and song
struct MusicModeInfoStrip: View {

    let video: MusicModeVideoQueue
    let music: MusicModeMusicController
    let errorMessages: [String]

    private static func title(for item: BaseItemDto) -> String {
        if item.type == .episode, let seriesName = item.seriesName {
            return "\(seriesName) · \(item.displayTitle)"
        }

        return item.displayTitle
    }

    @ViewBuilder
    private func row(systemImage: String, current: String?, next: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(current ?? "Loading…")
                    .fontWeight(.semibold)

                if let next {
                    Text("Next: \(next)")
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var rows: some View {
        row(
            systemImage: "film",
            current: video.current.map(Self.title(for:)),
            next: video.next.map(Self.title(for:))
        )

        row(
            systemImage: "music.note",
            current: music.currentSong,
            next: music.nextSong
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Side by side when there's room, stacked on narrow screens
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 32) {
                    rows
                }

                VStack(alignment: .leading, spacing: 8) {
                    rows
                }
            }

            ForEach(errorMessages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .font(UIDevice.isTV ? .callout : .footnote)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .dark)
    }
}
