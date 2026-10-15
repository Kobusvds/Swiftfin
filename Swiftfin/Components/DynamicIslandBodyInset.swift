//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import UIKit

extension View {

    /// Insets content group bodies, but not headers, away from the Dynamic Island
    /// while it's on the left in landscape
    func dynamicIslandBodyInset() -> some View {
        modifier(DynamicIslandBodyInsetModifier())
    }
}

private struct DynamicIslandBodyInsetModifier: ViewModifier {

    /// Extra room so content doesn't crowd the cutout
    private static let cutoutClearance: CGFloat = 16

    @State
    private var inset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.contentGroupBodyLeadingInset, inset)
            .animation(.default, value: inset)
            .onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                update()
            }
            .onDisappear {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
            // Rotating between portrait and landscape changes the size
            .onGeometryChange(for: CGSize.self, of: \.size) { _ in
                update()
            }
            // Flipping between the two landscape orientations doesn't, so check
            // again once the interface has finished rotating
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    update()
                }
            }
    }

    private func update() {
        let newInset = Self.leftCutoutInset() ?? 0

        if newInset != inset {
            inset = newInset
        }
    }

    /// How far content must move right to clear the Dynamic Island or notch while
    /// it's on the left of the screen, or `nil` if it isn't.
    ///
    /// Landscape safe area insets are the same on both sides, so the side is found
    /// by converting the top center of the screen, where the cutout is, from the
    /// screen's fixed portrait coordinates into the window's coordinates.
    private static func leftCutoutInset() -> CGFloat? {
        guard UIDevice.isPhone,
              let windowScene = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene })
              .first(where: { $0.activationState == .foregroundActive }) ??
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = windowScene.keyWindow ?? windowScene.windows.first
        else { return nil }

        let sideInset = max(window.safeAreaInsets.left, window.safeAreaInsets.right)

        guard window.bounds.width > window.bounds.height, sideInset > 0 else { return nil }

        let fixedSpace = windowScene.screen.fixedCoordinateSpace
        let cutoutCenter = CGPoint(x: fixedSpace.bounds.midX, y: 0)
        let cutoutInWindow = window.coordinateSpace.convert(cutoutCenter, from: fixedSpace)

        guard cutoutInWindow.x < window.bounds.midX else { return nil }

        return sideInset + cutoutClearance
    }
}
