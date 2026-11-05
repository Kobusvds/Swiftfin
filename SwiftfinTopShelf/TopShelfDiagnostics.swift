//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// Records the outcome of top shelf loads, to find out why the top shelf stays empty.
///
/// Each step is written to the app group and also posted as a Darwin notification,
/// which can be observed with `devicectl device notification observe` even if the app group is unreachable.
enum TopShelfDiagnostics {

    enum Step: String {
        case created
        case started
        case hasAccount
        case noAccount
        case hasToken
        case noToken
        case failed
        case finished
        case empty
        case appGroupUnavailable
    }

    private static let key = "topShelf.diagnostics"

    static func record(_ step: Step, _ details: String = "") {
        // The extension's own container is always writable
        if let fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "topshelf-diagnostics.txt"),
            let handle = try? FileHandle(forWritingTo: fileURL)
        {
            handle.seekToEndOfFile()
            handle.write(Data("\(Int(Date.now.timeIntervalSince1970)) \(step.rawValue) \(details)\n".utf8))
            try? handle.close()
        }

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("galactic.topshelf.\(step.rawValue)" as CFString),
            nil,
            nil,
            true
        )

        guard let defaults = UserDefaults(suiteName: WidgetSharedStore.appGroupID) else {
            if step != .appGroupUnavailable {
                record(.appGroupUnavailable)
            }
            return
        }

        var entries = defaults.stringArray(forKey: key) ?? []
        entries.append("\(Date.now.ISO8601Format()) \(step.rawValue) \(details)")
        defaults.set(Array(entries.suffix(20)), forKey: key)
    }
}
