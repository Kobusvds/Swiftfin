//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import UIKit

@MainActor
enum MacDockIcon {

    private static let storageKey = "macDockAppIcon"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }

    static var savedIcon: AppIcon {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppIcon.init(rawValue:)) ?? .blue
    }

    static func applySavedIcon() {
        guard isEnabled, savedIcon.alternateIconName != nil else { return }

        apply(savedIcon)
    }

    @discardableResult
    static func select(_ icon: AppIcon) -> Bool {
        guard isEnabled, apply(icon) else { return false }

        UserDefaults.standard.set(icon.rawValue, forKey: storageKey)
        return true
    }

    @discardableResult
    private static func apply(_ icon: AppIcon) -> Bool {
        guard let applicationClass = NSClassFromString("NSApplication") as? NSObject.Type,
              let application = applicationClass.perform(NSSelectorFromString("sharedApplication"))?
              .takeUnretainedValue() as? NSObject
        else { return false }

        let setIconSelector = NSSelectorFromString("setApplicationIconImage:")

        guard application.responds(to: setIconSelector) else { return false }

        guard icon.alternateIconName != nil else {
            application.perform(setIconSelector, with: nil)
            return true
        }

        guard let data = dockImageData(for: icon),
              let image = appKitImage(from: data)
        else { return false }

        application.perform(setIconSelector, with: image)
        return true
    }

    private static func dockImageData(for icon: AppIcon) -> Data? {
        guard let source = UIImage(named: icon.iconName) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let image = UIGraphicsImageRenderer(bounds: canvas, format: format).image { context in
            let shape = UIBezierPath(roundedRect: iconRect, cornerRadius: 185)

            context.cgContext.saveGState()
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 10),
                blur: 20,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            UIColor.black.setFill()
            shape.fill()
            context.cgContext.restoreGState()

            shape.addClip()
            source.draw(in: iconRect)
        }

        return image.pngData()
    }

    private static func appKitImage(from data: Data) -> NSObject? {
        guard let imageClass = NSClassFromString("NSImage") as? NSObject.Type,
              let allocated = imageClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject,
              let image = allocated.perform(NSSelectorFromString("initWithData:"), with: data)?
              .takeRetainedValue() as? NSObject
        else { return nil }

        return image
    }
}

extension AppIcon {

    @MainActor
    static var current: AppIcon {
        if MacDockIcon.isEnabled {
            MacDockIcon.savedIcon
        } else {
            resolve(alternateIconName: UIApplication.shared.alternateIconName)
        }
    }

    @MainActor
    static var isSelectable: Bool {
        UIApplication.shared.supportsAlternateIcons || MacDockIcon.isEnabled
    }
}
