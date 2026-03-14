import Testing
import SwiftData
@testable import mahjong_tracker_iosnative

// MARK: - Session model tests

@Suite("Session Model Tests")
struct SessionTests {

    // MARK: totalGames

    @Test("totalGames は count1〜count4 の合計を返す")
    func totalGamesSum() throws {
        let session = Session(count1: 3, count2: 5, count3: 2, count4: 1)
        #expect(session.totalGames == 11)
    }

    @Test("totalGames: すべて0のとき0を返す")
    func totalGamesAllZero() throws {
        let session = Session(count1: 0, count2: 0, count3: 0, count4: 0)
        #expect(session.totalGames == 0)
    }

    @Test("totalGames: 3人打ちでcount4=0でも正しい合計")
    func totalGamesThreePlayers() throws {
        let session = Session(players: 3, count1: 4, count2: 3, count3: 2, count4: 0)
        #expect(session.totalGames == 9)
    }

    // MARK: net 計算（フリー）

    @Test("フリー: net = balance + chipVal")
    func freeNetWithChip() throws {
        let session = Session(
            gameType: "free",
            balance: 5000,
            chipVal: 2000,
            net: 7000
        )
        #expect(session.net == session.balance + session.chipVal)
    }

    @Test("フリー: チップなし net = balance")
    func freeNetNoChip() throws {
        let session = Session(
            gameType: "free",
            balance: -3000,
            chips: 0,
            chipUnit: 0,
            chipVal: 0,
            net: -3000
        )
        #expect(session.net == session.balance)
    }

    @Test("フリー: マイナス収支")
    func freeNetNegative() throws {
        let session = Session(
            gameType: "free",
            balance: -8000,
            chipVal: 1500,
            net: -6500
        )
        #expect(session.net == -6500)
    }

    // MARK: net 計算（セット）

    @Test("セット: net = balance + chipVal - venueFee")
    func setNetWithVenueFee() throws {
        let session = Session(
            gameType: "set",
            balance: 10000,
            chipVal: 3000,
            venueFee: 2000,
            net: 11000
        )
        #expect(session.net == session.balance + session.chipVal - session.venueFee)
    }

    @Test("セット: 場代のみで収支マイナス")
    func setNetOnlyVenueFee() throws {
        let session = Session(
            gameType: "set",
            balance: 0,
            chipVal: 0,
            venueFee: 1500,
            net: -1500
        )
        #expect(session.net == -1500)
    }
}

// MARK: - getNet function tests

@Suite("getNet Function Tests")
struct GetNetTests {

    @Test("withFees: true → session.net をそのまま返す")
    func withFeesTrue() throws {
        let session = Session(
            gameType: "free",
            balance: 5000,
            chipVal: 1000,
            net: 6000,
            gameFee: 200,
            topPrize: 500
        )
        #expect(getNet(session, withFees: true) == 6000)
    }

    @Test("withFees: false, フリー, gameFee/topPrize=0 → net をそのまま返す")
    func withFeesFalseNoFees() throws {
        let session = Session(
            gameType: "free",
            balance: 5000,
            chipVal: 1000,
            net: 6000,
            gameFee: 0,
            topPrize: 0
        )
        #expect(getNet(session, withFees: false) == 6000)
    }

    @Test("withFees: false, フリー, ゲーム代あり → net + totalGames*gameFee + count1*topPrize")
    func withFeesFalseWithGameFee() throws {
        let session = Session(
            gameType: "free",
            count1: 3, count2: 2, count3: 1, count4: 0,
            net: -1000,
            gameFee: 100,
            topPrize: 300
        )
        // totalGames = 6, gameFee=100, topPrize=300, count1=3
        // expected = -1000 + 6*100 + 3*300 = -1000 + 600 + 900 = 500
        #expect(getNet(session, withFees: false) == 500)
    }

    @Test("withFees: false, セット → net + venueFee")
    func withFeesFalseSet() throws {
        let session = Session(
            gameType: "set",
            balance: 8000,
            chipVal: 2000,
            venueFee: 1500,
            net: 8500  // 8000 + 2000 - 1500
        )
        // fees除外: 8500 + 1500 = 10000
        #expect(getNet(session, withFees: false) == 10000)
    }

    @Test("getNet: ゼロ収支")
    func zeroNet() throws {
        let session = Session(gameType: "free", balance: 0, chipVal: 0, net: 0)
        #expect(getNet(session, withFees: true) == 0)
        #expect(getNet(session, withFees: false) == 0)
    }
}

// MARK: - signedYen function tests

@Suite("signedYen Function Tests")
struct SignedYenTests {

    @Test("正の値に + を付ける")
    func positiveValue() {
        #expect(signedYen(1000) == "+1000円")
    }

    @Test("負の値はそのまま - が付く")
    func negativeValue() {
        #expect(signedYen(-500) == "-500円")
    }

    @Test("ゼロは + を付ける")
    func zeroValue() {
        #expect(signedYen(0) == "+0円")
    }
}
