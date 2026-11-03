//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// Records the outcome of the last top shelf load in the app group, to find out why the top shelf stays empty
enum TopShelfDiagnostics {

    private static let key = "topShelf.diagnostics"

    static func record(_ outcome: String) {
        let defaults = UserDefaults(suiteName: WidgetSharedStore.appGroupID)
        var entries = defaults?.stringArray(forKey: key) ?? []

        entries.append("\(Date.now.ISO8601Format()) \(outcome)")
        defaults?.set(Array(entries.suffix(20)), forKey: key)
    }
}
