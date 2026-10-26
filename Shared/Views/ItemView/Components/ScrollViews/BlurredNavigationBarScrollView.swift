//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension ItemView {

    struct BlurredNavigationBarScrollView: View {

        @Environment(\.appTheme)
        private var theme
        @Environment(\.horizontalSizeClass)
        private var horizontalSizeClass

        let groups: [any ContentGroup]

        var body: some View {
            WithBlurNavigationBar {
                _Body(groups: groups)
            }
            .ignoresSafeArea(
                edges: theme.isThemed && !theme.overlaysItemTopBar(in: horizontalSizeClass) ? [.horizontal, .bottom] : .all
            )
            .trackingFrame(for: .scrollView)
        }
    }

    private struct _Body: View {

        @Environment(\.appTheme)
        private var theme
        @Environment(\.frameForParentView)
        private var frameForParentView
        @Environment(\.horizontalSizeClass)
        private var horizontalSizeClass

        private var showsTopBlur: Bool {
            !theme.isThemed || theme.overlaysItemTopBar(in: horizontalSizeClass)
        }

        /// How far the blur reaches below the safe area, the Y2K iPad bar sits
        /// below a short status bar so the fade has to extend behind it
        private var topBlurExtent: CGFloat {
            theme == .y2k && horizontalSizeClass == .regular ? 110 : 20
        }

        let groups: [any ContentGroup]

        var body: some View {
            // The ZStack itself ignores the horizontal safe area so both the
            // scroll content and the blur span the full screen width in landscape
            ZStack(alignment: .top) {
                ScrollView {
                    ContentGroupVStack(groups: groups)
                        .edgePadding(.bottom)
                        #if os(iOS)
                        .dynamicIslandBodyInset()
                        #endif
                }
                .scrollIndicators(.hidden)
                .backport
                .scrollEdgeEffectStyle(.soft, for: .top)

                Rectangle()
                    .fill(showsTopBlur ? AnyShapeStyle(Material.ultraThin) : AnyShapeStyle(.clear))
                    .mask(gradient: .eased(.smootherstep)) {
                        (location: 0, opacity: 1)
                        (location: 1, opacity: 0)
                    }
                    .frame(
                        height: frameForParentView[.scrollView, default: .zero]
                            .safeAreaInsets.top + topBlurExtent
                    )
                    .offset(
                        y: -frameForParentView[.scrollView, default: .zero]
                            .safeAreaInsets.top
                    )
                    .colorScheme(.dark)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea(edges: .horizontal)
        }
    }
}
