//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct PosterButton<Item: Poster>: View {

    @Environment(\.appTheme)
    private var theme
    @Environment(\.viewContext)
    private var viewContext

    @Namespace
    private var namespace

    @State
    private var posterSize: CGSize = .zero

    @SharedPoster
    var item: Item
    let displayType: PosterDisplayType
    let size: PosterDisplayType.Size
    let action: (Namespace.ID) -> Void

    init(
        item: Item,
        displayType: PosterDisplayType,
        size: PosterDisplayType.Size = .small,
        action: @escaping (Namespace.ID) -> Void
    ) {
        self.item = item
        self.displayType = displayType
        self.size = size
        self.action = action
    }

    @ViewBuilder
    private var contextMenuPreview: some View {
        buttonLabel()
            .posterAccessibility(for: item)
            .frame(width: posterSize.width)
            .padding(20)
            .backport
            .glassEffect(in: .rect(cornerRadius: 10))
    }

    private var imageDisplayType: PosterDisplayType {
        theme.isThemed && item.themedPosterKind == .person ? .square : displayType
    }

    @ViewBuilder
    private func posterImage(overlay: some View) -> some View {
        PosterImage(
            item: item,
            type: imageDisplayType,
            size: size
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedPosterGloss(imageDisplayType)
        .overlay { overlay.posterStyle(imageDisplayType) }
        .contentShape(.contextMenuPreview, Rectangle())
        .matchedTransitionSource(id: "item", in: namespace)
        .themedPosterFrame(item.themedPosterKind, ringIndex: ringIndex)
        .overlay(alignment: .topTrailing) {
            if theme == .gameUI2, let baseItem = item.underlyingBaseItem {
                ThemedOverhangMarker(item: baseItem)
                    .offset(x: 10, y: -10)
            }
        }
        .hoverEffect(.highlight)
    }

    private var ringIndex: Int {
        item.displayTitle.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    @ViewBuilder
    private func buttonLabel(overlay: some View = EmptyView()) -> some View {
        VStack(alignment: .leading) {
            posterImage(overlay: overlay)

            item.posterLabel
                .allowsHitTesting(false)
        }
    }

    var body: some View {
        Button {
            action(namespace)
        } label: {
            // Layout required for tvOS focused offset label behavior
            #if os(tvOS)
            posterImage(overlay: item.posterOverlay(for: displayType))
                .posterAspectRatio(displayType, contentMode: .fit)
                .frame(width: posterSize.width > 0 ? posterSize.width : nil)
                .posterAccessibility(for: item)

            item.posterLabel
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            #else
            buttonLabel(overlay: item.posterOverlay(for: displayType))
                .posterAccessibility(for: item)
            #endif
        }
        .environment(\.posterDisplayType, displayType)
        .foregroundStyle(.primary, .secondary)
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle)
        #if os(tvOS)
        .focusedValue(\.focusedPoster, AnyPoster(item))
        .frame(maxWidth: .infinity, alignment: .leading)
        .ignoresSafeArea()
        #endif
        .trackingSize($posterSize)
        .posterContextMenu(for: item) {
            contextMenuPreview
                .withViewContext(viewContext)
        }
    }
}
