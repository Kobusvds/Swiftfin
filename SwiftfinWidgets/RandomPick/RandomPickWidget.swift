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
        case item(RandomPickItem)
        case empty
        case noLibrary
        case signedOut
        case unavailable
    }

    let date: Date
    let content: Content

    var hasItem: Bool {
        if case .item = content { true } else { false }
    }

    static let placeholder = RandomPickEntry(
        date: .now,
        content: .item(RandomPickItem(
            id: "placeholder",
            title: "Title",
            subtitle: "2026",
            imageData: nil,
            url: nil
        ))
    )
}

struct RandomPickProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> RandomPickEntry {
        .placeholder
    }

    func snapshot(for configuration: RandomPickConfigurationIntent, in context: Context) async -> RandomPickEntry {
        let entry = await entry(for: configuration)

        // Show sample content in the widget gallery rather than an empty state
        return context.isPreview && !entry.hasItem ? .placeholder : entry
    }

    func timeline(for configuration: RandomPickConfigurationIntent, in context: Context) async -> Timeline<RandomPickEntry> {
        // Pick something new every few hours, as well as whenever the dice is rolled
        let nextRefresh = Date.now.addingTimeInterval(6 * 60 * 60)
        return Timeline(entries: [await entry(for: configuration)], policy: .after(nextRefresh))
    }

    private func entry(for configuration: RandomPickConfigurationIntent) async -> RandomPickEntry {
        do {
            let libraryID: String

            if let library = configuration.library {
                libraryID = library.id
            } else if let library = try await RandomPickClient.libraries().first {
                libraryID = library.id
            } else {
                return RandomPickEntry(date: .now, content: .noLibrary)
            }

            guard let item = try await RandomPickClient.randomItem(libraryID: libraryID, imagePixelWidth: 700) else {
                return RandomPickEntry(date: .now, content: .empty)
            }

            return RandomPickEntry(date: .now, content: .item(item))
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
        .supportedFamilies([.systemMedium])
        // Artwork reaches the widget's edges
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct RandomPickWidgetView: View {

    let entry: RandomPickEntry

    var body: some View {
        HStack(spacing: 0) {
            Group {
                switch entry.content {
                case let .item(item):
                    if let url = item.url {
                        Link(destination: url) {
                            ItemArtworkView(item: item)
                        }
                    } else {
                        ItemArtworkView(item: item)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DiceButton()
                .frame(width: 104)
                .frame(maxHeight: .infinity)
        }
        // Taps outside the dice open the item, rather than the app's last screen
        .widgetURL(itemURL)
    }

    private var itemURL: URL? {
        if case let .item(item) = entry.content {
            item.url
        } else {
            nil
        }
    }
}

private struct ItemArtworkView: View {

    let item: RandomPickItem

    private var isPlaceholder: Bool {
        item.id == "placeholder"
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .widgetAccentedRenderingMode(.accentedDesaturated)
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
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
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
            }
            .clipped()
            .contentShape(.rect)
            // Dims while the dice loads the next pick
            .invalidatableContent()
    }
}

private struct DiceButton: View {

    var body: some View {
        Button(intent: RollRandomPickIntent()) {
            VStack(spacing: 6) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.widgetAccent)
                    .widgetAccentable()

                Text("Roll")
                    .font(.caption)
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
    RandomPickEntry.placeholder
    RandomPickEntry(date: .now, content: .signedOut)
}
