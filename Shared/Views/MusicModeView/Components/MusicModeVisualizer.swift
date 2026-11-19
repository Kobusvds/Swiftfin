//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// A Windows Media Player style spectrum of bars with falling peaks.
///
/// Apple Music's audio can't be read by the app, so the bars move randomly to a made up beat.
struct MusicModeVisualizer: View {

    /// Whether the bars move, or fall to rest
    let isActive: Bool

    @State
    private var spectrum = MusicModeSpectrum(barCount: 14)

    private static let segmentCount = 16

    private var size: CGFloat {
        UIDevice.isTV ? 170 : 76
    }

    /// Green at the bottom, yellow, then red at the top, like an LED meter
    private static func color(at position: Double) -> Color {
        switch position {
        case ..<0.6:
            Color(red: 0.2, green: 0.95, blue: 0.3)
        case ..<0.85:
            Color(red: 1, green: 0.85, blue: 0.1)
        default:
            Color(red: 1, green: 0.25, blue: 0.2)
        }
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let barCount = spectrum.levels.count
        let barGap = size.width * 0.03
        let barWidth = (size.width - barGap * CGFloat(barCount - 1)) / CGFloat(barCount)
        let segmentGap = size.height * 0.012
        let segmentHeight = (size.height - segmentGap * CGFloat(Self.segmentCount - 1)) / CGFloat(Self.segmentCount)

        for bar in 0 ..< barCount {
            let x = CGFloat(bar) * (barWidth + barGap)
            let litSegments = Int((spectrum.levels[bar] * Double(Self.segmentCount)).rounded())

            for segment in 0 ..< Self.segmentCount {
                let y = size.height - CGFloat(segment + 1) * segmentHeight - CGFloat(segment) * segmentGap
                let rect = CGRect(x: x, y: y, width: barWidth, height: segmentHeight)
                let color = Self.color(at: Double(segment) / Double(Self.segmentCount - 1))

                // Unlit segments stay faintly visible, as on the real meter
                context.fill(Path(rect), with: .color(segment < litSegments ? color : color.opacity(0.08)))
            }

            // The peak hangs above the bar for a moment, then falls
            let peak = spectrum.peaks[bar]
            if peak > 0.02 {
                let y = size.height - CGFloat(peak) * size.height
                let rect = CGRect(x: x, y: max(0, y - segmentHeight * 0.5), width: barWidth, height: segmentHeight * 0.5)
                context.fill(Path(rect), with: .color(.white.opacity(0.9)))
            }
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                spectrum.update(at: timeline.date, isActive: isActive)
                draw(in: context, size: size)
            }
        }
        .padding(UIDevice.isTV ? 14 : 7)
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: UIDevice.isTV ? 14 : 8))
        .overlay {
            RoundedRectangle(cornerRadius: UIDevice.isTV ? 14 : 8)
                .strokeBorder(.white.opacity(0.15))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// The bar levels of the visualizer, moved on every frame.
///
/// Not observed, as the timeline redraws the visualizer anyway.
private final class MusicModeSpectrum {

    /// 0 is empty and 1 full, from the lowest frequency on the left
    private(set) var levels: [Double]
    private(set) var peaks: [Double]

    private var targets: [Double]
    private var lastUpdate: Date?
    private var nextBeat: Date = .distantPast
    /// How much the last beat still lifts the low bars
    private var beat = 0.0

    init(barCount: Int) {
        levels = Array(repeating: 0, count: barCount)
        peaks = Array(repeating: 0, count: barCount)
        targets = Array(repeating: 0, count: barCount)
    }

    func update(at date: Date, isActive: Bool) {
        // Capped, so a long pause between frames doesn't make the bars jump
        let elapsed = min(lastUpdate.map { date.timeIntervalSince($0) } ?? 0, 0.1)
        lastUpdate = date

        guard elapsed > 0 else { return }

        if isActive {
            if date >= nextBeat {
                // Around 120 BPM, drifting slightly so it doesn't feel mechanical
                beat = .random(in: 0.6 ... 1)
                nextBeat = date.addingTimeInterval(.random(in: 0.42 ... 0.56))
            }

            beat = max(0, beat - elapsed * 2.4)

            for index in targets.indices where Double.random(in: 0 ... 1) < elapsed * 9 {
                let position = Double(index) / Double(max(1, targets.count - 1))

                // Low frequencies carry more energy, and most of the beat
                let base = (0.7 - position * 0.35) * .random(in: 0.3 ... 1)
                targets[index] = min(1, max(0.04, base + beat * (1 - position) * 0.5))
            }
        } else {
            targets = targets.map { _ in 0 }
        }

        for index in levels.indices {
            let target = targets[index]

            // Rises quickly and falls slowly
            let speed = target > levels[index] ? 20.0 : 5.0
            levels[index] += (target - levels[index]) * min(1, speed * elapsed)

            if levels[index] >= peaks[index] {
                peaks[index] = levels[index]
            } else {
                peaks[index] = max(0, peaks[index] - elapsed * 0.4)
            }
        }
    }
}
