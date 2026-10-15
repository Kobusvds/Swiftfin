//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import WidgetKit

struct ContinueWatchingEntry: TimelineEntry {

    enum Content {
        case items([ContinueWatchingItem])
        case signedOut
        case unavailable
    }

    let date: Date
    let content: Content

    var hasItems: Bool {
        if case let .items(items) = content {
            !items.isEmpty
        } else {
            false
        }
    }

    static let placeholder = ContinueWatchingEntry(
        date: .now,
        content: .items(ContinueWatchingItem.placeholders)
    )
}

struct ContinueWatchingProvider: TimelineProvider {

    func placeholder(in context: Context) -> ContinueWatchingEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueWatchingEntry) -> Void) {
        Task {
            let entry = await entry(for: context.family)

            // Show sample content in the widget gallery rather than an empty state
            if context.isPreview, !entry.hasItems {
                completion(.placeholder)
            } else {
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueWatchingEntry>) -> Void) {
        Task {
            let entry = await entry(for: context.family)

            // The app also reloads the widget when it moves to the background
            let nextRefresh = Date.now.addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func entry(for family: WidgetFamily) async -> ContinueWatchingEntry {
        do {
            let items = try await ContinueWatchingClient.items(
                limit: family.continueWatchingItemCount,
                imagePixelWidth: family == .systemSmall ? 600 : 480
            )
            return ContinueWatchingEntry(date: .now, content: .items(items))
        } catch ContinueWatchingClient.ClientError.signedOut {
            return ContinueWatchingEntry(date: .now, content: .signedOut)
        } catch {
            return ContinueWatchingEntry(date: .now, content: .unavailable)
        }
    }
}

struct ContinueWatchingWidget: Widget {

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]

        if #available(iOS 27, *) {
            families.append(.systemExtraLargePortrait)
        }

        return families
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedStore.WidgetKind.continueWatching,
            provider: ContinueWatchingProvider()
        ) { entry in
            ContinueWatchingWidgetView(entry: entry)
        }
        .configurationDisplayName("Continue Watching")
        .description("Pick up where you left off.")
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
    }
}

extension WidgetFamily {

    /// The number of items laid out as columns and rows
    var continueWatchingGrid: (columns: Int, rows: Int) {
        switch self {
        case .systemSmall:
            (1, 1)
        case .systemMedium:
            (2, 1)
        case .systemLarge:
            (2, 2)
        case .systemExtraLarge:
            (4, 2)
        default:
            // Extra large portrait
            (2, 4)
        }
    }

    var continueWatchingItemCount: Int {
        continueWatchingGrid.columns * continueWatchingGrid.rows
    }
}

extension ContinueWatchingItem {

    static let placeholders: [ContinueWatchingItem] = (0 ..< 8).map { index in
        ContinueWatchingItem(
            id: "placeholder-\(index)",
            title: "Title",
            subtitle: "S1, E1 · Episode",
            progress: 0.4,
            remainingSeconds: 1800,
            imageData: nil,
            url: nil
        )
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    ContinueWatchingWidget()
} timeline: {
    ContinueWatchingEntry.placeholder
    ContinueWatchingEntry(date: .now, content: .signedOut)
}

#Preview(as: .systemMedium) {
    ContinueWatchingWidget()
} timeline: {
    ContinueWatchingEntry.placeholder
}

#Preview(as: .systemLarge) {
    ContinueWatchingWidget()
} timeline: {
    ContinueWatchingEntry.placeholder
    ContinueWatchingEntry(date: .now, content: .items([]))
}
