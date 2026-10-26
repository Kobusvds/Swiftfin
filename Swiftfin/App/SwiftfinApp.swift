//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import PreferencesView
import SwiftUI
import UIKit

@main
struct SwiftfinApp: App {

    @UIApplicationDelegateAdaptor(SwiftfinAppDelegate.self)
    private var appDelegate

    init() {
        Self.configure()

        MacDockIcon.applySavedIcon()

        UIScrollView.appearance().keyboardDismissMode = .onDrag

        // Sometimes the tab bar won't appear properly on push, always have material background.
        UITabBar.appearance().scrollEdgeAppearance = UITabBarAppearance(idiom: .unspecified)

        SwiftfinSpotlight().addSwiftfinToSpotlight()
    }

    var body: some Scene {
        WindowGroup {
            OverlayToastView {
                PreferencesView {
                    WithLocalUserAuthentication {
                        RootView()
                            .supportedOrientations(.allButUpsideDown)
                    }
                }
            }
            .ignoresSafeArea()
            .overlay {
                LaunchIconOverlay()
            }
        }
    }
}

final class SwiftfinAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SwiftfinSceneDelegate.self
        return configuration
    }
}

/// SwiftUI still manages the scene's window, this only adds window preferences on top
final class SwiftfinSceneDelegate: NSObject, UIWindowSceneDelegate {

    /// On iPad, keep the close, minimize and zoom buttons small and tucked into the
    /// top leading corner instead of reserving space for them in the navigation bar
    @available(iOS 26.0, *)
    func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        .minimal
    }
}

extension UINavigationController {

    // Remove back button text
    override open func viewWillLayoutSubviews() {
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }
}
