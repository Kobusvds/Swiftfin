//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import UIKit

/// Draws the dice posters that open a random pick from a library
enum TopShelfRandomTile {

    /// Poster size in points, matching `TopShelfClient.ImageShape.poster`
    private static let size = CGSize(width: 404, height: 606)

    /// Writes the poster at 1x and 2x into the app group container, which the system can read
    static func imageURLs(libraryID: String, title: String) -> (oneX: URL, twoX: URL)? {
        guard let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedStore.appGroupID)?
            .appending(path: "Library/Caches/TopShelf", directoryHint: .isDirectory)
        else { return nil }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // The title is part of the name so a renamed library gets a new image instead of a cached one.
        // `hashValue` changes every launch, so this uses a stable FNV-1a hash.
        let titleHash = title.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        let name = "random-v1-\(libraryID)-\(String(titleHash, radix: 36))"

        guard let oneX = write(scale: 1, title: title, to: directory.appending(path: "\(name).png")),
              let twoX = write(scale: 2, title: title, to: directory.appending(path: "\(name)@2x.png"))
        else { return nil }

        return (oneX, twoX)
    }

    private static func write(scale: CGFloat, title: String, to url: URL) -> URL? {
        if FileManager.default.fileExists(atPath: url.path()) {
            return url
        }

        guard let data = render(title: title, scale: scale).pngData(),
              (try? data.write(to: url, options: .atomic)) != nil
        else { return nil }

        return url
    }

    private static func render(title: String, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)

            // The Sunset app icon's gradient
            let colors = [
                UIColor(red: 1.0, green: 0.373, blue: 0.635, alpha: 1).cgColor,
                UIColor(red: 1.0, green: 0.643, blue: 0.239, alpha: 1).cgColor,
            ] as CFArray

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: bounds.midX, y: 0),
                    end: CGPoint(x: bounds.midX, y: bounds.maxY),
                    options: []
                )
            }

            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 6),
                blur: 18,
                color: UIColor.black.withAlphaComponent(0.25).cgColor
            )

            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 170, weight: .semibold)
            if let dice = UIImage(systemName: "dice.fill", withConfiguration: symbolConfiguration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            {
                let diceSize = dice.size
                dice.draw(in: CGRect(
                    x: bounds.midX - diceSize.width / 2,
                    y: bounds.height * 0.38 - diceSize.height / 2,
                    width: diceSize.width,
                    height: diceSize.height
                ))
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail

            let baseFont = UIFont.systemFont(ofSize: 52, weight: .heavy)
            let font = baseFont.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 52) } ?? baseFont

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]

            let titleRect = CGRect(x: 28, y: bounds.height * 0.62, width: bounds.width - 56, height: 140)
            (title as NSString).draw(
                with: titleRect,
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: attributes,
                context: nil
            )

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .paragraphStyle: paragraph,
            ]

            (String(localized: "Random Pick") as NSString).draw(
                with: CGRect(x: 28, y: bounds.height * 0.86, width: bounds.width - 56, height: 44),
                options: .usesLineFragmentOrigin,
                attributes: subtitleAttributes,
                context: nil
            )
        }
    }
}
