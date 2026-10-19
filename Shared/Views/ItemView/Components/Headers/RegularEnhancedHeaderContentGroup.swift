//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension ItemView {

    struct RegularEnhancedHeaderContentGroup: ContentGroup {

        let id: String = ItemView.Component.header
        let provider: ItemContentGroupProvider

        func body(with viewModel: Empty) -> Body {
            Body(provider: provider)
        }

        struct Body: View {

            @Environment(\.appTheme)
            private var theme

            @ObservedObject
            var provider: ItemContentGroupProvider

            @StoredValue(.User.itemViewAttributes)
            private var attributes

            // Movies and series use a hero image 25% shorter than the default
            private var headerAspectRatio: CGFloat {
                provider.item.type == .movie || provider.item.type == .series ? 2.0 / 0.75 : 2.0
            }

            #if !os(tvOS)
            private var headerImageItem: BaseItemDto {
                if provider.item.type == .person || provider.item.type == .musicArtist,
                   let randomItem = provider.randomBackdropItem
                {
                    randomItem
                } else {
                    provider.item
                }
            }
            #endif

            private var logoHeight: CGFloat {
                UIDevice.isTV ? 100 : 70
            }

            @ViewBuilder
            private var logo: some View {
                ImageView(
                    provider.item.imageSource(
                        .logo,
                        itemID: provider.item.id,
                        environment: ImageSourceOptions(maxHeight: logoHeight)
                    )
                )
                .image { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: logoHeight)
                }
                .placeholder { _ in
                    EmptyView()
                }
                .failure {
                    ThemedHeroTitle(title: provider.item.displayTitle)
                }
                .accessibilityLabel(provider.item.displayTitle)
                .accessibilityRemoveTraits(.isImage)
            }

            @ViewBuilder
            private var titleBlock: some View {
                VStack(alignment: .leading) {
                    if let parentID = provider.item.parentRootID, let parentTitle = provider.item.parentTitle {
                        ParentButton(title: parentTitle, id: parentID)
                    }

                    logo
                }
            }

            @ViewBuilder
            private var details: some View {
                VStack(alignment: .leading, spacing: 10) {
                    ItemView.Description(item: provider.item)

                    HStack(alignment: .top) {
                        ItemView.AttributesHStack(
                            attributes: attributes,
                            item: provider.item,
                            selectedMediaSource: provider.mediaPlayerItemProvider?.mediaSource,
                            alignment: .leading
                        )

                        MetadataHStack(item: provider.item)
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            @ViewBuilder
            private var stripOverlay: some View {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .center, spacing: 28) {
                        ItemView.ActionBar(provider: provider)
                            .fixedSize()

                        details
                    }
                    .themedHeroStrip()
                }
                .padding(.horizontal, ThemedHeroLayout.y2kInset + ThemedHeroLayout.y2kStripInset - EdgeInsets.edgePadding)
                .padding(.bottom, ThemedHeroLayout.y2kStripInset)
                .colorScheme(.light)
            }

            @ViewBuilder
            private var overlay: some View {
                if theme == .y2k {
                    stripOverlay
                } else {
                    standardOverlay
                }
            }

            @ViewBuilder
            private var standardOverlay: some View {
                HStack(alignment: .bottom, spacing: EdgeInsets.edgePadding) {
                    VStack(alignment: .center, spacing: UIDevice.isTV ? 30 : 5) {
                        titleBlock
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ItemView.ActionBar(provider: provider)
                    }
                    .frame(width: UIDevice.isTV ? 450 : theme.heroColumnWidth)

                    details
                        .themedHeroDetails()
                }
                #if os(tvOS)
                .focusSection()
                #else
                    .padding(.horizontal, theme == .gameUI2 ? ThemedHeroLayout.y2kInset + 28 - EdgeInsets.edgePadding : 0)
                    .padding(.bottom, theme == .gameUI2 ? 6 : 0)
                    .edgePadding(.bottom)
                    .background(
                        alignment: .bottom,
                        extendedBy: .init(horizontal: EdgeInsets.edgePadding)
                    ) {
                        if !theme.isThemed {
                            Rectangle()
                                .fill(Material.ultraThin)
                                .mask(gradient: .eased(.easeOut)) {
                                    (location: 0, opacity: 0)
                                    (location: 1, opacity: 1)
                                }
                                // Reach the screen edges in landscape, past the side safe areas
                                .ignoresSafeArea(edges: .horizontal)
                        }
                    }
                #endif
            }

            #if !os(tvOS)
            private func resolveColor(from image: UIImage, binding: Binding<Color>) {
                Task.detached(priority: .utility) {
                    guard let color = image.interestingColor() else { return }

                    await MainActor.run {
                        binding.wrappedValue = color
                    }
                }
            }
            #endif

            var body: some View {
                #if os(tvOS)
                CinematicContentGroupContainer {
                    overlay
                        .edgePadding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .colorScheme(.dark)
                }
                #else
                AlternateLayoutView(alignment: .bottom) {
                    Color.clear
                        .aspectRatio(headerAspectRatio, contentMode: .fit)
                } content: {
                    overlay
                        .edgePadding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .colorScheme(.dark)
                }
                .backgroundParallaxHeader(multiplier: 0.3) {
                    StateAdapter(initialValue: Color.secondarySystemFill) { resolvedColor in
                        AlternateLayoutView {
                            Color.clear
                        } content: {
                            ImageView(headerImageItem.imageSources(for: .landscape, environment: .init(maxWidth: 1920)))
                                .image { (image: UIImage) in
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(1.77, contentMode: .fill)
                                        .onAppear {
                                            resolveColor(from: image, binding: resolvedColor)
                                        }
                                }
                        }
                        .themedHeroPanel()
                        .aspectRatio(headerAspectRatio, contentMode: .fit)
                        .themedHeroArtwork(bottomColor: resolvedColor.wrappedValue)
                        .accessibilityHidden(true)
                    }
                }
                #endif
            }
        }
    }
}
