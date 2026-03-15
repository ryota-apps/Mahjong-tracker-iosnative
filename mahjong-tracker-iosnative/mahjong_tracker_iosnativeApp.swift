//
//  mahjong_tracker_iosnativeApp.swift
//  mahjong-tracker-iosnative
//
//  Created by 本間諒太 on 2026/03/14.
//

import SwiftUI
import SwiftData

@main
struct mahjong_tracker_iosnativeApp: App {
    var sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([Session.self, Shop.self])

        if CommandLine.arguments.contains("UI_TESTING") {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            sharedModelContainer = try! ModelContainer(for: schema, configurations: [config])
            return
        }

        let groupID = "group.com.ryota.mahjongtracker"
        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            storeURL = groupURL.appendingPathComponent("mahjong.sqlite")
        } else {
            storeURL = URL.applicationSupportDirectory.appendingPathComponent("mahjong.sqlite")
        }

        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: iCloudEnabled ? .automatic : .none
        )
        sharedModelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
