//
//  ContentView.swift
//  mahjong-tracker-iosnative
//
//  Created by 本間諒太 on 2026/03/14.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var filterState = FilterState()

    var body: some View {
        TabView {
            Tab("記録する", systemImage: "pencil") {
                RecordView()
            }
            Tab("戦績一覧", systemImage: "list.bullet") {
                HistoryView()
            }
            Tab("分析", systemImage: "chart.bar") {
                AnalysisView()
            }
            Tab("店舗設定", systemImage: "building.2") {
                ShopsView()
            }
            Tab("データ", systemImage: "square.and.arrow.up") {
                DataView()
            }
        }
        .environment(filterState)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
}
