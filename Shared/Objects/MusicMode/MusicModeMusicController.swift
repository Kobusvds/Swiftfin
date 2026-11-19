//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Algorithms
import AVFoundation
import Foundation
import Logging
import MusicKit

/// Plays an Apple Music library playlist on a looping `ApplicationMusicPlayer`
@MainActor
@Observable
final class MusicModeMusicController {

    enum MusicModeError: LocalizedError {
        case notAuthorized
        case playlistUnavailable(String)
        case emptyPlaylist(String)
        case notInCatalog(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                "Allow access to Apple Music in Settings to play music here."
            case let .playlistUnavailable(name):
                "\(name) is no longer in your Apple Music library."
            case let .emptyPlaylist(name):
                "\(name) doesn't contain any songs."
            case let .notInCatalog(name):
                "None of the songs in \(name) could be found on Apple Music."
            }
        }
    }

    var player: ApplicationMusicPlayer {
        .shared
    }

    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The current and next songs, as "Title — Artist"
    private(set) var currentSong: String?
    private(set) var nextSong: String?
    private(set) var isPlaying = false

    /// Whether the music should be playing.
    ///
    /// Changes on its own when the music is paused or played from outside the app's controls,
    /// such as by the Apple TV remote's Play/Pause button, so the video can follow it.
    private(set) var wantsPlayback = false
    @ObservationIgnored
    private var monitorTask: Task<Void, Never>?
    /// When the music was last resumed after an outside pause, so it doesn't fight another player
    @ObservationIgnored
    private var lastAutoResume: ContinuousClock.Instant?
    /// When the app last played or paused the music, as the player takes a moment to follow
    @ObservationIgnored
    private var lastCommand: ContinuousClock.Instant?
    /// Until when an outside pause is from the video starting, and is undone
    @ObservationIgnored
    private var expectsInterruptionUntil: ContinuousClock.Instant?
    /// The last logged player state, so the log only shows changes
    @ObservationIgnored
    private var lastLoggedState: String?
    @ObservationIgnored
    private let logger = Logger.swiftfin()

    // MARK: Authorization

    /// Asks for Apple Music access the first time, then returns the saved answer
    static func requestAuthorization() async -> Bool {
        if MusicAuthorization.currentStatus == .authorized {
            return true
        }

        return await MusicAuthorization.request() == .authorized
    }

    /// The playlists in the user's Apple Music library, by name
    static func libraryPlaylists() async throws -> [Playlist] {
        guard await requestAuthorization() else { throw MusicModeError.notAuthorized }

        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.name, ascending: true)

        let response = try await request.response()

        return Array(response.items)
    }

    // MARK: Playback

    func play(_ selection: MusicModePlaylist, shuffle: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Apple Music's servers sometimes fail a first request, so starting is tried twice
        for attempt in 1 ... 2 {
            do {
                try await start(selection, shuffle: shuffle)
                errorMessage = nil
                return
            } catch {
                logger.error("Music mode: starting \(selection.name) failed (attempt \(attempt)): \(String(describing: error))")
                errorMessage = "Apple Music: \(error.localizedDescription)"

                guard attempt < 2, !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func start(_ selection: MusicModePlaylist, shuffle: Bool) async throws {
        guard await Self.requestAuthorization() else { throw MusicModeError.notAuthorized }

        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(selection.id))

        guard let playlist = try await request.response().items.first else {
            throw MusicModeError.playlistUnavailable(selection.name)
        }

        var tracks = try await Array(playlist.with([.tracks]).tracks ?? [])

        guard tracks.isNotEmpty else { throw MusicModeError.emptyPlaylist(selection.name) }

        // Shuffled here so the queue order, and so the next song, is known
        if shuffle {
            tracks.shuffle()
        }

        #if os(tvOS)
        // tvOS can't play library songs through the app's player, only their Apple Music catalog versions
        let songs = await catalogSongs(for: tracks)

        guard songs.isNotEmpty else { throw MusicModeError.notInCatalog(selection.name) }

        logger.info("Music mode: queueing \(songs.count) of \(tracks.count) songs from \(selection.name)")

        player.queue = ApplicationMusicPlayer.Queue(for: songs)
        #else
        logger.info("Music mode: queueing \(tracks.count) songs from \(selection.name)")

        player.queue = ApplicationMusicPlayer.Queue(for: tracks)
        #endif
        player.state.shuffleMode = .off
        player.state.repeatMode = .all

        wantsPlayback = true
        lastCommand = .now
        startMonitoring()

        logState("before play")
        try await player.play()
        logState("after play")
        refresh()
    }

    func pause() {
        wantsPlayback = false
        lastCommand = .now
        player.pause()
        refresh()
    }

    func resume() {
        wantsPlayback = true
        lastCommand = .now
        perform("play") { try await $0.play() }
    }

    /// Called when a video starts, as that can stop Apple Music, which is then started again
    func expectInterruption() {
        expectsInterruptionUntil = .now + .seconds(5)
    }

    func skipToNext() {
        perform("skip to next") { try await $0.skipToNextEntry() }
    }

    func skipToPrevious() {
        perform("skip to previous") { try await $0.skipToPreviousEntry() }
    }

    /// Runs a player command, showing and logging its error instead of dropping it
    private func perform(_ name: String, _ command: @escaping (ApplicationMusicPlayer) async throws -> Void) {
        Task {
            do {
                try await command(player)
                errorMessage = nil
            } catch {
                logger.error("Music mode: \(name) failed: \(String(describing: error))")
                errorMessage = "Apple Music couldn't \(name): \(error.localizedDescription)"
            }

            logState("after \(name)")
            refresh()
        }
    }

    private func logState(_ context: String) {
        let queue = player.queue
        let session = AVAudioSession.sharedInstance()
        let status = String(describing: player.state.playbackStatus)
        let current = queue.currentEntry?.title ?? "none"

        let audioSession = "\(session.category.rawValue) options \(session.categoryOptions.rawValue)"

        logger.info("Music mode \(context): status \(status), entries \(queue.entries.count), current \(current), audio session \(audioSession)")
    }

    func stop() {
        wantsPlayback = false
        lastCommand = nil
        expectsInterruptionUntil = nil
        monitorTask?.cancel()
        monitorTask = nil
        player.stop()
        errorMessage = nil
        currentSong = nil
        nextSong = nil
        isPlaying = false
    }

    // MARK: Catalog

    #if os(tvOS)
    /// The Apple Music catalog versions of library tracks, in the same order, without songs that aren't on Apple Music
    private func catalogSongs(for tracks: [Track]) async -> [Song] {
        var catalogIDs: [Int: MusicItemID] = [:]
        var isrcs: [Int: String] = [:]

        for (index, track) in tracks.enumerated() {
            if let id = Self.catalogID(from: track.playParameters) {
                catalogIDs[index] = id
            } else if case let .song(song) = track, let isrc = song.isrc {
                isrcs[index] = isrc
            }
        }

        // Looked up in batches, as each request takes a limited number of identifiers
        var songsByID: [MusicItemID: Song] = [:]
        for batch in Set(catalogIDs.values).chunks(ofCount: 100) {
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: Array(batch))
                for song in try await request.response().items {
                    songsByID[song.id] = song
                }
            } catch {
                // The songs in a failed batch fall back to a search
                logger.error("Music mode: catalog ID lookup failed: \(String(describing: error))")
            }
        }

        var songsByISRC: [String: Song] = [:]
        for batch in Set(isrcs.values).chunks(ofCount: 25) {
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.isrc, memberOf: Array(batch))
                for song in try await request.response().items {
                    if let isrc = song.isrc, songsByISRC[isrc] == nil {
                        songsByISRC[isrc] = song
                    }
                }
            } catch {
                logger.error("Music mode: ISRC lookup failed: \(String(describing: error))")
            }
        }

        var songs: [Song] = []
        var searched = 0

        for (index, track) in tracks.enumerated() {
            if let id = catalogIDs[index], let song = songsByID[id] {
                songs.append(song)
            } else if let isrc = isrcs[index], let song = songsByISRC[isrc] {
                songs.append(song)
            } else if let song = await searchCatalog(for: track) {
                searched += 1
                songs.append(song)
            }
        }

        logger.info(
            "Music mode: matched \(songsByID.count) songs by catalog ID, \(songsByISRC.count) by ISRC, \(searched) by search"
        )

        return songs
    }

    /// The catalog identifier inside a library track's play parameters, which are otherwise opaque
    private static func catalogID(from parameters: PlayParameters?) -> MusicItemID? {
        guard let parameters,
              let data = try? JSONEncoder().encode(parameters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if let id = json["catalogId"] as? String {
            return MusicItemID(id)
        }

        if let id = json["catalogId"] as? Int {
            return MusicItemID(String(id))
        }

        // Tracks that aren't library items already use their catalog identifier
        if json["isLibrary"] as? Bool != true, let id = json["id"] as? String {
            return MusicItemID(id)
        }

        return nil
    }

    /// Finds a song by its title and artist, for library tracks without a catalog identifier
    private func searchCatalog(for track: Track) async -> Song? {
        var request = MusicCatalogSearchRequest(term: "\(track.title) \(track.artistName)", types: [Song.self])
        request.limit = 5

        let songs = try? await request.response().songs

        return songs?.first { $0.title.localizedCaseInsensitiveCompare(track.title) == .orderedSame } ?? songs?.first
    }
    #endif

    // MARK: Monitoring

    /// Polls the player, as the queue object is replaced for each playlist and can't be observed reliably
    private func startMonitoring() {
        monitorTask?.cancel()

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                self.refresh()
                await self.followPlaybackStatus()

                // Often enough that the video follows a pause from the remote quickly
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func refresh() {
        let queue = player.queue

        let state = "\(player.state.playbackStatus) \(queue.entries.count) \(queue.currentEntry?.id ?? "none")"
        if state != lastLoggedState {
            lastLoggedState = state
            logState("changed")
        }

        currentSong = queue.currentEntry.map(Self.title(for:))
        nextSong = queue.nextEntry.map(Self.title(for:))
        isPlaying = player.state.playbackStatus == .playing
    }

    /// Keeps the player and `wantsPlayback` in step when the music is paused or played by something else.
    ///
    /// Starting a video can stop Apple Music, so it's started again. Any other outside pause, like the
    /// remote's Play/Pause button which the system sends straight to Apple Music, is kept instead.
    private func followPlaybackStatus() async {
        guard player.queue.currentEntry != nil else { return }

        let now = ContinuousClock.now
        // Right after the app's own command the player may not have caught up yet
        let isFollowingCommand = lastCommand.map { now - $0 < .seconds(2) } ?? false
        let expectsInterruption = expectsInterruptionUntil.map { now < $0 } ?? false

        switch player.state.playbackStatus {
        case .paused, .interrupted, .stopped:
            guard wantsPlayback else { return }

            guard isFollowingCommand || expectsInterruption else {
                logState("paused from outside")
                wantsPlayback = false
                return
            }

            if let lastAutoResume, now - lastAutoResume < .seconds(3) {
                return
            }

            lastAutoResume = .now
            logState("auto resume")

            do {
                try await player.play()
            } catch {
                logger.error("Music mode: auto resume failed: \(String(describing: error))")
                errorMessage = "Apple Music: \(error.localizedDescription)"
            }
        case .playing:
            guard !wantsPlayback else { return }

            if isFollowingCommand {
                // The system can also act on a Play/Pause press the app handled, undoing the app's pause
                player.pause()
            } else {
                logState("played from outside")
                wantsPlayback = true
            }
        default:
            break
        }
    }

    private static func title(for entry: MusicKit.MusicPlayer.Queue.Entry) -> String {
        guard let artist = entry.subtitle, artist.isNotEmpty else { return entry.title }
        return "\(entry.title) — \(artist)"
    }
}

extension ApplicationMusicPlayer.Queue {

    /// The entry after the current one, wrapping to the first as the queue repeats
    var nextEntry: Entry? {
        guard let currentEntry,
              let index = entries.firstIndex(where: { $0.id == currentEntry.id })
        else { return nil }

        let nextIndex = entries.index(after: index)

        return nextIndex < entries.endIndex ? entries[nextIndex] : entries.first
    }
}
