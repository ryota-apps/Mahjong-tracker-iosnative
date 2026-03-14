import Testing
import Foundation
@testable import mahjong_tracker_iosnative

// MARK: - ExportManager Tests

@Suite("ExportManager Tests")
struct ExportManagerTests {

    // MARK: JSON export

    @Test("JSONエクスポート: 正しくエンコードされる")
    func jsonExportEncodes() throws {
        let session = Session(
            shop: "テスト雀荘",
            date: Date(timeIntervalSince1970: 0),
            players: 4,
            format: "東南戦",
            rule: 5,
            gameType: "free",
            count1: 2, count2: 1, count3: 1, count4: 0,
            balance: 3000,
            chips: 10,
            chipUnit: 100,
            chipVal: 1000,
            net: 4000
        )
        let shop = Shop(name: "テスト雀荘", players: 4, format: "東南戦", rule: 5)

        let data = try ExportManager.makeJSONData(sessions: [session], shops: [shop])
        #expect(!data.isEmpty)

        // デコードして内容を確認
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportData.self, from: data)

        #expect(payload.sessions.count == 1)
        #expect(payload.shops.count == 1)
        #expect(payload.sessions[0].shop == "テスト雀荘")
        #expect(payload.sessions[0].balance == 3000)
        #expect(payload.sessions[0].net == 4000)
        #expect(payload.sessions[0].count1 == 2)
        #expect(payload.shops[0].name == "テスト雀荘")
        #expect(payload.shops[0].rule == 5)
    }

    @Test("JSONエクスポート: 空データでもエラーにならない")
    func jsonExportEmpty() throws {
        let data = try ExportManager.makeJSONData(sessions: [], shops: [])
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportData.self, from: data)
        #expect(payload.sessions.isEmpty)
        #expect(payload.shops.isEmpty)
    }

    @Test("JSONファイル名: 日付フォーマットが正しい")
    func jsonFileName() {
        let name = ExportManager.jsonFileName()
        #expect(name.hasPrefix("麻雀成績_バックアップ_"))
        #expect(name.hasSuffix(".json"))
        // yyyy-MM-dd 形式の日付部分を確認
        let dateStr = name
            .replacingOccurrences(of: "麻雀成績_バックアップ_", with: "")
            .replacingOccurrences(of: ".json", with: "")
        #expect(dateStr.count == 10) // "2026-03-15" = 10文字
        #expect(dateStr.contains("-"))
    }

    // MARK: CSV export

    @Test("CSVエクスポート: ヘッダー行が正しい")
    func csvHeader() throws {
        let data = ExportManager.makeCSVData(sessions: [])
        let str = String(data: data, encoding: .utf8) ?? ""
        // BOM除去
        let content = str.hasPrefix("\u{FEFF}") ? String(str.dropFirst()) : str
        let firstLine = content.components(separatedBy: "\n").first ?? ""
        #expect(firstLine == "日付,店舗名,人数,戦型,種別,レート,1着,2着,3着,4着,総ゲーム数,現金収支,チップ枚数,チップ収支,場代,純収支,メモ")
    }

    @Test("CSVエクスポート: BOM付きUTF-8")
    func csvBOM() {
        let data = ExportManager.makeCSVData(sessions: [])
        // BOM = 0xEF 0xBB 0xBF
        let bytes = [UInt8](data)
        #expect(bytes.count >= 3)
        #expect(bytes[0] == 0xEF)
        #expect(bytes[1] == 0xBB)
        #expect(bytes[2] == 0xBF)
    }

    @Test("CSVエクスポート: セッションが正しく出力される")
    func csvSessionRow() throws {
        let session = Session(
            shop: "雀荘A",
            date: Date(timeIntervalSince1970: 0),
            players: 4,
            format: "東南戦",
            rule: 10,
            gameType: "free",
            count1: 2, count2: 1, count3: 1, count4: 0,
            balance: 5000,
            chips: 5,
            chipUnit: 200,
            chipVal: 1000,
            venueFee: 0,
            net: 6000
        )
        let data = ExportManager.makeCSVData(sessions: [session])
        let str = String(data: data, encoding: .utf8) ?? ""
        let content = str.hasPrefix("\u{FEFF}") ? String(str.dropFirst()) : str
        let lines = content.components(separatedBy: "\n")

        // ヘッダー + 1データ行
        #expect(lines.count >= 2)
        let row = lines[1]
        #expect(row.contains("雀荘A"))
        #expect(row.contains("東南戦"))
        #expect(row.contains("フリー"))
        #expect(row.contains("5000"))  // balance
        #expect(row.contains("6000"))  // net
    }

    @Test("CSVファイル名: 日付フォーマットが正しい")
    func csvFileName() {
        let name = ExportManager.csvFileName()
        #expect(name.hasPrefix("麻雀成績_"))
        #expect(name.hasSuffix(".csv"))
    }

    // MARK: JSON import

    @Test("JSONインポート: 重複IDをスキップする")
    func importSkipsDuplicates() throws {
        let existingID = UUID()
        let existingSession = Session(id: existingID, shop: "既存")

        // エクスポートデータを作って同じIDのセッションを含める
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = ExportData(
            sessions: [
                SessionExport(
                    id: existingID, shop: "既存", date: Date(), players: 4,
                    format: "東南戦", rule: 0, gameType: "free",
                    count1: 0, count2: 0, count3: 0, count4: 0,
                    balance: 0, chips: 0, chipUnit: 0, chipVal: 0,
                    venueFee: 0, net: 0, gameFee: 0, topPrize: 0,
                    note: "", createdAt: Date()
                ),
                SessionExport(
                    id: UUID(), shop: "新規", date: Date(), players: 4,
                    format: "東南戦", rule: 0, gameType: "free",
                    count1: 1, count2: 0, count3: 0, count4: 0,
                    balance: 1000, chips: 0, chipUnit: 0, chipVal: 0,
                    venueFee: 0, net: 1000, gameFee: 0, topPrize: 0,
                    note: "", createdAt: Date()
                )
            ],
            shops: []
        )
        let data = try encoder.encode(payload)

        // 一時ファイルに書き出して importJSON を呼ぶ
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_import.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let (newSessions, _, result) = try ExportManager.importJSON(
            from: url,
            existingSessions: [existingSession],
            existingShops: []
        )

        // 重複IDはスキップされ、新規1件のみインポート
        #expect(newSessions.count == 1)
        #expect(newSessions[0].shop == "新規")
        #expect(result.sessionCount == 1)
        #expect(result.skippedSessions == 1)
    }

    @Test("JSONインポート: 重複なしで全件インポート")
    func importAllNew() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = ExportData(
            sessions: (1...3).map { i in
                SessionExport(
                    id: UUID(), shop: "店舗\(i)", date: Date(), players: 4,
                    format: "東南戦", rule: 0, gameType: "free",
                    count1: 0, count2: 0, count3: 0, count4: 0,
                    balance: 0, chips: 0, chipUnit: 0, chipVal: 0,
                    venueFee: 0, net: 0, gameFee: 0, topPrize: 0,
                    note: "", createdAt: Date()
                )
            },
            shops: []
        )
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_import_all.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let (newSessions, _, result) = try ExportManager.importJSON(
            from: url,
            existingSessions: [],
            existingShops: []
        )

        #expect(newSessions.count == 3)
        #expect(result.sessionCount == 3)
        #expect(result.skippedSessions == 0)
    }

    // MARK: Import message

    @Test("importMessage: セッションと店舗の両方あり")
    func importMessageBoth() {
        let result = ImportResult(sessionCount: 3, shopCount: 1, skippedSessions: 0, skippedShops: 0)
        let msg = ExportManager.importMessage(result)
        #expect(msg.contains("3件のセッション"))
        #expect(msg.contains("1件の店舗"))
    }

    @Test("importMessage: セッションのみ")
    func importMessageSessionOnly() {
        let result = ImportResult(sessionCount: 5, shopCount: 0, skippedSessions: 2, skippedShops: 0)
        let msg = ExportManager.importMessage(result)
        #expect(msg.contains("5件のセッション"))
    }

    @Test("importMessage: 新規なし（全スキップ）")
    func importMessageAllSkipped() {
        let result = ImportResult(sessionCount: 0, shopCount: 0, skippedSessions: 3, skippedShops: 1)
        let msg = ExportManager.importMessage(result)
        #expect(msg.contains("スキップ"))
    }
}
