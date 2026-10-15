//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct ContentGroupVStack: View {

    @Environment(\.contentGroupBodyLeadingInset)
    private var bodyLeadingInset

    let groups: [any ContentGroup]

    private var spacing: CGFloat {
        #if os(tvOS)
        60
        #else
        20
        #endif
    }

    @ViewBuilder
    private func makeGroupBody(_ group: some ContentGroup) -> some View {
        group.body(with: group.viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(groups, id: \.id) { group in
                makeGroupBody(group)
                    .eraseToAnyView()
                    // Headers stay edge to edge
                    .padding(.leading, group.id == ItemView.Component.header ? 0 : bodyLeadingInset)
                    .coordinatedFocus(group.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

extension EnvironmentValues {

    /// Extra leading padding for content groups other than headers, such as to avoid the Dynamic Island
    @Entry
    var contentGroupBodyLeadingInset: CGFloat = 0
}
