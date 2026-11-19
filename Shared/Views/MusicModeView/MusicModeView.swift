//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import MusicKit
import SwiftUI

/// Plays a Jellyfin video source without sound over an Apple Music playlist
struct MusicModeView: View {

    private enum SelectionSheet: String, Identifiable {
        case videos
        case music

        var id: String {
            rawValue
        }
    }

    @Default(.MusicMode.videoSource)
    private var videoSource
    @Default(.MusicMode.musicPlaylist)
    private var musicPlaylist
    @Default(.MusicMode.shuffleVideos)
    private var shuffleVideos
    @Default(.MusicMode.shuffleSongs)
    private var shuffleSongs
    @Default(.MusicMode.showsVisualizer)
    private var showsVisualizer

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var video = MusicModeVideoQueue()
    @State
    private var music = MusicModeMusicController()
    @State
    private var isPlaying = false
    @State
    private var isVisible = false
    /// The music and video pause and play together
    @State
    private var isPaused = false
    @State
    private var areControlsVisible = false
    /// Bumped on every interaction to restart the controls' auto hide
    @State
    private var controlsInteraction = 0
    /// 1 is the normal brightness, 0 the darkest
    @State
    private var brightness = 1.0
    @State
    private var picker: SelectionSheet?

    #if os(iOS)
    @State
    private var screenBrightness = MusicModeScreenBrightness()
    #endif

    #if os(tvOS)
    @FocusState
    private var isBackgroundFocused: Bool
    /// Set when the app moves focus itself, so only the remote moving down opens the controls
    @State
    private var isFocusingBackground = false
    /// The tab bar hides while playing, and comes back when the remote moves up or presses Menu
    @State
    private var isTabBarVisible = false
    #endif

    private var canStart: Bool {
        videoSource != nil && musicPlaylist != nil
    }

    private var errorMessages: [String] {
        [video.errorMessage, music.errorMessage].compactMap(\.self)
    }

    // MARK: Actions

    private func start() {
        guard let videoSource, let musicPlaylist else { return }

        isPlaying = true
        isPaused = false
        areControlsVisible = false

        // Set before either player starts, so neither interrupts the other
        MusicModeVideoQueue.configureAudioSession()

        // A video starting can stop the music, which shouldn't count as a pause
        video.onWillPlay = { [music] in
            music.expectInterruption()
        }

        // The music starts once the video plays, so starting the video can't stop it
        Task {
            await video.load(source: videoSource, shuffle: shuffleVideos)
            await video.waitUntilPlaying()
            await music.play(musicPlaylist, shuffle: shuffleSongs)
        }
    }

    private func stop() {
        isPlaying = false
        isPaused = false
        areControlsVisible = false
        brightness = 1
        video.stop()
        music.stop()
    }

    private func togglePlayback() {
        isPaused.toggle()

        if isPaused {
            music.pause()
            video.pause()
        } else {
            music.resume()
            video.resume()
        }
    }

    /// The music was paused or played from outside the app's controls, so the video follows it
    private func followMusicPlayback() {
        guard isPlaying, music.wantsPlayback == isPaused else { return }

        isPaused = !music.wantsPlayback

        if isPaused {
            video.pause()
        } else if isVisible {
            video.resume()
        }
    }

    private func showControls() {
        areControlsVisible = true
        controlsInteraction += 1

        #if os(tvOS)
        isTabBarVisible = false
        #endif
    }

    private func hideControls() {
        areControlsVisible = false

        #if os(tvOS)
        focusBackground()
        #endif
    }

    #if os(tvOS)
    private func focusBackground() {
        isFocusingBackground = true
        isBackgroundFocused = true
    }

    private func showTabBar() {
        isTabBarVisible = true
    }
    #endif

    /// Keeps the screen awake and applies the brightness only while the session is on screen
    private func updateScreen() {
        let isActive = isPlaying && isVisible && scenePhase == .active

        UIApplication.shared.isIdleTimerDisabled = isActive

        #if os(iOS)
        if isActive {
            screenBrightness.apply(brightness)
        } else {
            screenBrightness.restore()
        }
        #endif
    }

    // MARK: Setup

    @ViewBuilder
    private func selectionRow(_ title: String, value: String?, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)

            Spacer()

            Text(value ?? "Choose")
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var setupView: some View {
        List {
            Section {
                Button {
                    picker = .videos
                } label: {
                    selectionRow("Videos", value: videoSource?.name, systemImage: videoSource?.systemImage ?? "film")
                }

                Toggle("Shuffle Videos", isOn: $shuffleVideos)
            } header: {
                Text("Videos")
            } footer: {
                Text("A Jellyfin playlist, collection or library. Videos play without sound.")
            }

            Section {
                Button {
                    picker = .music
                } label: {
                    selectionRow("Playlist", value: musicPlaylist?.name, systemImage: "music.note.list")
                }

                Toggle("Shuffle Songs", isOn: $shuffleSongs)
            } header: {
                Text("Apple Music")
            } footer: {
                Text("A playlist from your Apple Music library. Videos and songs repeat when they reach the end.")
            }

            Section {
                Toggle("Visualizer", isOn: $showsVisualizer)
            } footer: {
                Text("Shows moving bars in the bottom corner while music plays.")
            }

            Section {
                Button {
                    start()
                } label: {
                    Label(L10n.play, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canStart)
            }
        }
        .navigationTitle("Music")
        .sheet(item: $picker) { picker in
            NavigationStack {
                Group {
                    switch picker {
                    case .videos:
                        MusicModeVideoSourcePicker(selection: $videoSource)
                    case .music:
                        MusicModePlaylistPicker(selection: $musicPlaylist)
                    }
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) {
                            self.picker = nil
                        }
                    }
                }
                #endif
            }
        }
    }

    // MARK: Player

    @ViewBuilder
    private var playerView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            MusicModeVideoLayer(player: video.player)
                .ignoresSafeArea()

            if video.isLoading || music.isLoading {
                ProgressView()
                    .tint(.white)
            }

            HStack(alignment: .bottom, spacing: 16) {
                MusicModeInfoStrip(
                    video: video,
                    music: music,
                    errorMessages: errorMessages
                )

                Spacer(minLength: 0)

                if showsVisualizer {
                    MusicModeVisualizer(isActive: music.isPlaying && !isPaused)
                        .transition(.opacity)
                }
            }
            .padding(UIDevice.isTV ? 0 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            // Over the video and info, but under the controls so they stay readable
            Color.black
                .opacity((1 - brightness) * 0.85)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            #if os(tvOS)
            if !areControlsVisible {
                // Something has to hold focus for a remote press to show the controls
                Button(action: showControls) {
                    // Fully clear views can't take focus, so this is nearly, not fully, transparent
                    Color.black.opacity(0.02)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(MusicModeInvisibleButtonStyle())
                .focused($isBackgroundFocused)
                .onAppear {
                    // Takes focus from the tab bar, so the remote reaches this screen
                    focusBackground()
                }
                .onChange(of: isBackgroundFocused) {
                    // Swiping down from the tab bar opens the controls
                    if isBackgroundFocused, !isFocusingBackground {
                        showControls()
                    }

                    isFocusingBackground = false
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .up:
                        // Moving up brings back the tab bar, and moving up again focuses it
                        showTabBar()
                    case .down:
                        // Pressing down while on the page opens the controls
                        showControls()
                    default:
                        break
                    }
                }
                // Menu brings back the tab bar first, then does what it normally does
                .onExitCommand(perform: isTabBarVisible ? nil : showTabBar)
                .task(id: isTabBarVisible) {
                    guard isTabBarVisible else { return }

                    try? await Task.sleep(for: .seconds(5))

                    // Hidden again if the remote didn't move up into it
                    guard !Task.isCancelled, isBackgroundFocused else { return }
                    isTabBarVisible = false
                }
            }
            #endif

            if areControlsVisible {
                #if os(iOS)
                // Tapping around the controls hides them
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture(perform: hideControls)
                #endif

                MusicModeControls(
                    video: video,
                    music: music,
                    isPaused: isPaused,
                    brightness: $brightness,
                    onTogglePlayback: togglePlayback,
                    onInteraction: { controlsInteraction += 1 },
                    onChangePlaylists: {
                        stop()
                    },
                    onStop: stop
                )
                .padding()
                .transition(.opacity)
                #if os(tvOS)
                    .onExitCommand(perform: hideControls)
                #endif
            }
        }
        .animation(.easeInOut(duration: 0.25), value: areControlsVisible)
        .animation(.easeInOut(duration: 0.25), value: showsVisualizer)
        #if os(iOS)
            .contentShape(Rectangle())
            .onTapGesture(perform: showControls)
            .toolbar(areControlsVisible ? .visible : .hidden, for: .navigationBar, .tabBar)
            .statusBarHidden(!areControlsVisible)
            .persistentSystemOverlays(areControlsVisible ? .automatic : .hidden)
        #else
            .onPlayPauseCommand {
                togglePlayback()

                if areControlsVisible {
                    controlsInteraction += 1
                }
            }
        #endif
            .task(id: controlsInteraction) {
                guard areControlsVisible else { return }

                try? await Task.sleep(for: .seconds(6))

                guard !Task.isCancelled else { return }
                hideControls()
            }
    }

    var body: some View {
        Group {
            if isPlaying {
                playerView
            } else {
                setupView
            }
        }
        #if os(tvOS)
        .toolbar(isPlaying && !isTabBarVisible ? .hidden : .automatic, for: .tabBar)
        .animation(.easeInOut(duration: 0.25), value: isTabBarVisible)
        #endif
        .onAppear {
            isVisible = true

            if isPlaying, !isPaused {
                video.resume()
            }

            updateScreen()
        }
        .onDisappear {
            // Music keeps playing in other tabs, but the video only plays here
            isVisible = false
            areControlsVisible = false
            #if os(tvOS)
            isTabBarVisible = false
            #endif
            video.pause()
            updateScreen()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, isPlaying, isVisible, !isPaused {
                video.resume()
            }

            updateScreen()
        }
        .onChange(of: isPlaying) {
            updateScreen()
        }
        .onChange(of: music.wantsPlayback) {
            followMusicPlayback()
        }
        .onChange(of: brightness) {
            updateScreen()
        }
    }
}

#if os(tvOS)
/// A button without the focus effect, filling the screen behind the video info
private struct MusicModeInvisibleButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
#endif

#if os(iOS)
/// Lowers the screen's own brightness, and puts it back when leaving the Music tab
@MainActor
private final class MusicModeScreenBrightness {

    private var originalBrightness: CGFloat?

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
    }

    func apply(_ brightness: Double) {
        // A Mac's display brightness can't be changed by the app
        guard !ProcessInfo.processInfo.isiOSAppOnMac, let screen else { return }

        guard brightness < 1 else {
            restore()
            return
        }

        if originalBrightness == nil {
            originalBrightness = screen.brightness
        }

        screen.brightness = (originalBrightness ?? 1) * brightness
    }

    func restore() {
        guard let originalBrightness, let screen else { return }

        screen.brightness = originalBrightness
        self.originalBrightness = nil
    }
}
#endif
