//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct NavigationBarFilterDrawerModifier: ViewModifier {

    @FocusState
    private var focusedFilter: FilterTrack.FocusTarget?

    @State
    private var isHidden = false

    @ObservedObject
    var viewModel: FilterViewModel

    let types: [ItemFilterType]

    @ViewBuilder
    private var drawer: some View {
        ScrollView(.horizontal) {
            HStack {
                FilterTrack(viewModel: viewModel, types: types, focus: $focusedFilter)
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.bottom, 5)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    func body(content: Content) -> some View {
        if types.isEmpty {
            content
        } else {
            if #available(iOS 26, *) {
                content
                    .safeAreaBar(edge: .top, spacing: 0) {
                        // Removing the drawer also collapses the bar area it occupies.
                        // Scrolling content compensates for the change, see `ScrollDirectionObserver`.
                        if !isHidden {
                            drawer
                        }
                    }
                    .onPreferenceChange(IsFilterDrawerHidden.self) { newValue in
                        isHidden = newValue
                    }
                    .preference(key: IsSafeAreaBarApplied.self, value: true)
            } else {
                NavigationBarDrawerView {
                    drawer
                        .ignoresSafeArea()
                } content: {
                    content
                }
                .ignoresSafeArea()
            }
        }
    }
}
