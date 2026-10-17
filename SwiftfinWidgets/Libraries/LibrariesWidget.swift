//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import WidgetKit

struct LibrariesEntry: TimelineEntry {

    struct Library: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let url: URL?
    }

    let date: Date
    let libraries: [Library]
    let isSignedIn: Bool

    static let placeholder = LibrariesEntry(
        date: .now,
        libraries: [
            .init(id: "movies", title: "Movies", systemImage: "film", url: nil),
            .init(id: "shows", title: "Shows", systemImage: "tv", url: nil),
            .init(id: "music", title: "Music", systemImage: "music.note", url: nil),
            .init(id: "home", title: "Home", systemImage: "house.fill", url: nil),
        ],
        isSignedIn: true
    )

    /// The first four navigation tabs, with media libraries before other tabs
    static func current() -> LibrariesEntry {
        guard let account = WidgetSharedStore.account else {
            return LibrariesEntry(date: .now, libraries: [], isSignedIn: false)
        }

        let tabs = WidgetSharedStore.tabs
        let orderedTabs = tabs.filter(\.isLibrary) + tabs.filter { !$0.isLibrary }

        let libraries = orderedTabs.prefix(4).map { tab in
            Library(
                id: tab.id,
                title: tab.title,
                systemImage: tab.systemImage,
                url: WidgetSharedStore.url(account: account, destination: "tab", id: tab.id)
            )
        }

        return LibrariesEntry(date: .now, libraries: libraries, isSignedIn: true)
    }
}

struct LibrariesProvider: TimelineProvider {

    func placeholder(in context: Context) -> LibrariesEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LibrariesEntry) -> Void) {
        let entry = LibrariesEntry.current()
        completion(context.isPreview && entry.libraries.isEmpty ? .placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LibrariesEntry>) -> Void) {
        // The app reloads this widget whenever its tabs or user change
        completion(Timeline(entries: [.current()], policy: .never))
    }
}

struct LibrariesWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedStore.WidgetKind.libraries,
            provider: LibrariesProvider()
        ) { entry in
            LibrariesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Libraries")
        .description("Jump straight to your media libraries.")
        .supportedFamilies([.systemSmall])
        // Tiles sit closer to the widget's edges than the default margins allow
        .contentMarginsDisabled()
    }
}

struct LibrariesWidgetView: View {

    let entry: LibrariesEntry

    var body: some View {
        if entry.isSignedIn, entry.libraries.isNotEmpty {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    tile(at: 0)
                    tile(at: 1)
                }
                GridRow {
                    tile(at: 2)
                    tile(at: 3)
                }
            }
            .padding(10)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(Color.widgetAccent)

                Text("Sign in to Swiftfin to see your libraries")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func tile(at index: Int) -> some View {
        if entry.libraries.indices.contains(index) {
            let library = entry.libraries[index]

            if let url = library.url {
                Link(destination: url) {
                    LibraryTile(library: library)
                }
            } else {
                LibraryTile(library: library)
            }
        } else {
            Color.clear
        }
    }
}

private struct LibraryTile: View {

    let library: LibrariesEntry.Library

    var body: some View {
        VStack(spacing: 4) {
            // Custom tab icons are symbols in the widget's asset catalog
            (UIImage(systemName: library.systemImage) != nil ? Image(systemName: library.systemImage) : Image(library.systemImage))
                .font(.title2)
                .foregroundStyle(Color.widgetAccent)
                .widgetAccentable()

            Text(library.title)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.fill.secondary, in: ContainerRelativeShape())
    }
}

private extension Collection {

    var isNotEmpty: Bool {
        !isEmpty
    }
}

#Preview(as: .systemSmall) {
    LibrariesWidget()
} timeline: {
    LibrariesEntry.placeholder
    LibrariesEntry(date: .now, libraries: [], isSignedIn: false)
}
