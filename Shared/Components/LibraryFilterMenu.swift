//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

/// A library's filters as a submenu, for placing inside the library's options menu
struct LibraryFilterMenu: View {

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    @Router
    private var router

    @ObservedObject
    var viewModel: FilterViewModel

    /// The enabled filters that aren't fixed by the library
    private var types: [ItemFilterType] {
        enabledDrawerFilters.filter { !viewModel.staticFilters.containsFilters(ofType: $0) }
    }

    var body: some View {
        if types.isNotEmpty {
            Menu {
                ForEach(types, id: \.self) { type in
                    Button {
                        router.route(to: .filter(type: type, viewModel: viewModel))
                    } label: {
                        Label(
                            type.displayTitle,
                            systemImage: viewModel.isFilterSelected(type: type) ? "checkmark" : type.systemImage
                        )
                    }
                }

                if viewModel.hasActiveFilters {
                    Section {
                        Button(L10n.reset, systemImage: "arrow.counterclockwise", role: .destructive) {
                            viewModel.reset(filterType: nil)
                        }
                    }
                }
            } label: {
                Label(
                    L10n.filters,
                    systemImage: viewModel.hasActiveFilters
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease"
                )
            }
        }
    }
}
