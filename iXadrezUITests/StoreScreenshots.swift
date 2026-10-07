import XCTest

/// Generates the App Store screenshots by driving the real app. Skipped in normal test runs;
/// enable with `TEST_RUNNER_STORE_SHOTS=1 xcodebuild test -only-testing:iXadrezUITests ...` and
/// export the attachments from the .xcresult bundle.
final class StoreScreenshots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] == "1", "Set STORE_SHOTS=1 to generate store screenshots")
    }

    func testPortuguese() { captureAll(lang: "pt") }
    func testEnglish() { captureAll(lang: "en") }

    private func captureAll(lang: String) {
        // 1. Menu
        var app = launch(lang: lang)
        shot(app, "\(lang)-1-menu")

        // 2. A game against the bot, with a piece selected to show its legal moves
        app.buttons["mode-bot"].tap()
        app.buttons["level-medium"].tap()
        let board = app.otherElements["chess-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        for (from, to) in [("e2", "e4"), ("d2", "d4"), ("g1", "f3")] {
            tap(board, from); tap(board, to)
            sleep(3) // the bot always "thinks" for a moment
        }
        tap(board, "f1")
        shot(app, "\(lang)-2-game")

        // 3. Tutorial, with the knight's moves highlighted
        app = launch(lang: lang)
        app.buttons["mode-tutorial"].tap()
        let lessonBoard = app.otherElements["chess-board"]
        XCTAssertTrue(lessonBoard.waitForExistence(timeout: 5))
        tap(lessonBoard, "d4")
        shot(app, "\(lang)-3-tutorial")

        // 4. Multiplayer lobby
        app = launch(lang: lang)
        app.buttons["mode-multiplayer"].tap()
        let name = app.textFields["mp-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText((lang == "pt" ? "Vidi" : "Alex") + "\n") // return dismisses the keyboard
        shot(app, "\(lang)-4-multiplayer")

        // 5. Help
        app = launch(lang: lang)
        app.buttons["mode-help"].tap()
        sleep(1)
        shot(app, "\(lang)-5-help")
    }

    private func launch(lang: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["-xadrez-lang", lang, "-playerName", ""]
        app.launch()
        let skip = app.buttons["intro-skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        XCTAssertTrue(app.buttons["mode-bot"].waitForExistence(timeout: 5))
        return app
    }

    /// Taps a square ("e2") on a board shown from White's side.
    private func tap(_ board: XCUIElement, _ square: String) {
        let chars = Array(square)
        let col = Double(Array("abcdefgh").firstIndex(of: chars[0])!)
        let row = Double(8 - Int(String(chars[1]))!)
        board.coordinate(withNormalizedOffset: CGVector(dx: (col + 0.5) / 8, dy: (row + 0.5) / 8)).tap()
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
