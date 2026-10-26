//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// The system launch screen is static and can't reflect the user's chosen
/// alternate icon, so it is left blank and this overlay briefly shows the
/// currently selected app icon before fading into the app.
struct LaunchIconOverlay: View {

    @State
    private var isVisible = true

    private let icon = AppIcon.current

    var body: some View {
        if isVisible {
            ZStack {
                Color(uiColor: .systemBackground)

                Image(icon.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(.rect(cornerRadius: 27, style: .continuous))
                    .subtleShadow()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
            .task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeOut(duration: 0.35)) {
                    isVisible = false
                }
            }
        }
    }
}
