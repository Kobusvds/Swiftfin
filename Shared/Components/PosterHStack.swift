//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CollectionHStack
import SwiftUI

struct PosterHStack<
    Data: Collection
>: View where Data.Element: Poster, Data.Index == Int {

    @Environment(\.appTheme)
    private var theme
    #if os(iOS)
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
    #endif

    let elements: Data
    let displayType: PosterDisplayType
    let size: PosterDisplayType.Size
    let action: (Data.Element, Namespace.ID) -> Void

    /// Wide posters on an iPhone in landscape need more room between them to read as separate items
    private var itemSpacing: CGFloat {
        #if os(iOS)
        if UIDevice.isPhone, verticalSizeClass == .compact, displayType == .landscape {
            return EdgeInsets.itemSpacing * 2
        }
        #endif

        return EdgeInsets.itemSpacing
    }

    private var layout: CollectionHStackLayout {
        #if os(tvOS)
        .grid(
            columns: displayType == .landscape ? 5 : 7,
            rows: 1,
            columnTrailingInset: 0
        )
        #else
        // iPhones in landscape are wide enough to size posters like iPad
        if UIDevice.isPad || verticalSizeClass == .compact {
            let minWidth: CGFloat = {
                switch (displayType, size) {
                case (.landscape, .small):
                    220
                case (.landscape, .medium):
                    300
                case (_, .small):
                    140
//                case (_, .medium):
                default:
                    200
                }
            }()

            return .minimumWidth(
                columnWidth: minWidth,
                rows: 1
            )
        } else {
            let columnCount: CGFloat = {
                switch (displayType, size) {
                case (.landscape, .small):
                    2
                case (.landscape, .medium):
                    1.5
                case (_, .small):
                    3
//                case (_, .medium):
                default:
                    2
                }
            }()

            return .grid(
                columns: columnCount,
                rows: 1,
                columnTrailingInset: 0
            )
        }
        #endif
    }

    var body: some View {
        CollectionHStack(
            uniqueElements: elements,
            layout: layout
        ) { item in
            PosterButton(
                item: item,
                displayType: displayType,
                size: size
            ) { namespace in
                action(item, namespace)
            }
            .environment(\.appTheme, theme)
        }
        .clipsToBounds(false)
        .insets(horizontal: EdgeInsets.edgePadding)
        .itemSpacing(itemSpacing)
        .scrollBehavior(.continuousLeadingEdge)
        .id(theme)
        #if os(iOS)
        // Rebuild the collection when rotating so the new layout applies
        .id(verticalSizeClass)
        #endif
        .withViewContext(.isThumb)
    }
}
