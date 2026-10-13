//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Chooses how a single collection appears in library grids, or follows the library's setting
struct CollectionDisplayModePicker: View {

    @StoredValue(.User.collectionDisplayModes)
    private var collectionDisplayModes

    let collectionID: String

    private var selection: Binding<CollectionDisplayMode?> {
        Binding {
            collectionDisplayModes[collectionID]
        } set: { newValue in
            collectionDisplayModes[collectionID] = newValue
        }
    }

    var body: some View {
        Picker(selection: selection) {
            Text("Library Default")
                .tag(CollectionDisplayMode?.none)

            ForEach(CollectionDisplayMode.allCases, id: \.self) { mode in
                Text(mode.displayTitle)
                    .tag(CollectionDisplayMode?.some(mode))
            }
        } label: {
            Label("Library Display", systemImage: "square.stack")

            Text(selection.wrappedValue?.displayTitle ?? "Library Default")
        }
        .pickerStyle(.menu)
    }
}
