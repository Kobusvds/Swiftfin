//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension EnvironmentValues {

    /// Content placed at the top of a library's items that scrolls along with them, such as filters
    @Entry
    var libraryHeader: AnyView? = nil
}

#if os(iOS)
import UIKit

/// Hosts a SwiftUI view inside a UIKit scroll view, above its content, so it scrolls natively
/// with the items. Used for `CollectionVGrid`, which doesn't support headers in grid layouts.
///
/// The content's top inset must include `height` so items start below the header.
@MainActor
final class ScrollViewHeaderHost: ObservableObject {

    @Published
    private(set) var height: CGFloat = 0

    private var hostingController: UIHostingController<AnyView>?
    private var boundsObservation: NSKeyValueObservation?
    private var lastWidth: CGFloat = 0
    private weak var scrollView: UIScrollView?

    func attach(_ content: AnyView, to scrollView: UIScrollView) {
        guard scrollView !== self.scrollView || hostingController == nil else { return }

        detach()
        self.scrollView = scrollView

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.safeAreaRegions = []
        hostingController.view.layer.zPosition = 1
        scrollView.addSubview(hostingController.view)
        self.hostingController = hostingController

        // Only relayout when the width changes, not on every scroll
        boundsObservation = scrollView.observe(\.bounds, options: [.new]) { [weak self] scrollView, _ in
            MainActor.assumeIsolated {
                guard let self, scrollView.bounds.width != self.lastWidth else { return }
                self.layout()
            }
        }

        layout()
    }

    func detach() {
        boundsObservation = nil
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        scrollView = nil
        lastWidth = 0
        setHeight(0)
    }

    private func layout() {
        guard let scrollView, let hostingController else { return }

        let width = scrollView.bounds.width
        guard width > 0 else { return }

        lastWidth = width

        let size = hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        hostingController.view.frame = CGRect(x: 0, y: 0, width: width, height: size.height)

        setHeight(size.height)
    }

    private func setHeight(_ newHeight: CGFloat) {
        guard height != newHeight else { return }

        // Avoid publishing during a SwiftUI view update
        DispatchQueue.main.async { [weak self] in
            self?.height = newHeight
        }
    }
}
#endif
