import SwiftUI
import SwiftData
import Charts

// MARK: - AnalysisView

struct AnalysisView: View {
    @Query(sort: \Session.createdAt, order: .reverse) private var allSessions: [Session]
    @Environment(FilterState.self) private var filterState

    // MARK: Computed

    private var uniqueShops: [String] {
        Array(Set(allSessions.map(\.shop))).sorted()
    }

    private var uniqueRates: [Int] {
        Array(Set(allSessions.map(\.rule))).sorted()
    }

    private var filteredSessions: [Session] {
        var result = applyDateFilter(Array(allSessions), preset: filterState.dateRange)
        if let p = filterState.filterPlayers  { result = result.filter { $0.players == p } }
        if let gt = filterState.filterGameType { result = result.filter { $0.gameType == gt } }
        if let s = filterState.filterShop     { result = result.filter { $0.shop == s } }
        if let r = filterState.filterRate     { result = result.filter { $0.rule == r } }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: Chart data structs

    struct CumulativePoint: Identifiable {
        let id = UUID()
        let date: Date
        let cumulative: Int
    }

    struct MonthlyBar: Identifiable {
        let id = UUID()
        let label: String
        let monthStart: Date
        let net: Int
    }

    // MARK: Chart data

    private var cumulativePoints: [CumulativePoint] {
        var running = 0
        let all: [CumulativePoint] = filteredSessions.map { session in
            running += getNet(session, withFees: filterState.withFees)
            return CumulativePoint(date: session.date, cumulative: running)
        }
        // .all: show last 30 sessions; filtered period: show all sessions in range
        return filterState.dateRange == .all ? Array(all.suffix(30)) : all
    }

    private var monthlyBars: [MonthlyBar] {
        let cal = Calendar.current
        let now = Date()
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月"
        return stride(from: -5, through: 0, by: 1).compactMap { offset -> MonthlyBar? in
            guard let monthStart = cal.date(byAdding: .month, value: offset, to: thisMonthStart),
                  let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
            let monthSessions = filteredSessions.filter { $0.date >= monthStart && $0.date < nextMonth }
            guard !monthSessions.isEmpty else { return nil }
            let net = monthSessions.reduce(0) { $0 + getNet($1, withFees: filterState.withFees) }
            return MonthlyBar(label: fmt.string(from: monthStart), monthStart: monthStart, net: net)
        }
    }

    // MARK: Stats helpers

    private var totalNet: Int { filteredSessions.reduce(0) { $0 + getNet($1, withFees: filterState.withFees) } }
    private var totalChipNet: Int { filteredSessions.reduce(0) { $0 + $1.chipVal } }
    private var hasChipData: Bool { filteredSessions.contains { $0.chipVal != 0 } }
    private var maxNet: Int { filteredSessions.map { getNet($0, withFees: filterState.withFees) }.max() ?? 0 }
    private var minNet: Int { filteredSessions.map { getNet($0, withFees: filterState.withFees) }.min() ?? 0 }

    private func totalGameCount(players: Int) -> Int {
        filteredSessions.filter { $0.players == players }.reduce(0) { $0 + $1.totalGames }
    }

    private func avgPlace(players: Int) -> Double {
        let sessions = filteredSessions.filter { $0.players == players }
        let total = sessions.reduce(0) { $0 + $1.totalGames }
        guard total > 0 else { return 0 }
        let w = sessions.reduce(0) { $0 + $1.count1*1 + $1.count2*2 + $1.count3*3 + $1.count4*4 }
        return Double(w) / Double(total)
    }

    private func placeCount(_ place: Int, players: Int) -> Int {
        let sessions = filteredSessions.filter { $0.players == players }
        switch place {
        case 1: return sessions.reduce(0) { $0 + $1.count1 }
        case 2: return sessions.reduce(0) { $0 + $1.count2 }
        case 3: return sessions.reduce(0) { $0 + $1.count3 }
        case 4: return sessions.reduce(0) { $0 + $1.count4 }
        default: return 0
        }
    }

    // MARK: Shop stats

    struct ShopStats: Identifiable {
        let id = UUID()
        let name: String
        let sessionCount: Int
        let gameCount: Int
        let firstPlaceRate: Double
        let net: Int
        let chipNet: Int
    }

    private var shopStats: [ShopStats] {
        let groups = Dictionary(grouping: filteredSessions, by: \.shop)
        return groups.map { (name, sessions) in
            let gameCount = sessions.reduce(0) { $0 + $1.totalGames }
            let firstCount = sessions.reduce(0) { $0 + $1.count1 }
            let firstRate = gameCount > 0 ? Double(firstCount) / Double(gameCount) : 0
            let net = sessions.reduce(0) { $0 + getNet($1, withFees: filterState.withFees) }
            let chip = sessions.reduce(0) { $0 + $1.chipVal }
            return ShopStats(
                name: name.isEmpty ? "店舗未設定" : name,
                sessionCount: sessions.count,
                gameCount: gameCount,
                firstPlaceRate: firstRate,
                net: net,
                chipNet: chip
            )
        }
        .sorted { abs($0.net) > abs($1.net) }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPaper").ignoresSafeArea()
                VStack(spacing: 0) {
                    headerTitle
                    filterBar
                    if filteredSessions.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                cumulativeChartSection
                                summaryCardSection
                                monthlyBarSection
                                avgPlaceSection
                                placeDistSection
                                shopStatsSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: Header

    private var headerTitle: some View {
        HStack {
            Text("分析")
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(Color("AppInk"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateRangePreset.allCases, id: \.self) { preset in
                    Button(action: { filterState.dateRange = preset }) {
                        filterChipLabel(preset.rawValue, active: filterState.dateRange == preset)
                    }
                }
                chipDivider
                Menu {
                    Button("全人数") { filterState.filterPlayers = nil }
                    Button("3人") { filterState.filterPlayers = 3 }
                    Button("4人") { filterState.filterPlayers = 4 }
                } label: {
                    filterChipLabel(filterState.filterPlayers.map { "\($0)人" } ?? "人数",
                                    active: filterState.filterPlayers != nil)
                }
                Menu {
                    Button("全種別") { filterState.filterGameType = nil }
                    Button("フリー") { filterState.filterGameType = "free" }
                    Button("セット") { filterState.filterGameType = "set" }
                } label: {
                    filterChipLabel(
                        filterState.filterGameType == "free" ? "フリー" : filterState.filterGameType == "set" ? "セット" : "種別",
                        active: filterState.filterGameType != nil
                    )
                }
                if !uniqueShops.isEmpty {
                    Menu {
                        Button("全店舗") { filterState.filterShop = nil }
                        ForEach(uniqueShops, id: \.self) { name in
                            Button(name) { filterState.filterShop = name }
                        }
                    } label: {
                        filterChipLabel(filterState.filterShop ?? "店舗", active: filterState.filterShop != nil)
                    }
                }
                if !uniqueRates.isEmpty {
                    Menu {
                        Button("全レート") { filterState.filterRate = nil }
                        ForEach(uniqueRates, id: \.self) { r in
                            Button(r == 0 ? "未設定" : "\(r)点") { filterState.filterRate = r }
                        }
                    } label: {
                        filterChipLabel(
                            filterState.filterRate.map { $0 == 0 ? "未設定" : "\($0)点" } ?? "レート",
                            active: filterState.filterRate != nil
                        )
                    }
                }
                chipDivider
                Button(action: { filterState.withFees.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: filterState.withFees ? "checkmark.square.fill" : "square").font(.caption)
                        Text(filterState.withFees ? "差し引く" : "差し引かない").font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(filterState.withFees ? Color("AppInk") : Color("AppCream"))
                    .foregroundStyle(filterState.withFees ? Color("AppPaper") : Color("AppInk"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color("AppInk").opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Color("AppPaper"))
    }

    private func filterChipLabel(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(active ? Color("AppInk") : Color("AppCream"))
            .foregroundStyle(active ? Color("AppPaper") : Color("AppInk"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color("AppInk").opacity(0.2), lineWidth: 1))
    }

    private var chipDivider: some View {
        Rectangle().fill(Color("AppInk").opacity(0.15)).frame(width: 1, height: 20)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🀄").font(.system(size: 52))
            Text("データなし")
                .font(.headline).foregroundStyle(Color("AppInk").opacity(0.5))
            Text("フィルターを変更するか、新しいセッションを記録してください")
                .font(.caption).foregroundStyle(Color("AppInk").opacity(0.35))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: Section 1: 累計純収支チャート

    private var cumulativeChartSection: some View {
        analysisCard("累計純収支の推移") {
            if cumulativePoints.isEmpty {
                noDataLabel
            } else {
                Chart {
                    ForEach(cumulativePoints) { point in
                        // Teal fill above zero
                        AreaMark(
                            x: .value("日付", point.date),
                            yStart: .value("Base", 0),
                            yEnd: .value("Net", max(point.cumulative, 0))
                        )
                        .foregroundStyle(Color("AppTeal").opacity(0.2))
                        .interpolationMethod(.catmullRom)

                        // Red fill below zero
                        AreaMark(
                            x: .value("日付", point.date),
                            yStart: .value("Net", min(point.cumulative, 0)),
                            yEnd: .value("Base", 0)
                        )
                        .foregroundStyle(Color("AppRed").opacity(0.2))
                        .interpolationMethod(.catmullRom)

                        // Actual line
                        LineMark(
                            x: .value("日付", point.date),
                            y: .value("Net", point.cumulative)
                        )
                        .foregroundStyle(Color("AppInk").opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        // Point marks
                        PointMark(
                            x: .value("日付", point.date),
                            y: .value("Net", point.cumulative)
                        )
                        .foregroundStyle(point.cumulative >= 0 ? Color("AppTeal") : Color("AppRed"))
                        .symbolSize(36)
                    }
                    // Zero line
                    RuleMark(y: .value("Zero", 0))
                        .lineStyle(StrokeStyle(dash: [5, 4]))
                        .foregroundStyle(Color("AppInk").opacity(0.2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatMMDD(date))
                                    .font(.caption2)
                                    .foregroundStyle(Color("AppInk").opacity(0.5))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatK(v))
                                    .font(.caption2)
                                    .foregroundStyle(v > 0 ? Color("AppTeal") : v < 0 ? Color("AppRed") : Color("AppInk").opacity(0.4))
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: Section 2: 収支サマリーカード

    private var summaryCardSection: some View {
        let sessions = filteredSessions
        let avgNet = sessions.isEmpty ? 0 : totalNet / sessions.count

        return analysisCard("収支サマリー") {
            VStack(spacing: 0) {
                kvRow("累計純収支", value: signedYen(totalNet),
                      valueColor: totalNet >= 0 ? Color("AppTeal") : Color("AppRed"), bold: true)
                thinDivider
                kvRow("平均（1セッション）", value: signedYen(avgNet),
                      valueColor: avgNet >= 0 ? Color("AppTeal") : Color("AppRed"))
                thinDivider
                kvRow("最高", value: sessions.isEmpty ? "—" : signedYen(maxNet),
                      valueColor: Color("AppTeal"))
                thinDivider
                kvRow("最低", value: sessions.isEmpty ? "—" : signedYen(minNet),
                      valueColor: Color("AppRed"))
                if hasChipData {
                    thinDivider
                    kvRow("累計チップ収支", value: signedYen(totalChipNet),
                          valueColor: totalChipNet >= 0 ? Color("AppTeal") : Color("AppRed"))
                }
                thinDivider
                kvRow("セッション数", value: "\(sessions.count)回", valueColor: Color("AppInk"))
            }
        }
    }

    // MARK: Section 3: 月別収支

    private var monthlyBarSection: some View {
        analysisCard("月別収支（直近6ヶ月）") {
            if monthlyBars.isEmpty {
                noDataLabel
            } else {
                Chart {
                    ForEach(monthlyBars) { bar in
                        BarMark(
                            x: .value("月", bar.label),
                            y: .value("収支", bar.net)
                        )
                        .foregroundStyle(bar.net >= 0 ? Color("AppTealLight") : Color("AppRed"))
                        .cornerRadius(4)
                    }
                    RuleMark(y: .value("Zero", 0))
                        .lineStyle(StrokeStyle(dash: [5, 4]))
                        .foregroundStyle(Color("AppInk").opacity(0.2))
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label).font(.caption2).foregroundStyle(Color("AppInk").opacity(0.5))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatK(v))
                                    .font(.caption2)
                                    .foregroundStyle(Color("AppInk").opacity(0.4))
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: Section 4: 平均着順

    private var avgPlaceSection: some View {
        let has4 = filteredSessions.contains { $0.players == 4 }
        let has3 = filteredSessions.contains { $0.players == 3 }

        return analysisCard("平均着順") {
            if !has4 && !has3 {
                noDataLabel
            } else {
                VStack(spacing: 0) {
                    if has4 {
                        avgPlaceRow(label: "四麻", players: 4)
                    }
                    if has4 && has3 { thinDivider }
                    if has3 {
                        avgPlaceRow(label: "三麻", players: 3)
                    }
                }
            }
        }
    }

    private func avgPlaceRow(label: String, players: Int) -> some View {
        let avg = avgPlace(players: players)
        let total = totalGameCount(players: players)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("AppInk"))
                Text("\(total)局")
                    .font(.caption2)
                    .foregroundStyle(Color("AppInk").opacity(0.45))
            }
            Spacer()
            Text(total > 0 ? String(format: "%.2f", avg) : "—")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color("AppInk"))
            Text("着")
                .font(.caption)
                .foregroundStyle(Color("AppInk").opacity(0.5))
                .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Section 5: 着順分布

    private var placeDistSection: some View {
        let has4 = filteredSessions.contains { $0.players == 4 }
        let has3 = filteredSessions.contains { $0.players == 3 }

        return analysisCard("着順分布") {
            if !has4 && !has3 {
                noDataLabel.padding(.horizontal, 16).padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    if has4 {
                        placeDistBlock(label: "四麻", players: 4)
                    }
                    if has4 && has3 {
                        thinDivider.padding(.vertical, 4)
                    }
                    if has3 {
                        placeDistBlock(label: "三麻", players: 3)
                    }
                }
            }
        }
    }

    private func placeDistBlock(label: String, players: Int) -> some View {
        let total = totalGameCount(players: players)
        let placeColors: [Int: Color] = [
            1: Color("Place1"), 2: Color("Place2"), 3: Color("Place3"), 4: Color("Place4")
        ]
        let places = players == 4 ? [1, 2, 3, 4] : [1, 2, 3]

        return VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppInk").opacity(0.5))
                .padding(.horizontal, 16)

            if total > 0 {
                // Segmented bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(places, id: \.self) { place in
                            let count = placeCount(place, players: players)
                            let fraction = CGFloat(count) / CGFloat(total)
                            if fraction > 0 {
                                Rectangle()
                                    .fill(placeColors[place] ?? .gray)
                                    .frame(width: max((geo.size.width - CGFloat(places.count - 1) * 2) * fraction, 2))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 20)
                .padding(.horizontal, 16)

                // Labels
                HStack(spacing: 12) {
                    ForEach(places, id: \.self) { place in
                        let count = placeCount(place, players: players)
                        let pct = total > 0 ? Int(Double(count) / Double(total) * 100) : 0
                        HStack(spacing: 3) {
                            Circle()
                                .fill(placeColors[place] ?? .gray)
                                .frame(width: 6, height: 6)
                            Text("\(place)着 \(count)(\(pct)%)")
                                .font(.caption2)
                                .foregroundStyle(Color("AppInk").opacity(0.65))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                noDataLabel.padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: Section 6: 店舗別統計

    private var shopStatsSection: some View {
        analysisCard("店舗別統計") {
            if shopStats.isEmpty {
                noDataLabel.padding(.horizontal, 16).padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shopStats.enumerated()), id: \.element.id) { (idx, stats) in
                        if idx > 0 { thinDivider }
                        shopStatsRow(stats)
                    }
                }
            }
        }
    }

    private func shopStatsRow(_ stats: ShopStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stats.name)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(Color("AppInk"))
                Spacer()
                Text(signedYen(stats.net))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(stats.net >= 0 ? Color("AppTeal") : Color("AppRed"))
            }
            HStack(spacing: 12) {
                labelValue("\(stats.sessionCount)回", label: "セッション")
                labelValue("\(stats.gameCount)局", label: "ゲーム")
                labelValue(stats.gameCount > 0
                    ? String(format: "%.0f%%", stats.firstPlaceRate * 100)
                    : "—", label: "1着率")
                if stats.chipNet != 0 {
                    labelValue(signedYen(stats.chipNet), label: "チップ")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func labelValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppInk"))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color("AppInk").opacity(0.45))
        }
    }

    // MARK: Reusable card container

    private func analysisCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card title
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AppInk").opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Color("AppInk").opacity(0.07))
                .frame(height: 0.5)

            content()
                .padding(.bottom, 14)
        }
        .background(Color("AppCream"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color("AppInk").opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func kvRow(_ label: String, value: String, valueColor: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color("AppInk"))
            Spacer()
            Text(value)
                .font(bold ? .subheadline.weight(.bold) : .subheadline.weight(.medium))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color("AppInk").opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private var noDataLabel: some View {
        Text("データなし")
            .font(.caption)
            .foregroundStyle(Color("AppInk").opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    // MARK: Formatters

    private func formatMMDD(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd"
        return fmt.string(from: date)
    }

    private func formatK(_ v: Double) -> String {
        if v == 0 { return "0" }
        let abs = Swift.abs(v)
        let sign = v >= 0 ? "+" : "-"
        if abs >= 1000 {
            return "\(sign)\(Int((abs / 1000).rounded()))k"
        } else {
            return "\(v >= 0 ? "+" : "")\(Int(v))"
        }
    }
}

// MARK: - Preview

#Preview {
    AnalysisView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
        .environment(FilterState())
}
