//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI

// TODO: fix weird tvOS icon rendering
struct MainTabView: View {

    #if os(tvOS)
    @Default(.Customization.tabBarPlacement)
    private var tabBarPlacement
    #endif

    @Default(.Customization.navigationTabs)
    private var navigationTabs

    @InjectedObject(\.userSessionManager)
    private var userSessionManager

    @StateObject
    private var tabCoordinator: TabCoordinator

    init() {
        _tabCoordinator = StateObject(wrappedValue: Self.defaultTabCoordinator)
    }

    /// The user's chosen tabs, falling back to the defaults if none are chosen
    private static func tabItems(for tabs: [NavigationTab]) -> [TabItem] {
        let items = (tabs.isEmpty ? NavigationTab.defaultTabs : tabs)
            .map(TabItem.navigationTab)

        #if os(tvOS)
        // tvOS has no settings bar button, so settings is always the last tab
        return items + [TabItem.settings]
        #else
        return items
        #endif
    }

    private static var defaultTabCoordinator: TabCoordinator {
        TabCoordinator(tabs: tabItems(for: Defaults[.Customization.navigationTabs]))
    }

    private func routePendingDeepLink(_ deepLink: DeepLink?) {
        guard let deepLink else { return }

        Task { @MainActor in
            if case let .tab(id) = deepLink.destination {
                tabCoordinator.select(tabID: id)
            } else if case let .play(id) = deepLink.destination {
                guard let userSession = userSessionManager.currentSession else { return }

                userSessionManager.playItem(
                    id: id,
                    queuesEpisodes: true,
                    userSession: userSession
                )
            } else if let route = deepLink.route() {
                await tabCoordinator.route(to: route)
            }
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: TabCoordinator.TabData) -> some View {
        NavigationInjectionView(coordinator: tab.coordinator) {
            tab.item.content
                #if os(iOS)
                    .topBarTrailing {
                        TabRootSettingsBarButton()
                    }
                #endif
        }
        .environmentObject(tabCoordinator)
        .environment(\.tabCoordinator, tabCoordinator)
        .environment(\.tabItemSelected, tab.publisher)
    }

    @ViewBuilder
    private func tabView() -> some View {
        TabView(selection: $tabCoordinator.selectedTabID) {
            ForEach(tabCoordinator.tabs, id: \.item.id) { tab in
                Tab(
                    value: tab.item.id,
                    role: tab.item.id == TabItem.search.id ? .search : nil
                ) {
                    #if os(tvOS)
                    GeometryReader { proxy in
                        tabRoot(tab)
                            .environment(\.tabSafeAreaInsets, proxy.safeAreaInsets)
                    }
                    #else
                    tabRoot(tab)
                    #endif
                } label: {
                    Label(
                        tab.item.displayTitle,
                        symbol: tab.item.systemImage
                    )
                    .symbolRenderingMode(.monochrome)
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent() -> some View {
        #if os(tvOS)
        switch tabBarPlacement {
        case .sidebar:
            tabView()
                .tabViewStyle(.sidebarAdaptable)

        case .tabBar:
            tabView()
                .tabViewStyle(.tabBarOnly)
        }
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            tabView()
        } else if #available(iOS 26, *) {
            // Collapse the tab bar to just the selected tab while scrolling down
            tabView()
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabView()
        }
        #endif
    }

    var body: some View {
        tabContent()
            .onAppear {
                // A deep link that signed in a user is set before this view exists
                routePendingDeepLink(userSessionManager.consumePendingDeepLink())

                #if os(iOS)
                WidgetSync.update(tabs: navigationTabs)
                #endif
            }
            .onChange(of: userSessionManager.pendingDeepLink) {
                routePendingDeepLink(userSessionManager.consumePendingDeepLink())
            }
            .onReceive(userSessionManager.routePublisher) { route in
                Task { @MainActor in
                    await tabCoordinator.route(to: route)
                }
            }
            .onChange(of: navigationTabs) {
                tabCoordinator.update(tabs: Self.tabItems(for: navigationTabs))

                #if os(iOS)
                WidgetSync.update(tabs: navigationTabs)
                #endif
            }
            #if os(tvOS)
            .background(alignment: .top) {
                FocusedPosterCinematicBackgroundView()
            }
            #endif
    }
}

#if os(iOS)
private struct TabRootSettingsBarButton: View {

    @Injected(\.currentUserSession)
    private var userSession

    @Router
    private var router

    var body: some View {
        if router.isRootOfPath,
           let userSession
        {
            SettingsBarButton(
                server: userSession.server,
                user: userSession.user
            ) {
                router.route(to: .settings)
            }
        }
    }
}
#endif
