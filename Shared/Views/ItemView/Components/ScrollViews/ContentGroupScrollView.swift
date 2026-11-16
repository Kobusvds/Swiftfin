//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

// TODO: tvOS black background if not enhanced?

extension ItemView {

    struct ContentGroupScrollView: View {

        @Environment(\.tabSafeAreaInsets)
        private var tabSafeAreaInsets

        @EnvironmentObject
        private var focusCoordinator: FocusCoordinator

        @ObservedObject
        var provider: ItemContentGroupProvider

        let groups: [any ContentGroup]
        let isEnhanced: Bool
        /// Scrolls down to the episodes once they appear, so they're visible without scrolling
        var scrollsToEpisodes = false

        @State
        private var hasScrolledToEpisodes = false

        private var episodeGroupID: String? {
            groups.first { $0 is SeriesEpisodeContentGroup }?.id
        }

        private var isHeaderFocused: Bool {
            focusCoordinator.lastFocusedIDs.contains(Component.header)
        }

        private var backgroundImageItem: BaseItemDto {
            if provider.item.type == .person || provider.item.type == .musicArtist,
               let randomItem = provider.randomBackdropItem
            {
                randomItem
            } else {
                provider.item
            }
        }

        @ViewBuilder
        private var background: some View {
            AlternateLayoutView {
                Color.clear
            } content: {
                ImageView(backgroundImageItem.imageSources(
                    for: .landscape,
                    environment: .init(maxWidth: 1920)
                ))
                .failure {
                    Color.black
                }
                .aspectRatio(contentMode: .fill)
            }
            .accessibilityHidden(true)
            .overlay {
                Rectangle()
                    .fill(Material.regular)
                    .mask(gradient: .linear) {
                        if isHeaderFocused {
                            (location: 0.3, opacity: 0)
                        } else {
                            (location: 0, opacity: 1)
                        }

                        (location: 1, opacity: 1)
                    }
            }
            .animation(.linear(duration: 0.2), value: isHeaderFocused)
        }

        var body: some View {
            ZStack {
                #if os(tvOS)
                if isEnhanced {
                    background
                        .ignoresSafeArea()
                }
                #endif

                ScrollViewReader { proxy in
                    ScrollView {
                        ContentGroupVStack(groups: groups)
                            .edgePadding(.bottom)
                            .padding(.top, isEnhanced ? 0 : tabSafeAreaInsets.top)
                            #if os(iOS)
                            .dynamicIslandBodyInset()
                            #endif
                    }
                    .trackingFrame(for: .scrollView)
                    #if os(tvOS)
                    .ignoresSafeArea(.container, edges: isEnhanced ? .all : [.horizontal, .top])
                    #else
                    .ignoresSafeArea(edges: isEnhanced ? .all : .horizontal)
                    #endif
                    .scrollIndicators(.hidden)
                    .task(id: episodeGroupID) {
                        guard scrollsToEpisodes, !hasScrolledToEpisodes, let episodeGroupID else { return }

                        // Wait for the episodes to lay out before measuring where they are
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }

                        hasScrolledToEpisodes = true

                        withAnimation {
                            // Bottom aligned, so the whole episode row and its overviews are on screen
                            proxy.scrollTo(episodeGroupID, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
