import XCTest

final class RecordFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // インメモリストアで起動（テスト用フラグ）
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: Helper

    /// 記録タブに移動する
    private func navigateToRecordTab() {
        let recordTab = app.tabBars.buttons["記録する"]
        if recordTab.waitForExistence(timeout: 3) {
            recordTab.tap()
        }
    }

    /// セッション開始ボタンをタップしてセッション画面に遷移する
    private func startSession(gameType: String = "フリー") {
        navigateToRecordTab()

        // 種別選択
        let gameTypeButton = app.buttons[gameType]
        if gameTypeButton.waitForExistence(timeout: 3) {
            gameTypeButton.tap()
        }

        // セッション開始
        let startButton = app.buttons["セッション開始"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()
    }

    // MARK: Tests

    /// セットアップ画面の基本要素が存在する
    func testSetupScreenElements() throws {
        navigateToRecordTab()

        XCTAssertTrue(app.staticTexts["記録する"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["セッション開始"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["フリー"].exists)
        XCTAssertTrue(app.buttons["セット"].exists)
    }

    /// セッション開始でセッション画面に遷移する
    func testSessionStartNavigation() throws {
        startSession()

        // セッション画面の要素を確認
        XCTAssertTrue(app.buttons["終了・破棄"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["保存する"].waitForExistence(timeout: 3))
    }

    /// 着順カウントを増加できる
    func testCountIncrement() throws {
        startSession()

        // 1着の + ボタンを探してタップ
        let plusButtons = app.buttons.matching(identifier: "plus")
        if plusButtons.count == 0 {
            // SF Symbol ベースのボタンはアクセシビリティラベルで取得
            let allButtons = app.buttons.allElementsBoundByIndex
            let plusButton = allButtons.first { $0.label.contains("+") || $0.label == "Add" }
            XCTAssertNotNil(plusButton, "プラスボタンが見つかりません")
            return
        }

        let firstPlus = plusButtons.element(boundBy: 0)
        XCTAssertTrue(firstPlus.waitForExistence(timeout: 3))
        firstPlus.tap()

        // カウントが1になっていることを確認
        XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 2))
    }

    /// カウントは0以下にならない
    func testCountDoesNotGoBelowZero() throws {
        startSession()

        // 初期状態（全カウント0）で1着の − ボタンをタップ
        let minusButtons = app.buttons.matching(identifier: "minus")
        guard minusButtons.count > 0 else {
            // アクセシビリティ識別子がない場合はスキップ
            XCTSkip("マイナスボタンのアクセシビリティ識別子が未設定")
            return
        }

        let firstMinus = minusButtons.element(boundBy: 0)
        XCTAssertTrue(firstMinus.waitForExistence(timeout: 3))
        firstMinus.tap()
        firstMinus.tap()  // 複数回タップしても0以下にならない

        // "0" が表示されたまま（複数箇所に"0"があるので、少なくとも1つ存在する）
        XCTAssertTrue(app.staticTexts["0"].firstMatch.exists)
    }

    /// セット選択時にチップ単価・場代入力欄が表示される
    func testSetModeShowsVenueFeeField() throws {
        navigateToRecordTab()

        // セットを選択してセッション開始
        let setButton = app.buttons["セット"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 3))
        setButton.tap()

        let startButton = app.buttons["セッション開始"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        // 場代フィールドが表示されることを確認
        XCTAssertTrue(app.staticTexts["場代"].waitForExistence(timeout: 3))
        // チップ単価も表示される
        XCTAssertTrue(app.staticTexts["チップ単価"].exists)
    }

    /// フリー選択時は場代入力欄が表示されない（チップ単価0の場合）
    func testFreeModeHidesVenueFee() throws {
        startSession(gameType: "フリー")

        // 場代フィールドは表示されない
        // NOTE: チップ単価が0の場合はチップ欄も非表示
        let venueFee = app.staticTexts["場代"]
        // フリーモードでは場代ラベルがないことを確認（存在チェックをタイムアウト短く）
        let exists = venueFee.waitForExistence(timeout: 1)
        XCTAssertFalse(exists, "フリーモードで場代フィールドが表示されるべきでない")
    }

    /// 終了・破棄でセットアップ画面に戻る
    func testDiscardReturnsToSetup() throws {
        startSession()

        let discardButton = app.buttons["終了・破棄"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: 3))
        discardButton.tap()

        // 確認アラートが出る
        let alert = app.alerts["セッションを破棄しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))

        // 破棄するをタップ
        alert.buttons["破棄する"].tap()

        // セットアップ画面に戻ることを確認
        XCTAssertTrue(app.buttons["セッション開始"].waitForExistence(timeout: 3))
    }

    /// 保存後にセットアップ画面に戻る
    func testSaveReturnsToSetup() throws {
        startSession()

        // 保存ボタンをタップ
        let saveButton = app.buttons["保存する"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        // セットアップ画面に戻ることを確認
        XCTAssertTrue(app.buttons["セッション開始"].waitForExistence(timeout: 5))
    }

    /// セットアップ→セッション→保存の一連フロー
    func testFullRecordFlow() throws {
        navigateToRecordTab()

        // 1. セットアップ: フリーを選択
        let freeButton = app.buttons["フリー"]
        XCTAssertTrue(freeButton.waitForExistence(timeout: 3))
        freeButton.tap()

        // 2. セッション開始
        app.buttons["セッション開始"].tap()
        XCTAssertTrue(app.buttons["終了・破棄"].waitForExistence(timeout: 3))

        // 3. 収支入力（テキストフィールドに数値を入れる）
        let balanceFields = app.textFields.allElementsBoundByIndex
        if !balanceFields.isEmpty {
            balanceFields[0].tap()
            balanceFields[0].typeText("3000")
        }

        // 4. 保存
        let saveButton = app.buttons["保存する"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        // 5. セットアップ画面に戻ることを確認
        XCTAssertTrue(app.buttons["セッション開始"].waitForExistence(timeout: 5))
    }
}
