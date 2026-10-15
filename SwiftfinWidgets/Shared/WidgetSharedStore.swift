//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import Security

/// Data the iOS app shares with its widgets through the app group.
///
/// This file is compiled into both the app and the widget extension.
enum WidgetSharedStore {

    /// The signed in user and the details needed to reach their server
    struct Account: Codable, Equatable {
        let serverID: String
        let serverURL: URL
        let userID: String
        let client: String
        let deviceName: String
        let deviceID: String
        let version: String
    }

    /// A main navigation tab
    struct Tab: Codable, Equatable, Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let isLibrary: Bool
    }

    enum WidgetKind {
        static let continueWatching = "org.jellyfin.swiftfin.widget.continue-watching"
        static let libraries = "org.jellyfin.swiftfin.widget.libraries"
    }

    private enum Key {
        static let account = "widget.account"
        static let tabs = "widget.tabs"
        static let accessTokenService = "org.jellyfin.swiftfin.widget"
        static let accessTokenAccount = "accessToken"
    }

    /// `group.<app bundle identifier>`, resolved the same way from the app and its extensions
    static let appGroupID: String = {
        let bundleID = Bundle.main.bundleIdentifier ?? ""

        guard Bundle.main.bundleURL.pathExtension == "appex" else {
            return "group.\(bundleID)"
        }

        // Extension bundle identifiers are `<app bundle identifier>.<extension name>`
        let appBundleID = bundleID
            .split(separator: ".")
            .dropLast()
            .joined(separator: ".")

        return "group.\(appBundleID)"
    }()

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Account

    static var account: Account? {
        get {
            guard let data = defaults?.data(forKey: Key.account) else { return nil }
            return try? JSONDecoder().decode(Account.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: Key.account)
            } else {
                defaults?.removeObject(forKey: Key.account)
            }
        }
    }

    // MARK: - Tabs

    static var tabs: [Tab] {
        get {
            guard let data = defaults?.data(forKey: Key.tabs) else { return [] }
            return (try? JSONDecoder().decode([Tab].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: Key.tabs)
            }
        }
    }

    // MARK: - Access Token

    /// Stored in the keychain, shared through the app group access group
    static var accessToken: String? {
        get {
            var query = accessTokenQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data
            else { return nil }

            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(accessTokenQuery as CFDictionary)

            guard let newValue, let data = newValue.data(using: .utf8) else { return }

            var attributes = accessTokenQuery
            attributes[kSecValueData as String] = data
            // Widgets refresh in the background, while the device may be locked
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    private static var accessTokenQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Key.accessTokenService,
            kSecAttrAccount as String: Key.accessTokenAccount,
            kSecAttrAccessGroup as String: appGroupID,
        ]
    }

    // MARK: - Deep Links

    /// A link handled by the app's `DeepLink`
    static func url(
        account: Account,
        destination: String,
        id: String
    ) -> URL? {
        URL(string: "swiftfin://\(account.serverID)/\(account.userID)/\(destination)/\(id)")
    }

    static func clear() {
        account = nil
        accessToken = nil
        tabs = []
    }
}
