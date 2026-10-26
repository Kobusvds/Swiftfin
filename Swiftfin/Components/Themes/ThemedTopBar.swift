//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import SwiftUI

struct ThemedTopBar<MenuContent: View>: View {

    @Environment(\.appTheme)
    private var theme
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    @Environment(\.parentRouteTitle)
    private var parentRouteTitle
    @Environment(\.tabCoordinator)
    private var tabCoordinator

    @Injected(\.currentUserSession)
    private var userSession

    @Router
    private var router

    @State
    private var macWindowControlsWidth: CGFloat = 0

    let title: String?
    let isLoading: Bool
    let isOverlay: Bool
    let menuContent: MenuContent

    init(
        title: String? = nil,
        isLoading: Bool,
        isOverlay: Bool = false,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.title = title
        self.isOverlay = isOverlay
        self.isLoading = isLoading
        self.menuContent = menuContent()
    }

    private var backTitle: String {
        tabCoordinator?.tabs
            .first { $0.item.id == tabCoordinator?.selectedTabID }?
            .item.displayTitle ?? L10n.back
    }

    /// On phones the item hero bar drops its chrome and only shows the buttons
    private var isBareOverlay: Bool {
        isOverlay && horizontalSizeClass == .compact
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if router.isRootOfPath {
                    ThemedWordmark()
                } else {
                    ThemedBackButton(title: backTitle, pageTitle: title ?? parentRouteTitle, isOverlay: isBareOverlay) {
                        router.dismiss()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Without a centered tab switcher, let the title use the space the trailing buttons don't need
            .layoutPriority(horizontalSizeClass == .regular ? 0 : 1)

            if horizontalSizeClass == .regular, let tabCoordinator {
                ThemedTabSwitcher(tabCoordinator: tabCoordinator)
                    .layoutPriority(1)
            }

            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                }

                if router.isRootOfPath, let userSession {
                    Button {
                        router.route(to: .settings)
                    } label: {
                        ThemedAvatar {
                            UserProfileImage(
                                userID: userSession.user.id,
                                source: userSession.user.profileImageSource(
                                    client: userSession.server.client
                                ),
                                pipeline: .Swiftfin.local
                            )
                        }
                    }
                    .accessibilityLabel(L10n.settings)
                }

                Menu {
                    menuContent
                } label: {
                    ThemedMoreLabel()
                }
                .accessibilityLabel(L10n.options)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .modifier(ThemedTopBarFrame(windowControlsWidth: macWindowControlsWidth, isOverlay: isBareOverlay))
        .onMacWindowControlsWidthChange { width in
            macWindowControlsWidth = width
        }
    }
}

private struct ThemedTopBarFrame: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    let windowControlsWidth: CGFloat
    let isOverlay: Bool

    private func leadingInset(outerPadding: CGFloat) -> CGFloat {
        guard windowControlsWidth > 0 else { return 0 }

        return max(0, windowControlsWidth + 10 - outerPadding)
    }

    func body(content: Content) -> some View {
        switch theme {
        case .default:
            content
        case .skeuo:
            content
                .padding(.leading, leadingInset(outerPadding: 13))
                .padding(.horizontal, 5)
                .frame(height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Skeuo.stitch, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .allowsHitTesting(false)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background {
                    Skeuo.barLeather
                        .overlay(alignment: .top) {
                            Color.white.opacity(0.3)
                                .frame(height: 1)
                        }
                        .overlay(alignment: .bottom) {
                            Skeuo.leatherEdge
                                .frame(height: 1)
                        }
                        .background(alignment: .top) {
                            Skeuo.barLeather
                                .ignoresSafeArea(edges: .top)
                        }
                        .shadow(color: .black.opacity(0.55), radius: 3, y: 2)
                        .ignoresSafeArea(edges: .horizontal)
                }
        case .y2k where isOverlay:
            // Floating over the item hero, only the orb buttons are shown
            content
                .padding(.horizontal, 5)
                .frame(height: 56)
                .padding(.horizontal, 22)
                .padding(.leading, leadingInset(outerPadding: 22))
                .padding(.top, 8)
                .padding(.bottom, 4)
        case .y2k:
            content
                .padding(.horizontal, 5)
                .frame(height: 56)
                .background(Y2K.chrome, in: .capsule)
                .overlay(alignment: .top) {
                    Capsule()
                        .trim(from: 0.6, to: 0.9)
                        .stroke(.white, lineWidth: 1)
                        .padding(1)
                        .allowsHitTesting(false)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Y2K.chromeEdge)
                        .allowsHitTesting(false)
                }
                .shadow(color: Y2K.shadow.opacity(0.3), radius: 4, y: 3)
                .padding(.horizontal, 22)
                .padding(.leading, leadingInset(outerPadding: 22))
                .padding(.top, 8)
                .padding(.bottom, 4)
        case .gameUI2:
            content
                .frame(height: 52)
                .padding(.horizontal, 22)
                .padding(.leading, leadingInset(outerPadding: 22))
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }
}

private struct ThemedWordmark: View {

    @Environment(\.appTheme)
    private var theme

    var body: some View {
        switch theme {
        case .default:
            EmptyView()
        case .skeuo:
            Text(L10n.nextflix)
                .font(Skeuo.font(18, .bold))
                .kerning(0.36)
                .foregroundStyle(Skeuo.brassText)
                .shadow(color: .white.opacity(0.5), radius: 0, y: 1)
                .padding(.horizontal, 20)
                .frame(height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Skeuo.brass)
                        .overlay {
                            HStack {
                                Circle().fill(Skeuo.brassScrew).frame(width: 4, height: 4)
                                Spacer()
                                Circle().fill(Skeuo.brassScrew).frame(width: 4, height: 4)
                            }
                            .padding(.horizontal, 6)
                        }
                        .overlay(alignment: .top) {
                            Color.white.opacity(0.65)
                                .frame(height: 1)
                                .padding(.top, 1)
                        }
                        .clipShape(.rect(cornerRadius: 4))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Skeuo.brassEdge)
                }
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                .accessibilityAddTraits(.isHeader)
        case .y2k:
            HStack(spacing: 10) {
                SparkleShape()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: Y2K.pinkEdge.opacity(0.6), radius: 0.5, y: 1)
                    .y2kOrb(Y2K.pinkOrb, edge: Y2K.pinkEdge)
                    .accessibilityHidden(true)

                Y2KWordmarkText(size: 22)
            }
            .accessibilityAddTraits(.isHeader)
        case .gameUI2:
            Text(L10n.nextflix)
                .font(GameUI.title(30))
                .foregroundStyle(GameUI.yellow)
                .gameOutline(2, drop: 2)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

private struct Y2KWordmarkText: View {

    let size: CGFloat

    var body: some View {
        Text(L10n.nextflix)
            .font(Y2K.title(size))
            .kerning(size * 0.04)
            .foregroundStyle(Y2K.navy)
            .lineLimit(1)
    }
}

private struct ThemedBackButton: View {

    @Environment(\.appTheme)
    private var theme

    let title: String
    /// Title of the current page, shown by themes whose back button doesn't name the destination
    let pageTitle: String?
    let isOverlay: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch theme {
            case .default:
                EmptyView()
            case .skeuo:
                Text(title)
                    .font(Skeuo.font(15, .bold))
                    .foregroundStyle(Skeuo.cream)
                    .engraved(0.65)
                    .lineLimit(1)
                    .padding(.leading, 22)
                    .padding(.trailing, 16)
                    .frame(height: 40)
                    .background {
                        LeatherFill(shape: BackArrowShape())
                    }
            case .y2k:
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Y2K.navy)
                        .y2kOrb(Y2K.blueOrb, edge: Y2K.blueOrbEdge)

                    if isOverlay {
                        EmptyView()
                    } else if let pageTitle {
                        Text(pageTitle)
                            .font(Y2K.title(20))
                            .kerning(0.8)
                            .foregroundStyle(Y2K.navy)
                            .lineLimit(1)
                    } else {
                        Y2KWordmarkText(size: 20)
                    }
                }
                .contentShape(.rect)
            case .gameUI2:
                GameChunkyIcon(systemName: "chevron.left", fill: GameUI.pink)
            }
        }
        .accessibilityLabel(L10n.back)
    }
}

private struct ThemedAvatar<Content: View>: View {

    @Environment(\.appTheme)
    private var theme

    @ViewBuilder
    let content: Content

    var body: some View {
        switch theme {
        case .default:
            content
        case .skeuo:
            content
                .frame(width: 44, height: 44)
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .strokeBorder(Skeuo.cream, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
        case .y2k:
            content
                .frame(width: 44, height: 44)
                .overlay {
                    Y2K.glass(0.6, 0.1)
                        .allowsHitTesting(false)
                }
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                }
                .padding(1)
                .background(Y2K.chromeEdge, in: .circle)
                .shadow(color: Y2K.shadow.opacity(0.35), radius: 2.5, y: 2)
        case .gameUI2:
            content
                .frame(width: 40, height: 40)
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .strokeBorder(GameUI.outline, lineWidth: 3)
                }
                .background {
                    Circle()
                        .fill(GameUI.outline)
                        .offset(y: 4)
                }
                .padding(.bottom, 4)
        }
    }
}

private struct ThemedMoreLabel: View {

    @Environment(\.appTheme)
    private var theme

    var body: some View {
        switch theme {
        case .default:
            Image(systemName: "ellipsis")
        case .skeuo:
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Skeuo.cream)
                .frame(width: 48, height: 40)
                .background {
                    LeatherFill(shape: .rect(cornerRadius: 6))
                }
                .contentShape(.rect)
        case .y2k:
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Y2K.navy)
                .y2kOrb(Y2K.blueOrb, edge: Y2K.blueOrbEdge)
                .contentShape(.circle)
        case .gameUI2:
            GameChunkyIcon(systemName: "ellipsis", fill: GameUI.pink)
        }
    }
}

struct ThemedTabSwitcher: View {

    @Environment(\.appTheme)
    private var theme

    @ObservedObject
    var tabCoordinator: TabCoordinator

    private var tabSpacing: CGFloat {
        switch theme {
        case .default, .skeuo:
            -1
        case .y2k:
            6
        case .gameUI2:
            8
        }
    }

    @ViewBuilder
    private var tabs: some View {
        let tabs = tabCoordinator.tabs

        HStack(spacing: tabSpacing) {
            ForEach(Array(tabs.enumerated()), id: \.element.item.id) { index, tab in
                Button {
                    tabCoordinator.select(tabID: tab.item.id)
                } label: {
                    ThemedTabLabel(
                        title: tab.item.displayTitle,
                        systemImage: tab.item.systemImage,
                        isSelected: tab.item.id == tabCoordinator.selectedTabID,
                        isFirst: index == 0,
                        isLast: index == tabs.count - 1
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab.item.id == tabCoordinator.selectedTabID ? .isSelected : [])
            }
        }
        .modifier(ThemedTabWell())
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabs

            ScrollView(.horizontal) {
                tabs
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ThemedTabLabel: View {

    @Environment(\.appTheme)
    private var theme

    let title: String
    let systemImage: String
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool

    private func label(iconSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            ThemedTabIcon(systemImage: systemImage, size: iconSize)
                .accessibilityHidden(true)

            Text(title)
        }
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? 8 : 0,
            bottomLeadingRadius: isFirst ? 8 : 0,
            bottomTrailingRadius: isLast ? 8 : 0,
            topTrailingRadius: isLast ? 8 : 0
        )
    }

    var body: some View {
        switch theme {
        case .default:
            Text(title)
        case .skeuo:
            label(iconSize: 18)
                .font(Skeuo.font(16, .bold))
                .foregroundStyle(isSelected ? Skeuo.amberText : Skeuo.cream)
                .shadow(
                    color: isSelected ? .white.opacity(0.7) : .black.opacity(0.65),
                    radius: 0,
                    y: isSelected ? 1 : -1
                )
                .lineLimit(1)
                .padding(.horizontal, 22)
                .frame(height: 40)
                .background {
                    if isSelected {
                        shape
                            .fill(Skeuo.amber)
                            .overlay(alignment: .top) {
                                Color.white.opacity(0.8)
                                    .frame(height: 1)
                            }
                            .clipShape(shape)
                            .overlay {
                                shape.strokeBorder(Skeuo.leatherEdge)
                            }
                    } else {
                        LeatherFill(shape: shape)
                    }
                }
                .contentShape(shape)
        case .y2k:
            label(iconSize: 18)
                .font(Y2K.font(16, .semibold))
                .foregroundStyle(isSelected ? Y2K.lime : Y2K.navy)
                .shadow(color: .white.opacity(isSelected ? 0 : 0.6), radius: 0, y: 1)
                .lineLimit(1)
                .padding(.horizontal, 22)
                .frame(height: 40)
                .y2kGel(
                    isSelected ? Y2K.navy : Y2K.silver,
                    edge: isSelected ? Y2K.navy : Y2K.silverEdge,
                    in: .capsule,
                    isDark: isSelected
                )
                .padding(isSelected ? 2 : 0)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Y2K.lime)
                    }
                }
                .padding(isSelected ? -2 : 0)
                .shadow(
                    color: isSelected ? Y2K.navy.opacity(0.5) : Y2K.shadow.opacity(0.3),
                    radius: isSelected ? 3 : 2.5,
                    y: 2
                )
                .contentShape(.capsule)
        case .gameUI2:
            let shape = RoundedRectangle(cornerRadius: 12)

            label(iconSize: 20)
                .font(GameUI.title(18))
                .foregroundStyle(isSelected ? GameUI.outline : .white)
                .modifier(GameTabTextOutline(isEnabled: !isSelected))
                .lineLimit(1)
                .padding(.horizontal, 20)
                .frame(height: 42)
                .gameChunky(isSelected ? GameUI.yellow : GameUI.lilac, in: shape, isPressed: isSelected)
                .padding(isSelected ? 3 : 0)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.white)
                    }
                }
                .padding(isSelected ? -3 : 0)
                .offset(y: isSelected ? 4 : 0)
                .padding(.bottom, 4)
                .contentShape(shape)
        }
    }
}

struct GameTabTextOutline: ViewModifier {

    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.gameOutline(1, drop: 1)
        } else {
            content
        }
    }
}

struct GameChunkyIcon: View {

    let systemName: String
    let fill: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(GameUI.outline)
            .frame(width: 48, height: 40)
            .gameChunky(fill, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 4)
            .contentShape(.rect)
    }
}

private struct ThemedTabWell: ViewModifier {

    @Environment(\.appTheme)
    private var theme

    func body(content: Content) -> some View {
        switch theme {
        case .y2k:
            content
                .padding(4)
                .background(.white.opacity(0.45), in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(Y2K.navy.opacity(0.3), lineWidth: 3)
                        .blur(radius: 1.5)
                        .offset(y: 1)
                        .clipShape(.capsule)
                        .allowsHitTesting(false)
                }
        default:
            content
        }
    }
}

struct LeatherFill<S: InsettableShape>: View {

    let shape: S

    var body: some View {
        shape
            .fill(Skeuo.leather)
            .overlay(alignment: .top) {
                Color.white.opacity(0.22)
                    .frame(height: 1)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Skeuo.leatherEdge)
            }
    }
}

struct BackArrowShape: InsettableShape {

    var arrowWidth: CGFloat = 15
    var cornerRadius: CGFloat = 6
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let radius = max(0, cornerRadius - inset)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + arrowWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.minX + arrowWidth, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()

        return path
    }

    func inset(by amount: CGFloat) -> BackArrowShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}
