//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// A floating bar for the item playing in Picture in Picture while the
/// full-screen player is closed
struct NowPlayingBar: View {

    /// Whether the bar has an item to show
    static var isVisible: Bool {
        DetachedPictureInPicture.manager != nil && !DetachedPictureInPicture.isRestoring
    }

    var body: some View {
        ZStack {
            if Self.isVisible, let manager = DetachedPictureInPicture.manager {
                Content(manager: manager)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: DetachedPictureInPicture.manager == nil)
    }
}

extension NowPlayingBar {

    /// Content for the tab view's bottom accessory, which provides its own
    /// background and moves inline with the tab bar when it minimizes
    @available(iOS 26, *)
    struct Accessory: View {

        @Environment(\.tabViewBottomAccessoryPlacement)
        private var placement

        var body: some View {
            if let manager = DetachedPictureInPicture.manager {
                Content(
                    manager: manager,
                    isAccessory: true,
                    isInline: placement == .inline
                )
            }
        }
    }

    private struct Content: View {

        @ObservedObject
        var manager: MediaPlayerManager

        var isAccessory: Bool = false
        var isInline: Bool = false

        private var item: BaseItemDto {
            manager.item
        }

        private var title: String {
            item.type == .episode ? item.seriesName ?? item.displayTitle : item.displayTitle
        }

        private var subtitle: String? {
            guard item.type == .episode else { return nil }

            return [item.seasonEpisodeLabel, item.displayTitle]
                .compactMap(\.self)
                .joined(separator: " · ")
        }

        private var isPlaying: Bool {
            manager.playbackRequestStatus == .playing
        }

        var body: some View {
            HStack(spacing: 12) {
                Button {
                    DetachedPictureInPicture.returnToPlayer()
                } label: {
                    HStack(spacing: 12) {
                        PosterImage(item: item, type: .landscape)
                            .frame(width: isAccessory ? 48 : 64, height: isAccessory ? 27 : 36)
                            .clipShape(.rect(cornerRadius: isAccessory ? 4 : 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            if let subtitle, !isInline {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Button(isPlaying ? L10n.pause : L10n.play, systemImage: isPlaying ? "pause.fill" : "play.fill") {
                    manager.togglePlayPause()
                }
                .contentTransition(.symbolEffect(.replace))

                // Inline next to the minimized tab bar, only the essentials fit
                if !isInline {
                    Button(L10n.stop, systemImage: "xmark") {
                        manager.stop()
                    }
                }
            }
            .labelStyle(.iconOnly)
            .font(isAccessory ? .body : .title3)
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.leading, 8)
            .padding(.trailing, isAccessory ? 16 : 20)
            .padding(.vertical, isAccessory ? 4 : 8)
            .overlay(alignment: .bottom) {
                if !isInline {
                    ProgressLine(
                        secondsBox: manager.secondsBox,
                        runtime: item.runtime
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, isAccessory ? 1 : 3)
                }
            }
            .if(!isAccessory) { view in
                view
                    .nowPlayingBarBackground()
                    .frame(maxWidth: 520)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            }
        }
    }

    /// Thin playback progress along the bottom edge
    private struct ProgressLine: View {

        @ObservedObject
        var secondsBox: PublishedBox<Duration>

        let runtime: Duration?

        private var progress: Double {
            guard let runtime, runtime > .zero else { return 0 }
            return min(max(secondsBox.value / runtime, 0), 1)
        }

        var body: some View {
            GeometryReader { proxy in
                Capsule()
                    .fill(.primary.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.tint)
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 2)
        }
    }
}

private extension View {

    @ViewBuilder
    func nowPlayingBarBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.regularMaterial, in: .capsule)
        }
    }
}
