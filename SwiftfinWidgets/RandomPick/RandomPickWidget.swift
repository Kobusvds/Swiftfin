//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import AppIntents
import SwiftUI
import WidgetKit

struct RandomPickEntry: TimelineEntry {

    enum Content {
        case items([RandomPickItem])
        case empty
        case noLibrary
        case signedOut
        case unavailable
    }

    let date: Date
    let content: Content

    var hasItem: Bool {
        if case .items = content { true } else { false }
    }

    static func placeholder(count: Int) -> RandomPickEntry {
        RandomPickEntry(
            date: .now,
            content: .items((0 ..< count).map { index in
                RandomPickItem(
                    id: "placeholder-\(index)",
                    title: "Title",
                    subtitle: "2026",
                    imageData: nil,
                    url: nil
                )
            })
        )
    }
}

struct RandomPickProvider: AppIntentTimelineProvider {

    /// The large widget shows two picks, the medium one
    private func itemCount(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 2 : 1
    }

    func placeholder(in context: Context) -> RandomPickEntry {
        .placeholder(count: itemCount(for: context.family))
    }

    func snapshot(for configuration: RandomPickConfigurationIntent, in context: Context) async -> RandomPickEntry {
        let entry = await entry(for: configuration, count: itemCount(for: context.family))

        // Show sample content in the widget gallery rather than an empty state
        return context.isPreview && !entry.hasItem ? .placeholder(count: itemCount(for: context.family)) : entry
    }

    func timeline(for configuration: RandomPickConfigurationIntent, in context: Context) async -> Timeline<RandomPickEntry> {
        // Pick something new every few hours, as well as whenever the dice is rolled
        let nextRefresh = Date.now.addingTimeInterval(6 * 60 * 60)
        let entry = await entry(for: configuration, count: itemCount(for: context.family))
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func entry(for configuration: RandomPickConfigurationIntent, count: Int) async -> RandomPickEntry {
        do {
            let libraryID: String

            if let library = configuration.library {
                libraryID = library.id
            } else if let library = try await RandomPickClient.libraries().first {
                libraryID = library.id
            } else {
                return RandomPickEntry(date: .now, content: .noLibrary)
            }

            // The large widget's artwork spans its full width
            let items = try await RandomPickClient.randomItems(
                libraryID: libraryID,
                count: count,
                imagePixelWidth: count > 1 ? 1000 : 700
            )

            guard !items.isEmpty else {
                return RandomPickEntry(date: .now, content: .empty)
            }

            return RandomPickEntry(date: .now, content: .items(items))
        } catch RandomPickClient.ClientError.signedOut {
            return RandomPickEntry(date: .now, content: .signedOut)
        } catch {
            return RandomPickEntry(date: .now, content: .unavailable)
        }
    }
}

struct RandomPickWidget: Widget {

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetSharedStore.WidgetKind.randomPick,
            intent: RandomPickConfigurationIntent.self,
            provider: RandomPickProvider()
        ) { entry in
            RandomPickWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Random Pick")
        .description("Roll the dice for something to watch.")
        .supportedFamilies([.systemMedium, .systemLarge])
        // Artwork reaches the widget's edges
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct RandomPickWidgetView: View {

    @Environment(\.widgetFamily)
    private var widgetFamily

    let entry: RandomPickEntry

    var body: some View {
        if widgetFamily == .systemLarge {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                DiceButton(axis: .horizontal)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                DiceButton(axis: .vertical)
                    .frame(width: 104)
                    .frame(maxHeight: .infinity)
            }
            // Taps outside the dice open the item, rather than the app's last screen
            .widgetURL(itemURL)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case let .items(items):
            VStack(spacing: 2) {
                ForEach(items) { item in
                    if let url = item.url {
                        Link(destination: url) {
                            ItemArtworkView(item: item)
                        }
                    } else {
                        ItemArtworkView(item: item)
                    }
                }
            }
        case .empty:
            MessageView(systemImage: "film.stack", message: "No movies or shows in this library")
        case .noLibrary:
            MessageView(systemImage: "rectangle.stack", message: "Choose a library in the widget's settings")
        case .signedOut:
            MessageView(systemImage: "person.crop.circle", message: "Sign in to Swiftfin to get a random pick")
        case .unavailable:
            MessageView(systemImage: "wifi.exclamationmark", message: "Unable to connect to your server")
        }
    }

    private var itemURL: URL? {
        if case let .items(items) = entry.content {
            items.first?.url
        } else {
            nil
        }
    }
}

private struct ItemArtworkView: View {

    let item: RandomPickItem

    private var isPlaceholder: Bool {
        item.id.hasPrefix("placeholder")
    }

    // The title is the tile's base, with the artwork behind it. Widgets drop a `Link` whose
    // label is a `Color` with the artwork in an overlay, so tapping wouldn't open the item.
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.headline)
                .lineLimit(2)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .redacted(reason: isPlaceholder ? .placeholder : [])
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .background {
            if let image = item.image {
                // No `widgetAccentedRenderingMode`, which also stops the `Link` from opening the item
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.widgetAccent.opacity(0.8), Color.widgetAccent.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "film")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .clipped()
    }
}

private struct DiceButton: View {

    /// Stacks the dice above its label beside the artwork, or beside its label below it
    let axis: Axis

    var body: some View {
        Button(intent: RollRandomPickIntent()) {
            let layout = axis == .vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))

            layout {
                Image(systemName: "dice.fill")
                    .font(.system(size: axis == .vertical ? 36 : 26))
                    .foregroundStyle(Color.widgetAccent)
                    .widgetAccentable()

                Text("Roll")
                    .font(axis == .vertical ? .caption : .subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pick another")
    }
}

private struct MessageView: View {

    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.widgetAccent)

            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    RandomPickWidget()
} timeline: {
    RandomPickEntry.placeholder(count: 1)
    RandomPickEntry(date: .now, content: .signedOut)
}

#Preview(as: .systemLarge) {
    RandomPickWidget()
} timeline: {
    RandomPickEntry.placeholder(count: 2)
    RandomPickEntry(date: .now, content: .signedOut)
}
