//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(iOS)
import FactoryKit
import Foundation
import Observation

/// During Picture in Picture the full-screen player is closed to allow navigating
/// the app. The player is kept alive here so it can be restored from the Picture
/// in Picture window or the Now Playing bar.
@MainActor
enum DetachedPictureInPicture {

    /// Observable so views, such as the Now Playing bar, update with the detached player
    @Observable
    @MainActor
    final class Storage {
        var proxy: (any VideoMediaPlayerLayoutConfigurable)?
        var manager: MediaPlayerManager?
        var isRestoring = false
        var wasPlayingBeforeRestore = false
        var stopsPictureInPictureOnRestore = false
    }

    private static let storage = Storage()

    static var proxy: (any VideoMediaPlayerLayoutConfigurable)? {
        storage.proxy
    }

    static var manager: MediaPlayerManager? {
        storage.manager
    }

    /// Set when the user asks to return to the app from Picture in Picture
    static var isRestoring: Bool {
        storage.isRestoring
    }

    static func detach(proxy: any VideoMediaPlayerLayoutConfigurable, manager: MediaPlayerManager) {
        storage.proxy = proxy
        storage.manager = manager
        storage.isRestoring = false
    }

    static func isDetached(_ proxy: AnyObject) -> Bool {
        (self.proxy as AnyObject?) === proxy
    }

    /// Present the full-screen player again with the detached player
    static func restore() {
        guard let manager else { return }

        storage.isRestoring = true
        storage.wasPlayingBeforeRestore = manager.playbackRequestStatus == .playing

        Container.shared.userSessionManager()
            .routePublisher
            .send(.videoPlayer(manager: manager))
    }

    /// Take the detached player for a newly presented full-screen player
    static func takeRestoringProxy() -> (any VideoMediaPlayerLayoutConfigurable)? {
        guard isRestoring, let proxy else { return nil }
        return proxy
    }

    /// Return to the full-screen player from within the app
    static func returnToPlayer() {
        // Picture in Picture is stopped once the player is on screen to show the video
        storage.stopsPictureInPictureOnRestore = true
        restore()
    }

    /// Finish restoring once the full-screen player is on screen
    static func didRestore() {
        let proxy = proxy
        let manager = manager
        let wasPlaying = storage.wasPlayingBeforeRestore

        if storage.stopsPictureInPictureOnRestore {
            (proxy as? MediaPlayerPictureInPictureCapable)?.stopPiP()
        }

        clear()

        // Ending Picture in Picture can pause the video, so continue if it was playing
        guard wasPlaying, let proxy, let manager else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(500))

            guard manager.state == .playback else { return }

            proxy.play()
            await manager.setPlaybackRequestStatus(status: .playing)
        }
    }

    static func clear() {
        storage.proxy = nil
        storage.manager = nil
        storage.isRestoring = false
        storage.wasPlayingBeforeRestore = false
        storage.stopsPictureInPictureOnRestore = false
    }
}
#endif
