//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

@MainActor
final class TabCoordinator: ObservableObject {

    struct SelectedEvent {
        let isRoot: Bool
        let isRepeat: Bool
    }

    typealias TabData = (
        item: TabItem,
        coordinator: NavigationCoordinator,
        publisher: TabItemSelectedPublisher
    )

    @Published
    var selectedTabID: String! = nil {
        didSet {
            guard let tab = tabs.first(property: \.item.id, equalTo: selectedTabID) else { return }

            tab.publisher.send(
                .init(
                    isRoot: tab.coordinator.path.isEmpty,
                    isRepeat: oldValue == selectedTabID
                )
            )
        }
    }

    @Published
    private(set) var tabs: [TabData]

    convenience init(@ArrayBuilder<TabItem> tabs: () -> [TabItem]) {
        self.init(tabs: tabs())
    }

    init(tabs: [TabItem]) {
        self.tabs = tabs.map { tab in
            (tab, NavigationCoordinator(), TabItemSelectedPublisher())
        }
        self.selectedTabID = tabs.first?.id
    }

    /// Replaces the tabs, keeping the navigation state of tabs that remain
    func update(tabs newTabs: [TabItem]) {
        tabs = newTabs.map { item in
            if let existing = tabs.first(where: { $0.item.id == item.id }) {
                (item, existing.coordinator, existing.publisher)
            } else {
                (item, NavigationCoordinator(), TabItemSelectedPublisher())
            }
        }

        if !tabs.contains(where: { $0.item.id == selectedTabID }) {
            selectedTabID = tabs.first?.item.id
        }
    }

    func route(to route: NavigationRoute) async {
        guard let tab = tabs.first(where: { $0.item.id == selectedTabID }) else { return }

        tab.coordinator.push(route)
    }
}
