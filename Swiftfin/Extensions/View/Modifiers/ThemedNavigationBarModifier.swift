//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct ThemedNavigationBarModifier<MenuContent: View>: ViewModifier {

    @Environment(\.appTheme)
    private var theme
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @State
    private var collectedMenuGroups: [MenuContentGroup] = []

    private let title: String?
    private let isEnabled: Bool
    private let isLoading: Bool
    private let isMenuHidden: Bool
    private let isGlowing: Bool
    private let isOverlay: Bool
    private let menuContent: MenuContent

    init(
        title: String?,
        isEnabled: Bool,
        isLoading: Bool,
        isMenuHidden: Bool,
        isGlowing: Bool,
        isOverlay: Bool,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.isMenuHidden = isMenuHidden
        self.isGlowing = isGlowing
        self.isOverlay = isOverlay
        self.menuContent = menuContent()
    }

    private var overlaysBar: Bool {
        isOverlay && theme.overlaysItemTopBar(in: horizontalSizeClass)
    }

    func body(content: Content) -> some View {
        if theme.isThemed, isEnabled {
            content
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
                .modifier(ThemedTabBarInset(isEnabled: horizontalSizeClass == .compact))
                .themedTopInset(isOverlay: overlaysBar, isScrollEdgeBar: theme == .y2k || theme == .gameUI2) {
                    ThemedTopBar(title: title, isLoading: isLoading, isOverlay: overlaysBar) {
                        menuContent

                        ForEach(collectedMenuGroups) { group in
                            group.content
                        }
                    }
                }
                .background {
                    ThemedPageBackground(isGlowing: isGlowing)
                }
                .themedStatusBar(overlaysBar ? .dark : theme.colorScheme)
                .environment(\.colorScheme, theme.colorScheme ?? .dark)
                .onPreferenceChange(MenuContentKey.self) { newGroups in
                    collectedMenuGroups = newGroups
                }
        } else {
            content
                .navigationBarMenuButton(
                    isLoading: isLoading,
                    isHidden: isMenuHidden
                ) {
                    menuContent
                }
        }
    }
}

private extension View {

    @ViewBuilder
    func themedTopInset<Bar: View>(isOverlay: Bool, isScrollEdgeBar: Bool, @ViewBuilder bar: () -> Bar) -> some View {
        let bar = bar()

        if isOverlay {
            overlay(alignment: .top) {
                bar
            }
        } else if #available(iOS 26, *), isScrollEdgeBar {
            safeAreaBar(edge: .top, spacing: 0) {
                bar
            }
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                bar
            }
        }
    }

    @ViewBuilder
    func themedStatusBar(_ colorScheme: ColorScheme?) -> some View {
        if #available(iOS 27, *) {
            toolbarColorScheme(colorScheme, for: .statusBar)
        } else {
            self
        }
    }
}
