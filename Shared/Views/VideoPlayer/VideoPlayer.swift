//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import FactoryKit
import SwiftUI
import Transmission

struct VideoPlayer: View {

    @Environment(\.presentationCoordinator)
    private var presentationCoordinator

    @InjectedObject(\.mediaPlayerManager)
    private var manager: MediaPlayerManager

    @LazyState
    private var proxy: any VideoMediaPlayerLayoutConfigurable

    @Router
    private var router

    @State
    private var isBeingDismissedByTransition = false
    #if os(iOS)
    @State
    private var isDetachingForPictureInPicture = false
    @State
    private var isRestoringFromPictureInPicture = false
    @State
    private var isStartingPictureInPictureForSwipe = false
    #endif
    @State
    private var safeAreaInsets: EdgeInsets = .init()

    #if os(iOS)
    @State
    private var scrubbingStartTime: CFTimeInterval? = nil
    #endif

    @State
    private var viewState: ViewState = .init()

    init() {
        #if os(iOS)
        // Continue with the player that was playing in Picture in Picture
        if let proxy = DetachedPictureInPicture.takeRestoringProxy() {
            self._proxy = .init(wrappedValue: proxy)
            self._isRestoringFromPictureInPicture = State(initialValue: true)
            return
        }
        #endif

        switch Defaults[.VideoPlayer.videoPlayerType] {
        case .avPlayer:
            self._proxy = .init(wrappedValue: AVMediaPlayerProxy())
        case .mpv:
            self._proxy = .init(wrappedValue: MPVMediaPlayerProxy())
        case .vlc:
            self._proxy = .init(wrappedValue: VLCMediaPlayerProxy())
        }
    }

    #if os(iOS)
    private var pictureInPictureActivePublisher: AnyPublisher<Bool, Never> {
        (proxy as? MediaPlayerPictureInPictureCapable)?
            .isPiPActive
            .$value
            // A restored player is shown while Picture in Picture is still closing
            .dropFirst(isRestoringFromPictureInPicture ? 1 : 0)
            .removeDuplicates()
            .eraseToAnyPublisher()
            ?? Combine.Empty().eraseToAnyPublisher()
    }
    #endif

    #if os(iOS)
    /// Swiping the player away while playing continues in Picture in Picture.
    /// Starts as the swipe begins, as Picture in Picture can only start while
    /// the video is still on screen.
    private func startPictureInPictureForSwipe() {
        guard !ProcessInfo.processInfo.isiOSAppOnMac,
              !isDetachingForPictureInPicture,
              !viewState.isClosing,
              manager.state == .playback,
              manager.playbackRequestStatus == .playing,
              let capable = proxy as? MediaPlayerPictureInPictureCapable,
              capable.isPiPAvailable.value
        else { return }

        isStartingPictureInPictureForSwipe = true
        isDetachingForPictureInPicture = true
        DetachedPictureInPicture.detach(proxy: proxy, manager: manager)
        capable.startPiP()

        // End playback if Picture in Picture could not start
        Task { [manager, proxy] in
            try? await Task.sleep(for: .seconds(2))

            guard DetachedPictureInPicture.isDetached(proxy as AnyObject),
                  !capable.isPiPActive.value
            else { return }

            await manager.stop()
        }
    }

    /// The swipe was cancelled and the player stayed on screen
    private func cancelPictureInPictureForSwipe() {
        guard isStartingPictureInPictureForSwipe, presentationCoordinator.isPresented else { return }

        isStartingPictureInPictureForSwipe = false
        isDetachingForPictureInPicture = false

        // Clear first so stopping Picture in Picture doesn't end playback
        DetachedPictureInPicture.clear()
        (proxy as? MediaPlayerPictureInPictureCapable)?.stopPiP()
    }
    #endif

    var body: some View {
        Container(
            viewState: viewState,
            manager: manager,
            videoSize: proxy.videoSize
        ) { videoLayout in
            proxy.videoPlayerBody(layout: videoLayout)
                .eraseToAnyView()
        } playbackControls: {
            PlaybackControls()
        }
        .onAppear {
            manager.proxy = proxy

            #if os(iOS)
            if isRestoringFromPictureInPicture {
                DetachedPictureInPicture.didRestore()
                return
            }
            #endif

            manager.start()
        }
        #if os(iOS)
        .background {
            ViewControllerAppearanceObserver(
                onWillDisappear: startPictureInPictureForSwipe,
                onDidAppear: cancelPictureInPictureForSwipe
            )
        }
        .onReceive(pictureInPictureActivePublisher) { isActive in
            // Close the full-screen player so the app can be navigated
            guard isActive, !isDetachingForPictureInPicture else { return }

            isDetachingForPictureInPicture = true
            DetachedPictureInPicture.detach(proxy: proxy, manager: manager)
            router.dismiss()
        }
        #endif
        .prefersStatusBarHidden(!viewState.isPresentingControls)
        #if os(iOS)
        .onChange(of: viewState.isScrubbing) {
            if viewState.isScrubbing {
                scrubbingStartTime = CACurrentMediaTime()
                return
            }

            guard let scrubbingStartTime else { return }

            self.scrubbingStartTime = nil
            let scrubbingDelta = CACurrentMediaTime() - scrubbingStartTime
            let secondsDelta = abs(manager.seconds - viewState.scrubbedSeconds.value)

            guard secondsDelta >= .seconds(1), scrubbingDelta >= 0.1 else { return }

            let scrubbedSeconds = viewState.scrubbedSeconds.value
            manager.seconds = scrubbedSeconds
            proxy.setSeconds(scrubbedSeconds)
        }
        #endif
        .preference(
            key: PresentationControllerShouldDismissPreferenceKey.self,
            value: viewState.presentationControllerShouldDismiss
        )
        .onChange(of: presentationCoordinator.isPresented) {
            guard !presentationCoordinator.isPresented else { return }

            isBeingDismissedByTransition = true

            #if os(iOS)
            // Playback continues in Picture in Picture
            guard !isDetachingForPictureInPicture else { return }
            #endif

            manager.stop()
        }
        .onReceive(manager.$playbackItem) { newItem in
            // TODO: move to container view
            viewState.scrubbedSeconds.value = newItem?.baseItem.startSeconds ?? .zero
        }
        .onReceive(manager.$state) { newState in
            if newState == .stopped, !isBeingDismissedByTransition {
                #if os(iOS)
                guard !isDetachingForPictureInPicture else { return }
                #endif

                router.dismiss()
            }
        }

        .alert(
            L10n.error,
            isPresented: .constant(manager.error != nil)
        ) {
            Button(L10n.close, role: .cancel) {
                FactoryKit.Container.shared.mediaPlayerManager.reset()
                router.dismiss()
            }
        } message: {
            Text(L10n.unableToLoadThisItem)
        }
        .environment(\.safeAreaInsets, safeAreaInsets)
        .colorScheme(.dark) // use over `preferredColorScheme(.dark)` to not have destination change
        .supportedOrientations(.allButUpsideDown)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .onSceneDidEnterBackground {
            // On Mac the scene backgrounds whenever the app loses focus, even
            // while the player is still visible, such as full screen on another display
            guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }

            let isPictureInPictureActive = (proxy as? MediaPlayerPictureInPictureCapable)?.isPiPActive.value == true
            if Defaults[.VideoPlayer.Transition.pauseOnBackground], !isPictureInPictureActive {
                manager.setPlaybackRequestStatus(status: .paused)
            }
        }
        .onSizeChanged { _, safeArea in
            self.safeAreaInsets = safeArea.max(EdgeInsets.edgePadding)
        }
    }
}

#if os(iOS)
/// Reports appearance changes of the hosting view controller, such as when
/// an interactive dismissal begins
private struct ViewControllerAppearanceObserver: UIViewControllerRepresentable {

    let onWillDisappear: () -> Void
    let onDidAppear: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onWillDisappear = onWillDisappear
        controller.onDidAppear = onDidAppear
    }

    final class Controller: UIViewController {

        var onWillDisappear: (() -> Void)?
        var onDidAppear: (() -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            onWillDisappear?()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onDidAppear?()
        }
    }
}
#endif
