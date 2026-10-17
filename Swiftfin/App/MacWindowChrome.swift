//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import UIKit

/// Gives the Mac window a Safari-style toolbar, where the close, minimize and zoom buttons
/// share a single row with the tab bar and navigation bar items.
///
/// "Designed for iPad" apps can't use AppKit or the Mac Catalyst title bar APIs, so the
/// window is configured through the Objective-C runtime. Each step checks that what it
/// needs exists, and does nothing otherwise.
@MainActor
enum MacWindowChrome {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }

    static func configure(_ windowScene: UIWindowScene) {
        guard isEnabled,
              let window = windowScene.windows.first,
              let nsWindow = nsWindow()
        else { return }

        configureTitlebar(of: nsWindow)

        if !window.subviews.contains(where: { $0 is TitlebarInsetView }) {
            window.addSubview(TitlebarInsetView())
        }
    }

    /// The width, in the app's points, that the window controls take up from the leading edge,
    /// or zero if they aren't shown in the app's top row, such as in full screen
    static func windowControlsWidth(in window: UIWindow) -> CGFloat {
        guard isEnabled,
              window.safeAreaInsets.top > 0,
              let nsWindow = nsWindow(),
              !isFullScreen(nsWindow),
              let zoomButton = standardWindowButton(.zoom, of: nsWindow),
              let buttonFrame = (zoomButton.value(forKey: "frame") as? NSValue)?.cgRectValue,
              let windowFrame = (nsWindow.value(forKey: "frame") as? NSValue)?.cgRectValue,
              windowFrame.width > 0
        else { return 0 }

        // The app is scaled to fit the Mac's points
        let scale = window.bounds.width / windowFrame.width

        return buttonFrame.maxX * scale
    }

    /// Whether the app's window is in full screen, where macOS hides the title bar
    /// until the pointer moves to the top of the screen
    static var isFullScreen: Bool {
        guard isEnabled, let nsWindow = nsWindow() else { return false }

        return isFullScreen(nsWindow)
    }

    /// In full screen, how far down, in the app's points, the menu bar and title bar that macOS
    /// slides in when the pointer is at the top of the screen currently cover the app
    static func fullScreenTitlebarOverlap(in window: UIWindow) -> CGFloat {
        guard isEnabled,
              let windows = appKitWindows(),
              let nsWindow = mainWindow(in: windows),
              isFullScreen(nsWindow),
              let titlebarWindow = windows.first(where: isFullScreenTitlebarWindow),
              titlebarWindow.value(forKey: "visible") as? Bool == true,
              let titlebarFrame = (titlebarWindow.value(forKey: "frame") as? NSValue)?.cgRectValue,
              let windowFrame = (nsWindow.value(forKey: "frame") as? NSValue)?.cgRectValue,
              windowFrame.width > 0
        else { return 0 }

        let scale = window.bounds.width / windowFrame.width
        // AppKit's y axis points up, so the title bar covers the window from its top edge down to its bottom
        let overlap = min(max(windowFrame.maxY - titlebarFrame.minY, 0), titlebarFrame.height)

        return overlap * scale
    }

    // MARK: - AppKit

    private enum WindowButton: UInt {
        case close = 0
        case minimize = 1
        case zoom = 2
    }

    // Raw values of the matching AppKit options
    private static let fullScreenStyleMask: UInt = 1 << 14
    private static let fullSizeContentViewStyleMask: UInt = 1 << 15
    private static let hiddenTitleVisibility = 1
    private static let unifiedCompactToolbarStyle = 4
    private static let noTitlebarSeparatorStyle = 1

    private static func appKitWindows() -> [NSObject]? {
        guard let applicationClass = NSClassFromString("NSApplication") as? NSObject.Type,
              let application = applicationClass.perform(NSSelectorFromString("sharedApplication"))?
              .takeUnretainedValue() as? NSObject
        else { return nil }

        return application.value(forKey: "windows") as? [NSObject]
    }

    private static func mainWindow(in windows: [NSObject]) -> NSObject? {
        guard let windowClass = NSClassFromString("UINSWindow") else { return nil }

        return windows.first { $0.isKind(of: windowClass) }
    }

    /// The app's main AppKit window, which hosts the UIKit window
    private static func nsWindow() -> NSObject? {
        appKitWindows().flatMap(mainWindow)
    }

    /// In full screen, macOS moves the title bar and toolbar into a separate window,
    /// which it slides in along with the menu bar
    private static func isFullScreenTitlebarWindow(_ window: NSObject) -> Bool {
        let className = NSStringFromClass(type(of: window))

        return className.contains("FullScreen") && className.contains("Toolbar")
    }

    private static func isFullScreen(_ nsWindow: NSObject) -> Bool {
        guard let styleMask = nsWindow.value(forKey: "styleMask") as? UInt else { return false }

        return styleMask & fullScreenStyleMask != 0
    }

    private static func configureTitlebar(of nsWindow: NSObject) {
        if let styleMask = nsWindow.value(forKey: "styleMask") as? UInt,
           styleMask & fullSizeContentViewStyleMask == 0
        {
            nsWindow.setValue(styleMask | fullSizeContentViewStyleMask, forKey: "styleMask")
        }

        nsWindow.setValue(true, forKey: "titlebarAppearsTransparent")
        nsWindow.setValue(hiddenTitleVisibility, forKey: "titleVisibility")
        nsWindow.setValue(noTitlebarSeparatorStyle, forKey: "titlebarSeparatorStyle")

        updateToolbar(of: nsWindow)
    }

    /// An empty compact toolbar moves the window controls down, closer to the center of the
    /// tab bar, without making the top row taller than it needs to be.
    ///
    /// In full screen, macOS shows the toolbar as an opaque strip across the top of the screen,
    /// which would cover the app's bars, and the window controls are hidden anyway, so the
    /// toolbar is removed until the window leaves full screen.
    private static func updateToolbar(of nsWindow: NSObject) {
        let hasToolbar = nsWindow.value(forKey: "toolbar") != nil
        let showsToolbar = !isFullScreen(nsWindow)

        if showsToolbar, !hasToolbar,
           let toolbarClass = NSClassFromString("NSToolbar") as? NSObject.Type
        {
            nsWindow.setValue(toolbarClass.init(), forKey: "toolbar")
            nsWindow.setValue(unifiedCompactToolbarStyle, forKey: "toolbarStyle")
        } else if !showsToolbar, hasToolbar {
            nsWindow.setValue(nil, forKey: "toolbar")
        }
    }

    /// Adds or removes the toolbar when the window enters or leaves full screen
    static func updateToolbar() {
        guard isEnabled, let nsWindow = nsWindow() else { return }

        updateToolbar(of: nsWindow)
    }

    private static func standardWindowButton(_ button: WindowButton, of nsWindow: NSObject) -> NSObject? {
        typealias StandardWindowButton = @convention(c) (AnyObject, Selector, UInt) -> Unmanaged<AnyObject>?

        let selector = NSSelectorFromString("standardWindowButton:")

        guard nsWindow.responds(to: selector) else { return nil }

        let function = unsafeBitCast(nsWindow.method(for: selector), to: StandardWindowButton.self)

        return function(nsWindow, selector, button.rawValue)?.takeUnretainedValue() as? NSObject
    }
}

extension MacWindowChrome {

    /// Lets the app's content fill the title bar area, so the tab bar and navigation bar
    /// sit in the same row as the window controls.
    ///
    /// Added directly to the window, and sized to fill it, so it's told whenever the title bar's
    /// height changes, such as when entering and leaving full screen. It's transparent
    /// rather than hidden, since hidden views aren't reliably told about safe area changes.
    ///
    /// In full screen, it follows the title bar that macOS slides in at the top of the screen
    /// and moves the content down to match, like Safari, so the bars aren't covered.
    private final class TitlebarInsetView: UIView {

        private var displayLink: CADisplayLink?

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if let window {
                frame = window.bounds
            } else {
                setFollowsFullScreenTitlebar(false)
            }

            update()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            update()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            update()
        }

        @objc
        private func update() {
            guard let window, let rootViewController = window.rootViewController else { return }

            let isFullScreen = MacWindowChrome.isFullScreen

            MacWindowChrome.updateToolbar()
            setFollowsFullScreenTitlebar(isFullScreen)

            // Move the content up into the title bar area. In full screen, while macOS slides in
            // the menu bar and title bar, move it back down so they don't cover the app's bars
            let overlap = isFullScreen ? MacWindowChrome.fullScreenTitlebarOverlap(in: window) : 0
            let top = overlap - window.safeAreaInsets.top

            if rootViewController.additionalSafeAreaInsets.top != top {
                rootViewController.additionalSafeAreaInsets.top = top
            }
        }

        /// The title bar slides in without telling the app, so check it each frame while in full screen
        private func setFollowsFullScreenTitlebar(_ follows: Bool) {
            if follows, displayLink == nil {
                let displayLink = CADisplayLink(target: self, selector: #selector(update))
                displayLink.add(to: .main, forMode: .common)
                self.displayLink = displayLink
            } else if !follows, let displayLink {
                displayLink.invalidate()
                self.displayLink = nil
            }
        }
    }
}

/// Moves a navigation bar's leading items, such as the back button, clear of the
/// Mac window controls without moving the navigation stack's content
struct MacWindowControlsNavigationInset: UIViewRepresentable {

    func makeUIView(context: Context) -> InsetView {
        InsetView()
    }

    func updateUIView(_ uiView: InsetView, context: Context) {
        uiView.update()
    }

    final class InsetView: UIView {

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if let windowScene = window?.windowScene {
                MacWindowChrome.configure(windowScene)
            }

            update()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            update()
        }

        func update() {
            guard let window,
                  let navigationController = navigationController()
            else { return }

            // Only the navigation stacks in the window's top row sit beside the window controls,
            // presented ones such as sheets don't
            let isInTopRow = navigationController.presentingViewController == nil &&
                navigationController.view.convert(CGPoint.zero, to: window).y <= 0
            let inset = isInTopRow ? MacWindowChrome.windowControlsWidth(in: window) : 0

            if navigationController.additionalSafeAreaInsets.left != inset {
                navigationController.additionalSafeAreaInsets.left = inset
            }

            // Cancel the inset for the content, so only the navigation bar moves
            for viewController in navigationController.viewControllers
                where viewController.additionalSafeAreaInsets.left != -inset
            {
                viewController.additionalSafeAreaInsets.left = -inset
            }
        }

        private func navigationController() -> UINavigationController? {
            var responder: UIResponder? = self

            while let next = responder?.next {
                if let navigationController = next as? UINavigationController {
                    return navigationController
                }
                responder = next
            }

            return nil
        }
    }
}

extension View {

    /// On Mac, keeps the navigation bar's leading items clear of the window controls
    @ViewBuilder
    func macWindowControlsNavigationInset() -> some View {
        if MacWindowChrome.isEnabled {
            background {
                MacWindowControlsNavigationInset()
                    .frame(width: 0, height: 0)
            }
        } else {
            self
        }
    }
}
