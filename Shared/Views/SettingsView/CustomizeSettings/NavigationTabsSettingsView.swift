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

struct NavigationTabsSettingsView: View {

    @Default(.Customization.navigationTabs)
    private var tabs

    @Environment(\.editMode)
    private var editMode

    @Injected(\.currentUserSession)
    private var userSession

    @Router
    private var router

    @State
    private var libraries: [BaseItemDto] = []
    @State
    private var isResetConfirmationPresented = false

    private var isReordering: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    /// Built-in tabs and media libraries that are not currently in the navigation
    private var availableTabs: [NavigationTab] {
        let libraryTabs = libraries.compactMap(NavigationTab.init(library:))

        return (NavigationTab.defaultTabs + libraryTabs)
            .filter { tab in !tabs.contains(where: { $0.id == tab.id }) }
    }

    private func loadLibraries() async {
        guard let userSession else { return }

        do {
            let parameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
            let response = try await userSession.send(Paths.getUserViews(parameters: parameters))

            libraries = (response.value.items ?? []).filter { library in
                CollectionType.supportedCases.contains(library.collectionType ?? .folders)
            }
        } catch {
            libraries = []
        }
    }

    @ViewBuilder
    private var editButton: some View {
        Button(isReordering ? L10n.done : L10n.edit) {
            editMode?.wrappedValue = isReordering ? .inactive : .active
        }
        #if os(iOS)
        .backport
        .buttonStyle(.glass)
        .controlSize(.small)
        #endif
    }

    @ViewBuilder
    private func tabLabel(_ tab: NavigationTab) -> some View {
        Label(tab.displayTitle, systemImage: tab.systemImage)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary, .secondary)
    }

    @ViewBuilder
    private func enabledRow(_ tab: NavigationTab) -> some View {
        HStack {
            Button {
                router.route(to: .navigationTabIcon(tab: tab))
            } label: {
                HStack {
                    tabLabel(tab)

                    Spacer()

                    if !isReordering {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(isReordering)

            if !isReordering {
                Button {
                    tabs.removeAll { $0.id == tab.id }
                    UIDevice.impact(.light)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                // Always keep at least one tab in the navigation
                .disabled(tabs.count <= 1)
                .opacity(tabs.count <= 1 ? 0.3 : 1)
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func availableRow(_ tab: NavigationTab) -> some View {
        Button {
            tabs.append(tab)
            UIDevice.impact(.light)
        } label: {
            LabeledContent {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            } label: {
                tabLabel(tab)
            }
        }
        .disabled(isReordering)
    }

    var body: some View {
        Form(systemImage: "dock.rectangle") {
            Section {
                ForEach(tabs) { tab in
                    enabledRow(tab)
                }
                .onMove { source, destination in
                    tabs.move(fromOffsets: source, toOffset: destination)
                }
            } header: {
                Text(L10n.enabled)
            } footer: {
                Text("Tap a tab to change its icon. Tap Edit to change the order.")
            }

            Section(L10n.disabled) {
                if availableTabs.isEmpty {
                    Text(L10n.none)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableTabs) { tab in
                        availableRow(tab)
                    }
                }
            }

            Section {
                Button("Reset to Default", role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .disabled(tabs == NavigationTab.defaultTabs)
            } footer: {
                Text("Restores the Home, Search and Media tabs with their original icons.")
            }
        }
        .navigationTitle(L10n.tabBar)
        .animation(.linear(duration: 0.2), value: tabs)
        .animation(.linear(duration: 0.2), value: editMode?.wrappedValue)
        .toolbar {
            editButton
        }
        .confirmationDialog(
            "Reset to Default",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.reset, role: .destructive) {
                tabs = NavigationTab.defaultTabs
            }
        } message: {
            Text("Your tab choices, order and icons will be replaced with the defaults.")
        }
        .task {
            await loadLibraries()
        }
    }
}

extension NavigationTabsSettingsView {

    struct IconPicker: View {

        // Observed directly so the grid updates as soon as an icon is chosen
        @Default(.Customization.navigationTabs)
        private var tabs

        let tab: NavigationTab

        private var selection: String {
            get {
                tabs.first(where: { $0.id == tab.id })?.systemImage ?? tab.systemImage
            }
            nonmutating set {
                guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
                tabs[index].systemImage = newValue
            }
        }

        private var symbols: [String] {
            // Always offer the tab's default icon, even if it isn't in the curated list
            NavigationTab.availableSystemImages
                .prepending(tab.defaultSystemImage, if: !NavigationTab.availableSystemImages.contains(tab.defaultSystemImage))
        }

        private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

        var body: some View {
            Form(systemImage: selection) {
                Section {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button {
                                selection = symbol
                                UIDevice.impact(.light)
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title2)
                                    .frame(width: 56, height: 56)
                                    .foregroundStyle(selection == symbol ? Color.white : Color.primary)
                                    .background(
                                        selection == symbol ? Color.accentColor : Color.secondary.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                            .accessibilityAddTraits(selection == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button("Use Default Icon") {
                        selection = tab.defaultSystemImage
                    }
                    .disabled(selection == tab.defaultSystemImage)
                }
            }
            .navigationTitle(tab.displayTitle)
        }
    }
}
