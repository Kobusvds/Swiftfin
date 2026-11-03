//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// The portrait artwork of an item, opened from the item view's hero image
struct ItemPosterView: View {

    @Router
    private var router

    let item: BaseItemDto

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    router.dismiss()
                }

            ImageView(item.imageSources(for: .portrait, environment: .init(maxWidth: 1200)))
                .image { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .placeholder { _ in
                    ProgressView()
                        .tint(.white)
                }
                .failure {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .clipShape(.rect(cornerRadius: 12))
                .edgePadding()
                .accessibilityLabel(item.displayTitle)
        }
        .colorScheme(.dark)
        .navigationTitle(item.displayTitle)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarCloseButton {
            router.dismiss()
        }
    }
}
