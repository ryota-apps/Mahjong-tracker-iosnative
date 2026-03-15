import Foundation

// MARK: - HistorySortOrder

enum HistorySortOrder: String, CaseIterable {
    case newFirst = "新しい順"
    case oldFirst = "古い順"
    case balanceHigh = "収支高い順"
    case balanceLow = "収支低い順"
}

// MARK: - DateRangePreset

enum DateRangePreset: String, CaseIterable {
    case all = "全期間"
    case thisMonth = "今月"
    case lastMonth = "先月"
    case threeMonths = "直近3ヶ月"
}

// MARK: - Net calculation

/// ゲーム代・場代を含むかどうかを考慮して純収支を返す
func getNet(_ session: Session, withFees: Bool) -> Int {
    let net = session.net
    if withFees { return net }
    if session.gameType == "set" {
        return net + session.venueFee
    }
    if session.gameFee == 0 && session.topPrize == 0 { return net }
    let total = session.totalGames
    return net + total * session.gameFee + session.count1 * session.topPrize
}

// MARK: - Formatting

func signedYen(_ value: Int) -> String {
    "\(value >= 0 ? "+" : "")\(value)円"
}

// MARK: - Date filter helper

func applyDateFilter(_ sessions: [Session], preset: DateRangePreset) -> [Session] {
    let cal = Calendar.current
    let now = Date()
    switch preset {
    case .thisMonth:
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        return sessions.filter { $0.date >= start }
    case .lastMonth:
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
        return sessions.filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
    case .threeMonths:
        let start = cal.date(byAdding: .month, value: -3, to: now)!
        return sessions.filter { $0.date >= start }
    case .all:
        return sessions
    }
}
