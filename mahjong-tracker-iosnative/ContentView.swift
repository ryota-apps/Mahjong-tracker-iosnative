//
//  ContentView.swift
//  mahjong-tracker-iosnative
//
//  Created by 本間諒太 on 2026/03/14.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("記録する", systemImage: "pencil") {
                RecordView()
            }
            Tab("戦績一覧", systemImage: "list.bullet") {
                Text("Coming Soon")
            }
            Tab("分析", systemImage: "chart.bar") {
                Text("Coming Soon")
            }
            Tab("店舗設定", systemImage: "building.2") {
                Text("Coming Soon")
            }
            Tab("データ", systemImage: "square.and.arrow.up") {
                Text("Coming Soon")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
}
