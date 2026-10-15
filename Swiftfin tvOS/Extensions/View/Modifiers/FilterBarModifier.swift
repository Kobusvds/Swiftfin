//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct FilterBarModifier: ViewModifier {

    @Default(.accentColor)
    private var accentColor
    @Default(.Customization.Library.letterPickerOrientation)
    private var letterPickerOrientation

    @FocusState
    private var focusedFilter: FilterTrack.FocusTarget?

    @ObservedObject
    var viewModel: FilterViewModel

    let types: [ItemFilterType]
    /// Library options shown below the filters, such as grouping and collections
    var menu: AnyView? = nil

    @FocusState
    private var isMenuFocused: Bool

    private var edge: HorizontalEdge {
        letterPickerOrientation == .trailing ? .leading : .trailing
    }

    @ViewBuilder
    private var filters: some View {
        VStack(spacing: 20) {
            ForEach(subviews: FilterTrack(
                viewModel: viewModel,
                types: types,
                focus: $focusedFilter,
                style: .compact,
                iconEdge: edge
            )) { button in
                Color.clear
                    .frame(width: 64, height: 64)
                    .overlay(alignment: edge == .leading ? .leading : .trailing) {
                        button
                    }
            }

            if let menu {
                Color.clear
                    .frame(width: 64, height: 64)
                    .overlay(alignment: edge == .leading ? .leading : .trailing) {
                        menuButton(menu)
                    }
            }
        }
        .scrollIfLargerThanContainer()
        .frame(width: 64)
        .coordinatedFocusScope(
            $focusedFilter,
            values: types.map(FilterTrack.FocusTarget.filter) + (viewModel.hasActiveFilters ? [.reset] : [])
        )
    }

    /// Matches the compact filter buttons, showing the title only while focused
    @ViewBuilder
    private func menuButton(_ menu: AnyView) -> some View {
        Menu {
            menu
        } label: {
            HStack(spacing: 12) {
                if edge == .leading {
                    menuIcon
                }

                Text(L10n.options)
                    .isVisible(isMenuFocused)

                if edge == .trailing {
                    menuIcon
                }
            }
            .lineLimit(1)
            .fixedSize()
            .frame(width: isMenuFocused ? nil : 32, alignment: edge == .leading ? .leading : .trailing)
        }
        .focused($isMenuFocused)
        .fixedSize()
        .font(.callout)
        .controlSize(.large)
        .buttonStyle(.capsule(selectionTint: accentColor, focusTint: .white))
        .animation(.snappy(duration: 0.2), value: isMenuFocused)
        .accessibilityLabel(L10n.options)
    }

    private var menuIcon: some View {
        Image(systemName: "ellipsis")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .padding(.vertical, 8)
    }

    func body(content: Content) -> some View {
        if types.isEmpty, menu == nil {
            content
        } else {
            content
                .focusSection()
                .safeAreaInset(edge: edge, alignment: .center, spacing: 0) {
                    filters
                        .coordinatedFocus(.secondary)
                        .padding(edge.asEdgeSet, EdgeInsets.itemSpacing)
                }
                .ignoresSafeArea(.all, edges: edge.asEdgeSet)
        }
    }
}
