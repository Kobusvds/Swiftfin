//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import SwiftUI

// MARK: - Leading

/// A back button when pushed, and the current library's icon, which switches to another library
struct CoverFlowLibraryControls: View {

    @Environment(\.tabCoordinator)
    private var tabCoordinator

    @Router
    private var router

    var body: some View {
        HStack(spacing: 10) {
            if !router.isRootOfPath {
                Button {
                    router.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .coverFlowControlBackground()
                }
                .accessibilityLabel(String(localized: "Back"))
            }

            if let tabCoordinator {
                LibraryMenu(tabCoordinator: tabCoordinator)
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct LibraryMenu: View {

    @ObservedObject
    var tabCoordinator: TabCoordinator

    private var selectedTab: TabItem? {
        tabCoordinator.tabs.first(where: { $0.item.id == tabCoordinator.selectedTabID })?.item
    }

    private var selection: Binding<String> {
        Binding {
            tabCoordinator.selectedTabID ?? ""
        } set: { tabID in
            tabCoordinator.select(tabID: tabID)
        }
    }

    var body: some View {
        Menu {
            Picker(selection: selection) {
                ForEach(tabCoordinator.tabs, id: \.item.id) { tab in
                    Label(tab.item.displayTitle, symbol: tab.item.systemImage)
                        .tag(tab.item.id)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            Image(symbol: selectedTab?.systemImage ?? "rectangle.stack.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
                .coverFlowControlBackground()
        }
        .accessibilityLabel(selectedTab?.displayTitle ?? L10n.media)
    }
}

// MARK: - Trailing

/// The user's profile image, which opens settings, and the library's menu
struct CoverFlowAccountControls<MenuContent: View>: View {

    @Injected(\.currentUserSession)
    private var userSession

    @Router
    private var router

    private let menuContent: MenuContent

    init(@ViewBuilder menuContent: () -> MenuContent) {
        self.menuContent = menuContent()
    }

    var body: some View {
        HStack(spacing: 4) {
            if let userSession {
                SettingsBarButton(
                    server: userSession.server,
                    user: userSession.user
                ) {
                    router.route(to: .settings)
                }
                .frame(width: 36, height: 36)
                .clipShape(.circle)
            }

            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.options)
        }
        .padding(.leading, userSession == nil ? 0 : 4)
        .frame(height: 44)
        .coverFlowControlBackground()
        .foregroundStyle(.primary)
    }
}
