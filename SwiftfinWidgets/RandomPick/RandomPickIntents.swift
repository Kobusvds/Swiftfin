//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import AppIntents
import WidgetKit

/// A library chosen in the random pick widget's settings
struct RandomPickLibraryEntity: AppEntity {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Library"
    static let defaultQuery = RandomPickLibraryQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ library: RandomPickLibrary) {
        self.init(id: library.id, name: library.name)
    }
}

struct RandomPickLibraryQuery: EntityQuery {

    func entities(for identifiers: [RandomPickLibraryEntity.ID]) async throws -> [RandomPickLibraryEntity] {
        try await RandomPickClient.libraries()
            .filter { identifiers.contains($0.id) }
            .map(RandomPickLibraryEntity.init)
    }

    func suggestedEntities() async throws -> [RandomPickLibraryEntity] {
        try await RandomPickClient.libraries()
            .map(RandomPickLibraryEntity.init)
    }

    /// Newly added widgets start with the first library
    func defaultResult() async -> RandomPickLibraryEntity? {
        try? await suggestedEntities().first
    }
}

struct RandomPickConfigurationIntent: WidgetConfigurationIntent {

    static let title: LocalizedStringResource = "Random Pick"
    static let description = IntentDescription("Choose the library to pick from.")

    @Parameter(title: "Library")
    var library: RandomPickLibraryEntity?
}

/// Run by the widget's dice button
struct RollRandomPickIntent: AppIntent {

    static let title: LocalizedStringResource = "Roll the Dice"
    static let description = IntentDescription("Picks another random movie or show.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        // A fresh timeline picks a new random item
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.WidgetKind.randomPick)
        return .result()
    }
}
