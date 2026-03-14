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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Session.self,
            Shop.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
