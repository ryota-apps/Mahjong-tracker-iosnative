import Foundation
import SwiftData

@Model
final class Session {
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

    var totalGames: Int {
        count1 + count2 + count3 + count4
    }

    init(
        id: UUID = UUID(),
        shop: String = "",
        date: Date = Date(),
        players: Int = 4,
        format: String = "東南戦",
        rule: Int = 0,
        gameType: String = "free",
        count1: Int = 0,
        count2: Int = 0,
        count3: Int = 0,
        count4: Int = 0,
        balance: Int = 0,
        chips: Int = 0,
        chipUnit: Int = 0,
        chipVal: Int = 0,
        venueFee: Int = 0,
        net: Int = 0,
        gameFee: Int = 0,
        topPrize: Int = 0,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shop = shop
        self.date = date
        self.players = players
        self.format = format
        self.rule = rule
        self.gameType = gameType
        self.count1 = count1
        self.count2 = count2
        self.count3 = count3
        self.count4 = count4
        self.balance = balance
        self.chips = chips
        self.chipUnit = chipUnit
        self.chipVal = chipVal
        self.venueFee = venueFee
        self.net = net
        self.gameFee = gameFee
        self.topPrize = topPrize
        self.note = note
        self.createdAt = createdAt
    }
}
