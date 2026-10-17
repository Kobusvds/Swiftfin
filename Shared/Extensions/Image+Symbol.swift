//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension Image {

    /// Creates an image from an SF Symbol name, falling back to a
    /// custom symbol of the same name in the asset catalog
    init(symbol name: String) {
        if UIImage(systemName: name) != nil {
            self.init(systemName: name)
        } else {
            self.init(name)
        }
    }
}

extension Label where Title == Text, Icon == Image {

    /// Creates a label whose icon is an SF Symbol or a custom asset catalog symbol
    init(_ title: String, symbol name: String) {
        self.init {
            Text(title)
        } icon: {
            Image(symbol: name)
        }
    }
}
