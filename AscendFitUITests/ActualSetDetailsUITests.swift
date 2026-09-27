import XCTest

@MainActor
final class ActualSetDetailsUITests: XCTestCase {
    func testActualEffortAndNotesCanBeLoggedEditedAndRecoveredInHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.buttons["set-details"].waitForExistence(timeout: 3))
        app.buttons["set-details"].tap()
        XCTAssertTrue(app.segmentedControls["actual-effort-kind"].waitForExistence(timeout: 3))
        app.segmentedControls["actual-effort-kind"].buttons["RPE"].tap()
        let note = app.descendants(matching: .any).matching(identifier: "actual-set-notes").firstMatch
        note.tap()
        note.typeText("Left side felt tight.")
        app.buttons["Use for this set"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 3))
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()
        XCTAssertTrue(app.staticTexts["Set 2 of 3"].waitForExistence(timeout: 3))
        let completed = app.buttons["edit-completed-set-1"]
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        completed.tap()
        XCTAssertTrue(app.navigationBars["Edit completed set"].waitForExistence(timeout: 3))
        XCTAssertEqual(note.value as? String, "Left side felt tight.")
        XCTAssertTrue(app.segmentedControls["actual-effort-kind"].buttons["RPE"].isSelected)
        app.segmentedControls["actual-effort-kind"].buttons["RIR"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Editing actual effort and a verbatim completed-set note"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.buttons["active-workout-menu"].waitForExistence(timeout: 3))
        app.buttons["active-workout-menu"].tap()
        app.buttons["End workout"].tap()
        app.alerts.buttons["Finish and save"].tap()
        XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 3))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Lower A"].waitForExistence(timeout: 3))
        app.staticTexts["Lower A"].tap()
        XCTAssertTrue(app.staticTexts["Left side felt tight."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["8 RIR"].exists)
    }
}
