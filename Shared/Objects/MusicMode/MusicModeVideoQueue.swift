//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import AVFoundation
import FactoryKit
import Foundation
import JellyfinAPI
import Logging

/// Plays the videos of a Jellyfin source on a muted, looping `AVPlayer`
@MainActor
@Observable
final class MusicModeVideoQueue {

    let player = AVPlayer()

    private(set) var items: [BaseItemDto] = []
    private(set) var index = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Called just before a video starts playing, which can briefly stop Apple Music
    @ObservationIgnored
    var onWillPlay: (() -> Void)?

    @ObservationIgnored
    private var playTask: Task<Void, Never>?
    @ObservationIgnored
    private var endObserver: NSObjectProtocol?
    @ObservationIgnored
    private var failureObserver: NSObjectProtocol?
    @ObservationIgnored
    private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored
    private var timeControlObservation: NSKeyValueObservation?
    /// Whether the video should be playing, so outside pauses can be undone
    @ObservationIgnored
    private var wantsPlayback = false
    /// Items that failed in a row, so a source of unplayable videos doesn't loop forever
    @ObservationIgnored
    private var consecutiveFailures = 0
    @ObservationIgnored
    private let logger = Logger.swiftfin()

    init() {
        player.isMuted = true
        player.allowsExternalPlayback = false
        // The Music view keeps the screen awake itself, as it also covers the music
        player.preventsDisplaySleepDuringVideoPlayback = false

        // Apple Music starting playback can still pause the video, so it's resumed
        timeControlObservation = player.observe(\.timeControlStatus) { [weak self] player, _ in
            guard player.timeControlStatus == .paused else { return }

            Task { @MainActor in
                guard let self, self.wantsPlayback, player.currentItem?.status == .readyToPlay else { return }
                self.onWillPlay?()
                self.player.play()
            }
        }
    }

    /// The video is muted, so its audio session mixes with Apple Music instead of interrupting it
    static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        // Changing the category while Apple Music is playing can cut it off
        guard session.category != .playback || !session.categoryOptions.contains(.mixWithOthers) else { return }

        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            Logger.swiftfin().error("Music mode couldn't configure the audio session: \(error.localizedDescription)")
        }
    }

    /// Waits for the first video to start, or for the timeout, whichever is first
    func waitUntilPlaying(timeout: Duration = .seconds(15)) async {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline, !Task.isCancelled {
            if player.timeControlStatus == .playing || errorMessage != nil || (!isLoading && items.isEmpty) {
                return
            }

            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    var current: BaseItemDto? {
        items[safe: index]
    }

    /// Wraps to the first video, as the queue loops
    var next: BaseItemDto? {
        guard !items.isEmpty else { return nil }
        return items[(index + 1) % items.count]
    }

    // MARK: Loading

    func load(source: MusicModeVideoSource, shuffle: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var fetched = try await Self.fetchItems(source: source)

            if shuffle {
                fetched.shuffle()
            }

            guard fetched.isNotEmpty else {
                items = []
                errorMessage = "\(source.name) doesn't contain any videos."
                return
            }

            items = fetched
            index = 0
            consecutiveFailures = 0
            playCurrent()
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    private static func fetchItems(source: MusicModeVideoSource) async throws -> [BaseItemDto] {
        guard let userSession = Container.shared.currentUserSession() else { return [] }

        var parameters = Paths.GetItemsParameters()
        parameters.userID = userSession.user.id
        parameters.parentID = source.id
        parameters.isRecursive = true
        parameters.includeItemTypes = [.movie, .episode, .video, .musicVideo]
        parameters.isMissing = false
        parameters.limit = 1000

        // Playlists keep their own order
        if source.kind != .playlist {
            parameters.sortBy = [.sortName]
        }

        let response = try await userSession.client.send(Paths.getItems(parameters: parameters))

        return response.value.items ?? []
    }

    // MARK: Playback

    func skipToNext() {
        guard items.isNotEmpty else { return }
        index = (index + 1) % items.count
        playCurrent()
    }

    func skipToPrevious() {
        guard items.isNotEmpty else { return }
        index = (index - 1 + items.count) % items.count
        playCurrent()
    }

    func pause() {
        wantsPlayback = false
        player.pause()
    }

    func resume() {
        guard player.currentItem != nil else { return }

        Self.configureAudioSession()
        wantsPlayback = true
        player.play()
    }

    func stop() {
        playTask?.cancel()
        removeItemObservers()
        wantsPlayback = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        items = []
        index = 0
        errorMessage = nil
    }

    private func playCurrent() {
        playTask?.cancel()

        guard let item = current else { return }

        playTask = Task { [weak self] in
            do {
                // The native player profile makes the server send a stream AVPlayer can play
                let playbackItem = try await MediaPlayerItem.build(for: item, videoPlayerType: .avPlayer)
                guard !Task.isCancelled, let self else { return }

                let playerItem = AVPlayerItem(url: playbackItem.url)
                self.observe(playerItem)
                Self.configureAudioSession()
                self.wantsPlayback = true
                self.onWillPlay?()
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
            } catch {
                guard !Task.isCancelled, let self else { return }

                self.logger.error("Music mode couldn't play \(item.displayTitle): \(error.localizedDescription)")
                self.handleFailure()
            }
        }
    }

    private func observe(_ playerItem: AVPlayerItem) {
        removeItemObservers()

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.consecutiveFailures = 0
                self?.skipToNext()
            }
        }

        // Streams the server can't open fail here rather than at the end
        statusObservation = playerItem.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }

            Task { @MainActor in
                self?.handleFailure()
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleFailure()
            }
        }
    }

    private func removeItemObservers() {
        statusObservation = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }

        endObserver = nil
        failureObserver = nil
    }

    private func handleFailure() {
        consecutiveFailures += 1

        guard consecutiveFailures < items.count else {
            errorMessage = "None of the videos could be played."
            return
        }

        skipToNext()
    }
}
