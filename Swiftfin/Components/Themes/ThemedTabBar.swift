//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import SwiftUIIntrospect

@MainActor
@Observable
final class ThemedTabBarScroll {

    private(set) var isCollapsed = false

    @ObservationIgnored
    private var anchor: CGFloat = 0
    @ObservationIgnored
    private var offset: CGFloat = 0
    @ObservationIgnored
    private weak var scrollView: UIScrollView?
    @ObservationIgnored
    private var observation: NSKeyValueObservation?

    private let threshold: CGFloat = 24

    func expand() {
        anchor = offset
        setCollapsed(false)
    }

    func observe(_ scrollView: UIScrollView) {
        guard scrollView !== self.scrollView else { return }

        self.scrollView = scrollView
        observation = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
            MainActor.assumeIsolated {
                self?.update(scrollView)
            }
        }
    }

    func update(offset newOffset: CGFloat, maxOffset: CGFloat) {
        let newOffset = min(newOffset, max(maxOffset, 0))
        offset = newOffset

        guard newOffset > 0 else {
            anchor = newOffset
            setCollapsed(false)
            return
        }

        if isCollapsed {
            anchor = max(anchor, newOffset)

            if anchor - newOffset > threshold {
                anchor = newOffset
                setCollapsed(false)
            }
        } else {
            anchor = min(anchor, newOffset)

            if newOffset - anchor > threshold {
                anchor = newOffset
                setCollapsed(true)
            }
        }
    }

    private func update(_ scrollView: UIScrollView) {
        let insets = scrollView.adjustedContentInset
        let newOffset = scrollView.contentOffset.y + insets.top

        guard scrollView.isTracking || scrollView.isDecelerating || newOffset <= 0 else { return }

        update(
            offset: newOffset,
            maxOffset: scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
        )
    }

    private func setCollapsed(_ newValue: Bool) {
        guard isCollapsed != newValue else { return }

        withAnimation(.snappy(duration: 0.35)) {
            isCollapsed = newValue
        }
    }
}

extension EnvironmentValues {

    @Entry
    var themedTabBarScroll: ThemedTabBarScroll? = nil
}

struct ThemedTabBarScrollObserver: ViewModifier {

    @Environment(\.themedTabBarScroll)
    private var scroll

    func body(content: Content) -> some View {
        content
            .introspect(.scrollView, on: .iOS(.v18...)) { scrollView in
                scroll?.observe(scrollView)
            }
    }
}

struct ThemedTabBarInset: ViewModifier {

    @Environment(\.tabCoordinator)
    private var tabCoordinator

    @State
    private var bottomSafeArea: CGFloat = 0
    @State
    private var scroll = ThemedTabBarScroll()

    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.themedTabBarScroll, scroll)
            .onScrollGeometryChange(for: ScrollPosition.self) { geometry in
                ScrollPosition(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    maxOffset: geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
                        - geometry.containerSize.height
                )
            } action: { _, position in
                scroll.update(offset: position.offset, maxOffset: position.maxOffset)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEnabled, let tabCoordinator {
                    ThemedTabBar(
                        tabCoordinator: tabCoordinator,
                        scroll: scroll,
                        bottomSafeArea: bottomSafeArea
                    )
                }
            }
            .background {
                Color.clear
                    .ignoresSafeArea(.keyboard)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.safeAreaInsets.bottom
                    } action: { newValue in
                        bottomSafeArea = newValue
                    }
            }
    }
}

private struct ScrollPosition: Equatable {

    let offset: CGFloat
    let maxOffset: CGFloat
}

private let skeuoTabLeather = LinearGradient.vertical(Color(hex: "#8F6039"), Color(hex: "#5E3A1F"))

private struct ThemedTabBar: View {

    @Environment(\.appTheme)
    private var theme

    @ObservedObject
    var tabCoordinator: TabCoordinator

    let scroll: ThemedTabBarScroll
    let bottomSafeArea: CGFloat

    private var isCollapsed: Bool {
        scroll.isCollapsed
    }

    private var floatingBottomPadding: CGFloat {
        24 - bottomSafeArea
    }

    private var collapsedBottomPadding: CGFloat {
        (theme == .y2k ? 28 : 30) - bottomSafeArea
    }

    private var selectedTab: TabItem? {
        tabCoordinator.tabs.first { $0.item.id == tabCoordinator.selectedTabID }?.item
    }

    private var spacing: CGFloat {
        switch theme {
        case .default:
            0
        case .skeuo:
            4
        case .y2k:
            2
        case .gameUI2:
            6
        }
    }

    private var items: some View {
        HStack(spacing: spacing) {
            ForEach(tabCoordinator.tabs, id: \.item.id) { tab in
                let isSelected = tab.item.id == tabCoordinator.selectedTabID

                Button {
                    tabCoordinator.select(tabID: tab.item.id)
                } label: {
                    ThemedTabBarItem(
                        title: tab.item.displayTitle,
                        systemImage: tab.item.systemImage,
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var expandedBar: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            items
                .padding(4)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Skeuo.stitch, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, bottomSafeArea > 0 ? floatingBottomPadding : 6)
                .background {
                    skeuoTabLeather
                        .overlay(alignment: .top) {
                            VStack(spacing: 0) {
                                Skeuo.leatherEdge
                                    .frame(height: 1)

                                Color.white.opacity(0.3)
                                    .frame(height: 1)
                            }
                        }
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.55), radius: 4, y: -3)
                        .ignoresSafeArea(edges: [.horizontal, .bottom])
                }
        case .y2k:
            items
                .padding(7)
                .background {
                    Y2KChromeBackground(shape: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.bottom, floatingBottomPadding)
        case .gameUI2:
            items
                .padding(10)
                .background {
                    GamePanelBackground()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, floatingBottomPadding)
        }
    }

    var body: some View {
        let slidesAway = theme == .skeuo

        ZStack(alignment: .bottomLeading) {
            expandedBar
                .scaleEffect(isCollapsed && !slidesAway ? 0.3 : 1, anchor: .bottomLeading)
                .opacity(isCollapsed && !slidesAway ? 0 : 1)
                .offset(y: isCollapsed && slidesAway ? 110 : 0)
                .allowsHitTesting(!isCollapsed)
                .accessibilityHidden(isCollapsed)

            if let selectedTab {
                ThemedTabBarCollapsedButton(
                    title: selectedTab.displayTitle,
                    systemImage: selectedTab.systemImage
                ) {
                    scroll.expand()
                }
                .padding(.leading, 16)
                .padding(.bottom, collapsedBottomPadding)
                .scaleEffect(isCollapsed ? 1 : 0.5, anchor: .bottomLeading)
                .opacity(isCollapsed ? 1 : 0)
                .allowsHitTesting(isCollapsed)
                .accessibilityHidden(!isCollapsed)
            }
        }
    }
}

struct ThemedTabIcon: View {

    let systemImage: String
    let size: CGFloat

    var body: some View {
        Image(symbol: systemImage)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.monochrome)
            .frame(width: size, height: size)
    }
}

private struct ThemedTabBarItem: View {

    @Environment(\.appTheme)
    private var theme

    let title: String
    let systemImage: String
    let isSelected: Bool

    private func label(_ font: Font) -> some View {
        Text(title)
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            let shape = RoundedRectangle(cornerRadius: 7)

            VStack(spacing: 3) {
                ThemedTabIcon(systemImage: systemImage, size: 24)

                label(Skeuo.font(10.5, .bold))
            }
            .foregroundStyle(isSelected ? Skeuo.amberText : Skeuo.cream)
            .shadow(
                color: isSelected ? .white.opacity(0.6) : .black.opacity(0.65),
                radius: 0,
                y: isSelected ? 1 : -1
            )
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if isSelected {
                    shape
                        .fill(Skeuo.amber.shadow(.inner(color: .black.opacity(0.18), radius: 2.5, y: 2)))
                        .overlay(alignment: .top) {
                            Color.white.opacity(0.75)
                                .frame(height: 1)
                                .padding(.top, 1)
                        }
                        .clipShape(shape)
                        .overlay {
                            shape.strokeBorder(Skeuo.amberEdge)
                        }
                        .compositingGroup()
                        .shadow(color: .white.opacity(0.25), radius: 0, y: 1)
                }
            }
            .contentShape(shape)
        case .y2k:
            VStack(spacing: 2) {
                ThemedTabIcon(systemImage: systemImage, size: 25)
                    .shadow(
                        color: isSelected ? Y2K.lime.opacity(0.6) : .white.opacity(0.8),
                        radius: isSelected ? 2 : 0,
                        y: isSelected ? 0 : 1
                    )

                label(Y2K.font(11.5, .semibold))
                    .shadow(color: .white.opacity(isSelected ? 0 : 0.8), radius: 0, y: 1)
            }
            .foregroundStyle(isSelected ? Y2K.lime : Y2K.navy)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isSelected {
                    Y2KSelectedGel(shape: Capsule())
                }
            }
            .contentShape(.capsule)
        case .gameUI2:
            VStack(spacing: 2) {
                ThemedTabIcon(systemImage: systemImage, size: 25)
                    .shadow(color: isSelected ? .clear : GameUI.outline, radius: 0, y: 2)

                label(GameUI.title(11.5))
                    .modifier(GameTabTextOutline(isEnabled: !isSelected))
            }
            .foregroundStyle(isSelected ? GameUI.outline : .white)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                GameSlotBackground(isSelected: isSelected)
            }
            .contentShape(RoundedRectangle(cornerRadius: 15))
        }
    }
}

private struct ThemedTabBarCollapsedButton: View {

    @Environment(\.appTheme)
    private var theme

    let title: String
    let systemImage: String
    let action: () -> Void

    @ViewBuilder
    private var label: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            ThemedTabIcon(systemImage: systemImage, size: 26)
                .foregroundStyle(Skeuo.amberText)
                .shadow(color: .white.opacity(0.6), radius: 0, y: 1)
                .frame(width: 46, height: 46)
                .background {
                    Circle()
                        .fill(Skeuo.amber.shadow(.inner(color: .black.opacity(0.18), radius: 2.5, y: 2)))
                        .overlay {
                            Circle()
                                .trim(from: 0.6, to: 0.9)
                                .stroke(.white.opacity(0.75), lineWidth: 1)
                                .padding(1.5)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(Skeuo.amberEdge)
                        }
                        .compositingGroup()
                        .shadow(color: .white.opacity(0.25), radius: 0, y: 1)
                }
                .frame(width: 66, height: 66)
                .background {
                    Circle()
                        .fill(skeuoTabLeather)
                        .overlay {
                            Circle()
                                .trim(from: 0.6, to: 0.9)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                .padding(1.5)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(Skeuo.leatherEdge)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(Skeuo.stitch, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .padding(4)
                        }
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.65), radius: 5, y: 4)
                }
                .contentShape(.circle)
        case .y2k:
            ThemedTabIcon(systemImage: systemImage, size: 27)
                .foregroundStyle(Y2K.lime)
                .shadow(color: Y2K.lime.opacity(0.6), radius: 2)
                .frame(width: 54, height: 54)
                .background {
                    Y2KSelectedGel(shape: Circle())
                }
                .frame(width: 70, height: 70)
                .background {
                    Y2KChromeBackground(shape: Circle())
                }
                .contentShape(.circle)
        case .gameUI2:
            ThemedTabIcon(systemImage: systemImage, size: 30)
                .foregroundStyle(GameUI.outline)
                .frame(width: 58, height: 58)
                .background {
                    GameSlotBackground(isSelected: true)
                }
                .frame(width: 78, height: 78)
                .background {
                    GamePanelBackground()
                }
                .contentShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(L10n.showAllLibraries)")
    }
}

private struct Y2KChromeBackground<S: InsettableShape>: View {

    let shape: S

    var body: some View {
        shape
            .fill(Y2K.chrome)
            .overlay(alignment: .top) {
                shape
                    .trim(from: 0.6, to: 0.9)
                    .stroke(.white, lineWidth: 1)
                    .padding(1)
            }
            .overlay {
                shape
                    .strokeBorder(Y2K.chromeEdge)
            }
            .compositingGroup()
            .shadow(color: Y2K.shadow.opacity(0.4), radius: 10, y: 8)
            .shadow(color: Y2K.shadow.opacity(0.25), radius: 2, y: 2)
    }
}

private struct Y2KSelectedGel<S: InsettableShape>: View {

    let shape: S

    var body: some View {
        Color.clear
            .y2kGel(Y2K.navy, edge: Y2K.navy, in: shape, isDark: true)
            .padding(2)
            .background(Y2K.lime, in: shape)
            .padding(-2)
            .shadow(color: Y2K.navy.opacity(0.5), radius: 3, y: 2)
    }
}

private struct GamePanelBackground: View {

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24)

        shape
            .fill(GameUI.panel)
            .overlay(alignment: .top) {
                Color.white.opacity(0.18)
                    .frame(height: 2)
                    .padding(.top, 3)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(GameUI.outline, lineWidth: 3)
            }
            .background {
                shape
                    .fill(GameUI.outline)
                    .offset(y: 6)
            }
            .compositingGroup()
            .shadow(color: GameUI.outline.opacity(0.45), radius: 9, y: 10)
    }
}

private struct GameSlotBackground: View {

    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15)

        shape
            .fill(isSelected ? GameUI.yellow : GameUI.well)
            .overlay(alignment: .top) {
                Group {
                    if isSelected {
                        Color.white.opacity(0.6)
                            .frame(height: 2)
                    } else {
                        Color.black.opacity(0.35)
                            .frame(height: 3)
                    }
                }
                .padding(.top, 3)
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    Color.black.opacity(0.15)
                        .frame(height: 4)
                        .padding(.bottom, 3)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(GameUI.outline, lineWidth: 3)
            }
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(.white)
                        .padding(-2)
                }
            }
    }
}
