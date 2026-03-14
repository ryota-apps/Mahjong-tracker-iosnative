import Foundation

// MARK: - Export data structures

struct SessionExport: Codable {
    var id: UUID
    var shop: String
    var date: Date
    var players: Int
    var format: String
    var rule: Int
    var gameType: String
    var count1: Int
    var count2: Int
    var count3: Int
    var count4: Int
    var balance: Int
    var chips: Int
    var chipUnit: Int
    var chipVal: Int
    var venueFee: Int
    var net: Int
    var gameFee: Int
    var topPrize: Int
    var note: String
    var createdAt: Date
}

struct ShopExport: Codable {
    var id: UUID
    var name: String
    var players: Int
    var format: String
    var rule: Int
    var chipUnit: Int
    var chipNote: String
    var gameFee: Int
    var topPrize: Int
}

struct ExportData: Codable {
    let sessions: [SessionExport]
    let shops: [ShopExport]
}

// MARK: - Import result

struct ImportResult {
    let sessionCount: Int
    let shopCount: Int
    let skippedSessions: Int
    let skippedShops: Int
}

// MARK: - ExportManager

enum ExportManager {

    // MARK: JSON export

    static func makeJSONData(sessions: [Session], shops: [Shop]) throws -> Data {
        let sessionExports = sessions.map { s in
            SessionExport(
                id: s.id, shop: s.shop, date: s.date, players: s.players,
                format: s.format, rule: s.rule, gameType: s.gameType,
                count1: s.count1, count2: s.count2, count3: s.count3, count4: s.count4,
                balance: s.balance, chips: s.chips, chipUnit: s.chipUnit,
                chipVal: s.chipVal, venueFee: s.venueFee, net: s.net,
                gameFee: s.gameFee, topPrize: s.topPrize, note: s.note,
                createdAt: s.createdAt
            )
        }
        let shopExports = shops.map { sh in
            ShopExport(
                id: sh.id, name: sh.name, players: sh.players,
                format: sh.format, rule: sh.rule, chipUnit: sh.chipUnit,
                chipNote: sh.chipNote, gameFee: sh.gameFee, topPrize: sh.topPrize
            )
        }
        let payload = ExportData(sessions: sessionExports, shops: shopExports)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func jsonFileName() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "麻雀成績_バックアップ_\(fmt.string(from: Date())).json"
    }

    // MARK: CSV export

    static func makeCSVData(sessions: [Session]) -> Data {
        var rows: [String] = []

        let header = "日付,店舗名,人数,戦型,種別,レート,1着,2着,3着,4着,総ゲーム数,現金収支,チップ枚数,チップ収支,場代,純収支,メモ"
        rows.append(header)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy/MM/dd"

        for s in sessions.sorted(by: { $0.date < $1.date }) {
            let gameTypeLabel = s.gameType == "free" ? "フリー" : "セット"
            let rateLabel = s.rule == 0 ? "未設定" : "\(s.rule)点"
            let note = s.note.replacingOccurrences(of: "\"", with: "\"\"")
            let noteCell = note.contains(",") || note.contains("\n") ? "\"\(note)\"" : note

            let row = [
                dateFmt.string(from: s.date),
                s.shop,
                "\(s.players)人",
                s.format,
                gameTypeLabel,
                rateLabel,
                "\(s.count1)",
                "\(s.count2)",
                "\(s.count3)",
                "\(s.count4)",
                "\(s.totalGames)",
                "\(s.balance)",
                "\(s.chips)",
                "\(s.chipVal)",
                "\(s.venueFee)",
                "\(s.net)",
                noteCell
            ].joined(separator: ",")
            rows.append(row)
        }

        let csvString = rows.joined(separator: "\n")
        // BOM付きUTF-8でExcelが文字化けしないようにする
        let bom = "\u{FEFF}"
        return (bom + csvString).data(using: .utf8) ?? Data()
    }

    static func csvFileName() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "麻雀成績_\(fmt.string(from: Date())).csv"
    }

    // MARK: JSON import

    static func importJSON(
        from url: URL,
        existingSessions: [Session],
        existingShops: [Shop]
    ) throws -> (newSessions: [SessionExport], newShops: [ShopExport], result: ImportResult) {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportData.self, from: data)

        let existingSessionIDs = Set(existingSessions.map(\.id))
        let existingShopIDs = Set(existingShops.map(\.id))

        let newSessions = payload.sessions.filter { !existingSessionIDs.contains($0.id) }
        let newShops = payload.shops.filter { !existingShopIDs.contains($0.id) }

        let result = ImportResult(
            sessionCount: newSessions.count,
            shopCount: newShops.count,
            skippedSessions: payload.sessions.count - newSessions.count,
            skippedShops: payload.shops.count - newShops.count
        )
        return (newSessions, newShops, result)
    }

    // MARK: Import result message

    static func importMessage(_ result: ImportResult) -> String {
        var parts: [String] = []
        if result.sessionCount > 0 { parts.append("\(result.sessionCount)件のセッション") }
        if result.shopCount > 0 { parts.append("\(result.shopCount)件の店舗") }

        if parts.isEmpty {
            return "新しいデータはありませんでした（\(result.skippedSessions + result.skippedShops)件スキップ）"
        }
        return "\(parts.joined(separator: "と"))をインポートしました"
    }
}
