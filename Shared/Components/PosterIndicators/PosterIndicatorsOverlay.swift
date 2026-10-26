//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

struct PosterIndicatorsOverlay: View {

    @Default(.accentColor)
    private var accentColor

    @Environment(\.appTheme)
    private var theme
    @Environment(\.isSelected)
    private var isSelected
    @Environment(\.posterConfiguration)
    private var posterConfiguration

    @ViewContextContains(.isInResume)
    private var isInResume

    @SharedBaseItem
    var item: BaseItemDto
    let posterDisplayType: PosterDisplayType

    private var indicators: PosterIndicator {
        posterConfiguration.indicators
    }

    private var indicatorSize: CGFloat {
        UIDevice.isTV ? 45 : 25
    }

    private var showsUnplayedIndicator: Bool {
        item.showsUnplayedIndicator(indicators)
    }

    private var showsProgressIndicator: Bool {
        indicators.contains(.progress) &&
            item.progressLabel != nil
    }

    private var showsFavoriteIndicator: Bool {
        indicators.contains(.favorited) && item.userData?.isFavorite == true
    }

    private var showsPlayedIndicator: Bool {
        indicators.contains(.played) &&
            item.canBePlayed &&
            !item.isLiveStream &&
            item.userData?.isPlayed == true &&
            !isInResume &&
            (item.userData?.playbackPositionTicks ?? 0) == 0
    }

    /// Movies show nothing in the top trailing corner.
    private var showsTopTrailingIndicators: Bool {
        item.type != .movie
    }

    @ArrayBuilder<QuadrantItem>
    private var bottomIndicators: [QuadrantItem] {
        if item.isRecording {
            QuadrantItem(color: .red) {
                Text(Image(systemName: "record.circle"))
                    .accessibilityLabel(L10n.recording)
            }
        }

        if showsFavoriteIndicator {
            QuadrantItem(color: .pink) {
                Text(Image(systemName: "heart.fill"))
                    .accessibilityLabel(L10n.favorited)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if showsUnplayedIndicator, showsTopTrailingIndicators {
                    if theme.isThemed {
                        ThemedUnplayedMarker(
                            count: posterConfiguration.unplayedStyle == .count ? item.userData?.unplayedItemCount : nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityLabel(L10n.unplayed)
                    } else {
                        UnplayedIndicator(
                            count: posterConfiguration.unplayedStyle == .count ? item.userData?.unplayedItemCount : nil
                        )
                        .frame(height: indicatorSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                if showsPlayedIndicator, showsTopTrailingIndicators {
                    if theme.isThemed {
                        ThemedPlayedMarker()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .accessibilityLabel(L10n.played)
                    } else {
                        Quadrant(.topTrailing) {
                            QuadrantItem(color: accentColor) {
                                Text(Image(systemName: "checkmark"))
                                    .fontWeight(.bold)
                                    .accessibilityLabel(L10n.played)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                if !showsProgressIndicator {
                    Quadrant(.bottomTrailing) {
                        bottomIndicators
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsProgressIndicator {
                ProgressIndicator(
                    title: item.progressLabel ?? "",
                    progress: item.progressPercentage ?? 0,
                    posterDisplayType: posterDisplayType
                ) {
                    bottomIndicators
                }
            }
        }
        .opacity(isSelected ? 0.85 : 1)
        .posterCornerRadius(posterDisplayType)
    }
}

struct PosterSelectionOverlay: View {

    @Default(.accentColor)
    private var accentColor

    @Environment(\.isSelected)
    private var isSelected

    var body: some View {
        if isSelected {
            ContainerRelativeShape()
                .stroke(accentColor, lineWidth: UIDevice.isTV ? 12 : 8)
                .clipped()
                .accessibilityHidden(true)
        }
    }
}

extension BaseItemDto {

    func showsUnplayedIndicator(_ indicators: PosterIndicator) -> Bool {
        indicators.contains(.unplayed) &&
            canBePlayed &&
            !isLiveStream &&
            userData?.isPlayed == false &&
            (userData?.playbackPositionTicks ?? 0) == 0
    }
}
