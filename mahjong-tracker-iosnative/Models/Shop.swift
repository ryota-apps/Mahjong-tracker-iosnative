import Foundation
import SwiftData

@Model
final class Shop {
    @Attribute(.unique) var id: UUID
    var name: String
    var players: Int
    var format: String
    var rule: Int
    var chipUnit: Int
    var chipNote: String
    var gameFee: Int
    var topPrize: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        players: Int = 4,
        format: String = "東南戦",
        rule: Int = 0,
        chipUnit: Int = 0,
        chipNote: String = "",
        gameFee: Int = 0,
        topPrize: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.players = players
        self.format = format
        self.rule = rule
        self.chipUnit = chipUnit
        self.chipNote = chipNote
        self.gameFee = gameFee
        self.topPrize = topPrize
        self.createdAt = createdAt
    }
}
