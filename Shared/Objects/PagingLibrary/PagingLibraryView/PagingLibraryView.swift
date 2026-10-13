//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CollectionVGrid
import Defaults
import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct PagingLibraryView<Library: PagingLibrary>: View where Library.Element: LibraryElement {

    private enum Focus: String {

        case firstElement = "pagingLibrary-firstElement"
    }

    typealias Element = Library.Element

    @Default(.Customization.Library.rememberLayout)
    private var rememberIndividualLibraryStyle
    @Default(.Customization.Library.style)
    private var defaultLibraryStyle

    @Environment(\.tabSafeAreaInsets)
    private var tabSafeAreaInsets

    @Namespace
    private var namespace

    @Router
    private var router

    @State
    private var isSafeAreaBarApplied: Bool = false

    @StateObject
    private var focusCoordinator = FocusCoordinator(waitingFor: Focus.firstElement.rawValue)
    @StateObject
    private var gridProxy = CollectionVGridProxy()
    #if os(iOS)
    @StateObject
    private var headerHost = ScrollViewHeaderHost()
    #endif
    @StateObject
    private var viewModel: PagingLibraryViewModel<Library>

    @StoredValue
    private var parentLibraryStyle: LibraryStyle

    @TabItemSelected
    private var tabItemSelected

    private let displayTitle: String?

    private var libraryStyleOptions: LibraryStyleOptions {
        viewModel.libraryStyleOptions
    }

    private var libraryStyle: LibraryStyle {
        libraryStyleOptions.normalized(storedLibraryStyle)
    }

    private var isLibraryStyleSectionVisible: Bool {
        libraryStyleOptions.hasVisibleControls ||
            (
                libraryStyle.displayType == .list &&
                    UIDevice.isPad &&
                    libraryStyleOptions.displayTypes.contains(.list)
            )
    }

    private var storedLibraryStyle: LibraryStyle {
        rememberIndividualLibraryStyle ? parentLibraryStyle : defaultLibraryStyle
    }

    private var storedLibraryStyleBinding: Binding<LibraryStyle> {
        rememberIndividualLibraryStyle ? $parentLibraryStyle : $defaultLibraryStyle
    }

    init(library: Library, displayTitle: String? = nil) {
        self.displayTitle = displayTitle
        self._parentLibraryStyle = StoredValue(.User.libraryStyle(id: library.parent.pagingLibraryID))
        self._viewModel = StateObject(wrappedValue: PagingLibraryViewModel(library: library))
    }

    private func contentInsets(for frame: FrameAndSafeAreaInsets) -> EdgeInsets {
        #if os(tvOS)
        // The collection disables automatic adjustment, so include both the local
        // safe area (including filter bars) and the tab's measured top inset.
        var insets = frame.safeAreaInsets
        insets.top = max(insets.top, tabSafeAreaInsets.top)
        return insets + EdgeInsets.itemSpacing
        #else
        var insets: EdgeInsets = if isSafeAreaBarApplied {
            frame.safeAreaInsets + EdgeInsets.itemSpacing
        } else {
            EdgeInsets(
                top: 0,
                leading: frame.safeAreaInsets.leading,
                bottom: 0,
                trailing: frame.safeAreaInsets.trailing
            ) + EdgeInsets.itemSpacing
        }

        // TODO: shouldn't need explicitly for list, find fix
        if libraryStyle.displayType == .list {
            insets.leading = frame.safeAreaInsets.leading
            insets.trailing = frame.safeAreaInsets.trailing
        }

        // Leave room for a header hosted above the items, such as filters
        insets.top += headerHost.height

        return insets
        #endif
    }

    @ViewBuilder
    private func elementsView(header: AnyView?) -> some View {
        AlternateLayoutView {
            Color.clear
        } content: { frame in

            CollectionVGrid(
                uniqueElements: viewModel.displayedElements,
                layout: Element.layout(
                    for: libraryStyle,
                    options: libraryStyleOptions,
                    insets: contentInsets(for: frame)
                )
            ) { element in
                element.makeBody(libraryStyle: libraryStyle)
                    #if os(tvOS)
                        .if(element.id == viewModel.displayedElements.first?.id) { view in
                            view
                                .coordinatedFocus(Focus.firstElement.rawValue)
                                .environmentObject(focusCoordinator)
                        }
                        .introspect(.viewController, on: .tvOS(.v26...)) { controller in
                            // Do not have hosting controller apply safe regions
                            // TODO: do in CollectionVGrid instead
                            if let hostingController = controller as? UIHostingController<AnyView> {
                                hostingController.safeAreaRegions.remove(.container)
                            }
                        }
                    #endif
            }
            .onReachedBottomEdge(offset: .offset(300)) {
                if viewModel.isSearchActive {
                    viewModel.getNextSearchPage()
                } else {
                    viewModel.getNextPage()
                }
            }
            .proxy(gridProxy)
            .onRefresh {
                await viewModel.background.refresh()
            }
            #if os(tvOS)
            .introspect(.scrollView, on: .tvOS(.v26...)) { collectionView in
                // TODO: CollectionVGrid option instead
                collectionView.contentInsetAdjustmentBehavior = .never
            }
            #else
            .introspect(.scrollView, on: .iOS(.v18...)) { collectionView in
                // Host the header inside the grid so it scrolls natively with the items
                if let header {
                    headerHost.attach(header, to: collectionView)
                } else {
                    headerHost.detach()
                }
            }
            #endif
            .ignoresSafeArea()
        }
        .scrollIndicators(.hidden)
        .withViewContext(.isListRowSeparatorVisible)
        .withViewContext(.isThumb)
        .onReceive(tabItemSelected) { event in
            if event.isRepeat, event.isRoot {
                gridProxy.scrollToTop(animated: true)
            }
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if isLibraryStyleSectionVisible {
            LibraryStyleSection(
                libraryStyle: storedLibraryStyleBinding,
                options: libraryStyleOptions
            )
        }

        viewModel.library.makeMenuContent(environment: $viewModel.environment)

        Button(L10n.random, systemImage: "dice.fill") {
            viewModel.getRandomItem()
        }
    }

    /// Whether the items grid is showing, which hosts the header itself
    private var isShowingElements: Bool {
        viewModel.state == .content &&
            !(viewModel.isSearchActive && viewModel.background.is(.searching)) &&
            viewModel.displayedElements.isNotEmpty
    }

    @ViewBuilder
    private func content(header: AnyView?) -> some View {
        ZStack {
            switch viewModel.state {
            case .initial, .refreshing:
                ProgressView()
                    #if os(tvOS)
                        .coordinatedFocus(.placeholder)
                    #endif

            case .content:
                if viewModel.isSearchActive, viewModel.background.is(.searching) {
                    ProgressView()
                } else if viewModel.displayedElements.isEmpty {
                    ContentUnavailableView(
                        viewModel.isSearchActive ? L10n.noResults.localizedCapitalized : L10n.noItems.localizedCapitalized,
                        systemImage: viewModel.isSearchActive ? "magnifyingglass" : "rectangle.on.rectangle.slash"
                    )
                    .focusable()
                    #if os(tvOS)
                    .coordinatedFocus(.fallback)
                    #endif
                } else {
                    elementsView(header: header)
                }

            case .error:
                viewModel.error.map(ErrorView.init)
                    #if os(tvOS)
                        .coordinatedFocus(.fallback)
                    #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            // Without items to scroll with, keep the header visible, such as
            // so filters that return no items can be changed
            if !isShowingElements, let header {
                header
            }
        }
    }
}

/// Reads the library header from the environment, which is set by a library's body
/// below `PagingLibraryView`, and carries the environment along for hosting outside SwiftUI
private struct LibraryHeaderReader<Content: View>: View {

    @Environment(\.libraryHeader)
    private var header
    @Environment(\.self)
    private var environment

    let content: (AnyView?) -> Content

    var body: some View {
        content(header.map { AnyView($0.environment(\.self, environment)) })
    }
}

extension PagingLibraryView {

    var body: some View {
        viewModel.library.makeLibraryBody(viewModel: viewModel) {
            LibraryHeaderReader { header in
                content(header: header)
            }
        }
        .animation(.linear(duration: 0.2), value: viewModel.background.is(.gettingNextPage))
        .animation(.linear(duration: 0.2), value: viewModel.background.is(.searching))
        .animation(.linear(duration: 0.2), value: viewModel.elements)
        .animation(.linear(duration: 0.2), value: viewModel.searchElements)
        .navigationTitle(displayTitle ?? viewModel.library.parent.displayTitle)
        .errorMessage($viewModel.error)
        .onPreferenceChange(IsSafeAreaBarApplied.self) { newValue in
            isSafeAreaBarApplied = newValue
        }
        #if os(iOS)
        .toolbarTitleDisplayMode(router.isRootOfPath ? .inlineLarge : .inline)
        #endif
        .onChange(of: viewModel.environment) {
            viewModel.refreshForEnvironmentChange()
        }
        .onChange(of: libraryStyle) { oldStyle, newStyle in
            if Element.layout(for: oldStyle, options: libraryStyleOptions, insets: .zero) ==
                Element.layout(for: newStyle, options: libraryStyleOptions, insets: .zero)
            {
                gridProxy.redraw()
            }
        }
        .onReceive(viewModel.events) { event in
            switch event {
            case let .gotRandomItem(element):
                element.libraryDidSelectElement(router: router, in: namespace)
            }
        }
        .onFirstAppear {
            viewModel.refresh()
        }
        #if os(tvOS)
        .environmentObject(focusCoordinator)
        #else
        .navigationBarMenuButton(
            isLoading: viewModel.background.is(.gettingNextPage) || viewModel.background.is(.gettingNextSearchPage)
        ) {
            menuContent
        }
        #endif
    }
}
