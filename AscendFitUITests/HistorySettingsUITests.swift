import XCTest

@MainActor
final class HistorySettingsUITests: XCTestCase {
    func testExportOptionsAndDeleteAllClearRetainedHistoryAndPreservePreferences() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-previous-performance"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Lower A"].waitForExistence(timeout: 3))
        app.buttons["exercise-progress"].tap()
        XCTAssertTrue(app.staticTexts["Back Squat"].waitForExistence(timeout: 3))
        app.staticTexts["Back Squat"].tap()
        XCTAssertTrue(app.staticTexts["More history needed"].waitForExistence(timeout: 3))
        reveal(app.staticTexts["95 lb × 7"], in: app)
        XCTAssertTrue(app.staticTexts["95 lb × 7"].exists)
        capture("Exercise progress with honest low-data state", in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Lower A"].tap()
        let actions = app.buttons["history-workout-actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 3))
        capture("History detail before export", in: app)
        actions.tap()
        XCTAssertTrue(app.buttons["export-workouts-json"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["export-workouts-csv"].exists)
        app.buttons["export-workouts-json"].tap()
        // A destination/action proves the system activity sheet is presented;
        // do not select one or send any workout data outside the app.
        let shareAction = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR label == %@ OR label == %@", "Save to Files", "Copy", "AirDrop"
        )).firstMatch
        XCTAssertTrue(shareAction.waitForExistence(timeout: 5))
        capture("JSON export system share sheet", in: app)
        // iOS 26 presents this as a popover without a Close button.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.25)).tap()
        XCTAssertTrue(actions.waitForExistence(timeout: 3))
        XCTAssertFalse(shareAction.exists)

        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["kg / cm"].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["kg / cm"].tap()
        let notifications = app.switches["settings-rest-notifications"]
        reveal(notifications, in: app)
        XCTAssertEqual(notifications.value as? String, "1")
        // SwiftUI exposes the whole labeled row as the switch; tap its control
        // at the trailing edge rather than the noninteractive label midpoint.
        notifications.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(notifications.value as? String, "0")
        capture("Settings notifications and appearance", in: app)

        let delete = app.buttons["settings-delete-workout-data"]
        reveal(delete, in: app)
        capture("Settings data ownership controls", in: app)
        delete.tap()
        XCTAssertTrue(app.buttons["Delete all workouts"].waitForExistence(timeout: 2))
        app.buttons["Delete all workouts"].tap()
        XCTAssertTrue(app.staticTexts["All local workout plans and history were deleted."].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["history-workout-actions"].exists)
        XCTAssertFalse(app.staticTexts["95 lb × 7"].exists)

        app.terminate()
        // Remove fixture flag: relaunch must inspect persisted deletion, not reseed.
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["kg / cm"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.segmentedControls.buttons["kg / cm"].isSelected)
        reveal(notifications, in: app)
        XCTAssertEqual(notifications.value as? String, "0")
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
