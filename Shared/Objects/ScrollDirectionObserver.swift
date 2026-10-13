//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(iOS)
import SwiftUI
import UIKit

/// Tracks whether a UIKit scroll view is being scrolled down, for views that SwiftUI's
/// scroll modifiers can't observe, such as `CollectionVGrid`
@MainActor
final class ScrollDirectionObserver: ObservableObject {

    @Published
    private(set) var isScrollingDown = false

    /// Distance to scroll in one direction before the state changes
    private let threshold: CGFloat = 12

    private var lastOffset: CGFloat = 0
    private var observation: NSKeyValueObservation?
    private weak var scrollView: UIScrollView?

    func observe(_ scrollView: UIScrollView) {
        guard scrollView !== self.scrollView else { return }

        self.scrollView = scrollView
        lastOffset = scrollView.contentOffset.y

        observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            MainActor.assumeIsolated {
                self?.update(with: scrollView)
            }
        }
    }

    /// Shifts the scroll position by the change in the content's top inset so visible content
    /// stays in place, such as when a bar above the content collapses or expands
    func compensateForTopInsetChange(_ delta: CGFloat) {
        guard let scrollView, delta != 0 else { return }

        let minimumOffset = -scrollView.adjustedContentInset.top

        // At the top, let the content follow the inset instead
        guard scrollView.contentOffset.y > minimumOffset + threshold else { return }

        let newOffset = max(minimumOffset, scrollView.contentOffset.y + delta)
        lastOffset += newOffset - scrollView.contentOffset.y
        scrollView.contentOffset.y = newOffset
    }

    private func update(with scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let topOffset = -scrollView.adjustedContentInset.top
        let bottomOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom

        // Always show at the top of the content
        guard offset > topOffset + threshold else {
            setScrollingDown(false)
            lastOffset = offset
            return
        }

        // Ignore layout driven offset changes and the bounce at the bottom edge
        guard scrollView.isTracking || scrollView.isDecelerating, offset <= bottomOffset else { return }

        let delta = offset - lastOffset
        guard abs(delta) > threshold else { return }

        setScrollingDown(delta > 0)
        lastOffset = offset
    }

    private func setScrollingDown(_ newValue: Bool) {
        guard isScrollingDown != newValue else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isScrollingDown = newValue
        }
    }
}
#endif
