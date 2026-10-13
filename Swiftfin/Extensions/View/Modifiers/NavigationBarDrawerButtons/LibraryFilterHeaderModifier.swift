//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Places the library filters at the top of the page's items instead of in the navigation bar,
/// so they scroll away with the content
struct LibraryFilterHeaderModifier: ViewModifier {

    @ObservedObject
    var viewModel: FilterViewModel

    let types: [ItemFilterType]

    func body(content: Content) -> some View {
        content
            .environment(
                \.libraryHeader,
                types.isEmpty ? nil : AnyView(LibraryFilterHeader(viewModel: viewModel, types: types))
            )
    }
}

struct LibraryFilterHeader: View {

    @FocusState
    private var focusedFilter: FilterTrack.FocusTarget?

    @ObservedObject
    var viewModel: FilterViewModel

    let types: [ItemFilterType]

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                FilterTrack(viewModel: viewModel, types: types, focus: $focusedFilter)
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.vertical, 5)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

extension View {

    func libraryFilterHeader(
        viewModel: FilterViewModel,
        types: [ItemFilterType]
    ) -> some View {
        modifier(
            LibraryFilterHeaderModifier(
                viewModel: viewModel,
                types: types
            )
        )
    }
}
