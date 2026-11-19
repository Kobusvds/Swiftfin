//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// The video, song and brightness controls, shown on a tap or remote press
struct MusicModeControls: View {

    private enum Control: Hashable {
        case previousVideo
        case nextVideo
        case previousSong
        case playPause
        case nextSong
        case dimmer
        case brighter
        case change
        case stop
    }

    let video: MusicModeVideoQueue
    let music: MusicModeMusicController

    /// Whether the music and video are paused together
    let isPaused: Bool

    /// 1 is the normal brightness, 0 the darkest
    @Binding
    var brightness: Double

    let onTogglePlayback: () -> Void
    let onInteraction: () -> Void
    let onChangePlaylists: () -> Void
    let onStop: () -> Void

    #if os(tvOS)
    @FocusState
    private var focusedControl: Control?
    #endif

    @ViewBuilder
    private func controlButton(
        _ title: String,
        systemImage: String,
        control: Control,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            onInteraction()
        } label: {
            Image(systemName: systemImage)
                .font(isProminent ? .largeTitle : .title2)
                .frame(width: UIDevice.isTV ? 90 : 52, height: UIDevice.isTV ? 90 : 52)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
        #if os(tvOS)
            .buttonStyle(.card)
            .focused($focusedControl, equals: control)
        #else
            .buttonStyle(.plain)
        #endif
    }

    @ViewBuilder
    private func controlRow(_ title: String, @ViewBuilder buttons: () -> some View) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: UIDevice.isTV ? 40 : 28) {
                buttons()
            }
        }
    }

    @ViewBuilder
    private var brightnessControl: some View {
        controlRow("Brightness") {
            #if os(tvOS)
            // tvOS has no slider, so the brightness moves in steps
            controlButton("Dimmer", systemImage: "sun.min", control: .dimmer) {
                brightness = max(0, ((brightness - 0.2) * 10).rounded() / 10)
            }

            Text(brightness, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(minWidth: 100)

            controlButton("Brighter", systemImage: "sun.max", control: .brighter) {
                brightness = min(1, ((brightness + 0.2) * 10).rounded() / 10)
            }
            #else
            Image(systemName: "sun.min")

            Slider(value: $brightness, in: 0 ... 1) { editing in
                if !editing { onInteraction() }
            }
            .frame(maxWidth: 280)
            .onChange(of: brightness) {
                onInteraction()
            }

            Image(systemName: "sun.max")
            #endif
        }
    }

    var body: some View {
        VStack(spacing: UIDevice.isTV ? 40 : 24) {
            controlRow("Video") {
                controlButton("Previous Video", systemImage: "backward.end.fill", control: .previousVideo) {
                    video.skipToPrevious()
                }

                controlButton("Next Video", systemImage: "forward.end.fill", control: .nextVideo) {
                    video.skipToNext()
                }
            }

            controlRow("Music") {
                controlButton("Previous Song", systemImage: "backward.fill", control: .previousSong) {
                    music.skipToPrevious()
                }

                // Pauses and plays the video along with the music
                controlButton(
                    isPaused ? L10n.play : "Pause",
                    systemImage: isPaused ? "play.fill" : "pause.fill",
                    control: .playPause,
                    isProminent: true
                ) {
                    onTogglePlayback()
                }

                controlButton("Next Song", systemImage: "forward.fill", control: .nextSong) {
                    music.skipToNext()
                }
            }

            brightnessControl

            HStack(spacing: 20) {
                Button("Change Playlists", systemImage: "music.note.list") {
                    onChangePlaylists()
                }
                #if os(tvOS)
                .focused($focusedControl, equals: .change)
                #endif

                Button(L10n.stop, systemImage: "stop.fill", role: .destructive) {
                    onStop()
                }
                #if os(tvOS)
                .focused($focusedControl, equals: .stop)
                #endif
            }
            #if os(iOS)
            .buttonStyle(.bordered)
            #endif
        }
        .foregroundStyle(.white)
        .padding(UIDevice.isTV ? 60 : 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .environment(\.colorScheme, .dark)
        #if os(tvOS)
            .onAppear {
                focusedControl = .playPause
            }
            .onChange(of: focusedControl) {
                // Moving between controls keeps them on screen
                onInteraction()
            }
        #endif
    }
}
