//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct AppIconSelectorView: View {

    @State
    private var currentAppIcon = AppIcon.current

    @MainActor
    private func select(icon: AppIcon) async {
        let previousAppIcon = currentAppIcon
        currentAppIcon = icon

        if MacDockIcon.isEnabled {
            if !MacDockIcon.select(icon) {
                currentAppIcon = previousAppIcon
            }
            return
        }

        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
        } catch {
            currentAppIcon = previousAppIcon
        }
    }

    private func row(for icon: AppIcon) -> some View {
        AppIconRow(icon: icon) {
            Task {
                await select(icon: icon)
            }
        }
        .isSelected(icon == currentAppIcon)
    }

    var body: some View {
        Form {
            Section("Nextflix") {
                ForEach(AppIcon.allCases.filter(\.isNextflix)) { icon in
                    row(for: icon)
                }
            }

            Section(L10n.jellyfin) {
                ForEach(AppIcon.allCases.filter { !$0.isNextflix }) { icon in
                    row(for: icon)
                }
            }
        } image: {
            Image(currentAppIcon.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 400)
                .cornerRadius(48)
                .subtleShadow()
        }
        .navigationTitle(L10n.appIcon.localizedCapitalized)
    }
}

extension AppIconSelectorView {

    struct AppIconRow: View {

        let icon: AppIcon
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack {
                    Image(icon.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIDevice.isTV ? 150 : 60, height: UIDevice.isTV ? 90 : 60)
                        .cornerRadius(UIDevice.isTV ? 18 : 12)
                        .subtleShadow()

                    Text(icon.displayTitle)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ListRowCheckbox()
                        .isEditing(true)
                }
            }
            .foregroundStyle(.primary, .secondary)
        }
    }
}
