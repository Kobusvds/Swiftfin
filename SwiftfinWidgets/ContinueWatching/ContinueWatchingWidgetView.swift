//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import WidgetKit

struct ContinueWatchingWidgetView: View {

    @Environment(\.widgetFamily)
    private var family

    let entry: ContinueWatchingEntry

    var body: some View {
        switch entry.content {
        case let .items(items) where !items.isEmpty:
            if family == .systemSmall, let item = items.first {
                SmallItemView(item: item)
            } else {
                ItemGridView(items: items, grid: family.continueWatchingGrid)
                    .containerBackground(.fill.tertiary, for: .widget)
            }

        case .items:
            MessageView(
                systemImage: "play.rectangle.on.rectangle",
                message: "Nothing to continue watching"
            )

        case .signedOut:
            MessageView(
                systemImage: "person.crop.circle",
                message: "Sign in to Swiftfin to see what to watch next"
            )

        case .unavailable:
            MessageView(
                systemImage: "wifi.exclamationmark",
                message: "Unable to connect to your server"
            )
        }
    }
}

// MARK: - Small

/// A single item with its artwork filling the widget
private struct SmallItemView: View {

    let item: ContinueWatchingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)

            Text(item.title)
                .font(.headline)
                .lineLimit(2)

            if let subtitle = item.subtitle, subtitle.isNotEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            ProgressRow(item: item)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(14)
        .redacted(reason: item.isPlaceholder ? .placeholder : [])
        .containerBackground(for: .widget) {
            ItemArtwork(item: item)
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
        }
        .widgetURL(item.url)
    }
}

// MARK: - Grid

private struct ItemGridView: View {

    let items: [ContinueWatchingItem]
    let grid: (columns: Int, rows: Int)

    /// Medium widgets don't have room for a header
    private var showsHeader: Bool {
        grid.rows > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                Text("Continue Watching")
                    .font(.headline)
                    .padding(.bottom, 10)
            }

            // Rows share the available height, with artwork growing to fill it
            VStack(spacing: 10) {
                ForEach(0 ..< grid.rows, id: \.self) { row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(0 ..< grid.columns, id: \.self) { column in
                            let index = row * grid.columns + column

                            Group {
                                if items.indices.contains(index) {
                                    ItemTile(item: items[index])
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ItemTile: View {

    let item: ContinueWatchingItem

    var body: some View {
        if let url = item.url {
            Link(destination: url) {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    ItemArtwork(item: item)
                }
                .overlay(alignment: .bottom) {
                    ProgressBar(progress: item.progress)
                        .padding(6)
                }
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let caption = item.gridCaption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .redacted(reason: item.isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Components

private struct ItemArtwork: View {

    let item: ContinueWatchingItem

    var body: some View {
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
}

private struct ProgressRow: View {

    let item: ContinueWatchingItem

    var body: some View {
        HStack(spacing: 6) {
            ProgressBar(progress: item.progress)

            if let remaining = item.remainingText {
                Text(remaining)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

private struct ProgressBar: View {

    let progress: Double

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.35))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * progress)
                        .widgetAccentable()
                }
            }
            .frame(height: 4)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Formatting

private extension ContinueWatchingItem {

    var isPlaceholder: Bool {
        id.hasPrefix("placeholder-")
    }

    /// For example, "23 min left"
    var remainingText: String? {
        guard let remainingSeconds, remainingSeconds >= 60 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = remainingSeconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated

        guard let duration = formatter.string(from: TimeInterval(remainingSeconds)) else { return nil }
        return String(localized: "\(duration) left")
    }

    var gridCaption: String? {
        [subtitle, remainingText]
            .compactMap(\.self)
            .filter(\.isNotEmpty)
            .joined(separator: " · ")
            .nilIfEmpty
    }
}

private extension String {

    var isNotEmpty: Bool {
        !isEmpty
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
