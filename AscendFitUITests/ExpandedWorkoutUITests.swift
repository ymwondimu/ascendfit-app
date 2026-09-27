import XCTest

@MainActor
final class ExpandedWorkoutUITests: XCTestCase {
    func testReplacementKeepsOriginalRecordedExerciseInHistory() {
        let app = isolatedApp(arguments: ["--ui-testing", "--ui-testing-seed-plan"])
        app.launch()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 3))
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()

        app.buttons["active-workout-menu"].tap()
        app.buttons["Replace exercise"].tap()
        XCTAssertTrue(app.buttons["replace-exercise-2"].waitForExistence(timeout: 3))
        app.buttons["replace-exercise-2"].tap()
        XCTAssertTrue(app.staticTexts["Front Squat"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Back Squat"].exists, "The completed ledger row retains its original movement")
        app.buttons["increase-set-load"].tap()
        XCTAssertTrue(app.staticTexts["105 lb × 8"].waitForExistence(timeout: 2))
        capture(app, named: "Replacement preserves the original completed set")
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["active-workout-menu"].tap()
        app.buttons["End workout"].tap()
        app.alerts.buttons["Finish and save"].tap()
        XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        // Reopen the store so this checks persisted identity, not only in-memory rows.
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 3))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Lower A"].waitForExistence(timeout: 3))
        app.staticTexts["Lower A"].tap()
        let original = app.cells.containing(.staticText, identifier: "100 lb × 8").firstMatch
        XCTAssertTrue(original.waitForExistence(timeout: 3))
        XCTAssertTrue(original.staticTexts["Back Squat"].exists)
        let replacement = app.cells.containing(.staticText, identifier: "105 lb × 8").firstMatch
        reveal(replacement, in: app)
        XCTAssertTrue(replacement.staticTexts["Front Squat"].exists)
        capture(app, named: "History preserves original and replacement movement results")
    }

    func testManualSupersetAlternatesMovementsAndRestoresNextRound() {
        let app = isolatedApp(arguments: ["--ui-testing"])
        app.launch()
        XCTAssertTrue(app.buttons["Build manually"].waitForExistence(timeout: 3))
        app.buttons["Build manually"].tap()
        app.buttons["add-first-exercise"].tap()
        XCTAssertTrue(app.buttons["exercise-1"].waitForExistence(timeout: 3))
        app.buttons["exercise-1"].tap()
        app.buttons["exercise-2"].tap()
        app.buttons["Done"].tap()

        let groupButton = app.buttons["Supersets & circuits"]
        // The pinned Save action covers partially visible rows even when XCTest
        // reports them hittable. Scroll the grouping row fully above it.
        for _ in 0..<4 where groupButton.frame.maxY > app.buttons["Save workout"].frame.minY {
            app.swipeUp()
        }
        reveal(groupButton, in: app)
        groupButton.tap()
        XCTAssertTrue(app.buttons["Back Squat"].waitForExistence(timeout: 3))
        app.buttons["Back Squat"].tap()
        app.buttons["Front Squat"].tap()
        app.buttons["Group selected exercises"].tap()
        app.buttons["Save workout"].tap()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()

        XCTAssertTrue(app.staticTexts["active-group-round"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["active-group-round"].label, "Superset · Round 1")
        XCTAssertTrue(app.staticTexts["Back Squat"].exists)
        XCTAssertTrue(app.staticTexts["Next: Front Squat"].exists)
        capture(app, named: "Manual superset first round")
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()
        XCTAssertTrue(app.staticTexts["Front Squat"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Set 1 of 3"].exists)
        XCTAssertFalse(app.staticTexts["Final exercise"].exists, "Grouped rounds return to earlier movements")
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()
        XCTAssertTrue(app.staticTexts["Back Squat"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["active-group-round"].label, "Superset · Round 2")
        XCTAssertTrue(app.staticTexts["Set 2 of 3"].exists)
        XCTAssertTrue(app.staticTexts["1 of 3 complete"].exists)
        capture(app, named: "Superset restored at the second round")
    }

    private func isolatedApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
