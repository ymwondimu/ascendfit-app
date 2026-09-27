import XCTest

@MainActor
final class WorkoutNavigationUITests: XCTestCase {
    func testSelectedLaterSetRestoresAndReturnsToRemainingOrder() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.buttons["active-workout-menu"].waitForExistence(timeout: 3))
        app.buttons["active-workout-menu"].tap()
        app.buttons["Workout overview"].tap()
        let bench = app.buttons["overview-set-1-1"]
        XCTAssertTrue(bench.waitForExistence(timeout: 3))
        for _ in 0..<4 where !bench.isHittable { app.swipeUp() }
        bench.tap()
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Set 1 of 2"].exists)
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()
        XCTAssertTrue(app.staticTexts["Back Squat"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Set 1 of 3"].exists)
        app.buttons["active-workout-menu"].tap()
        app.buttons["Workout overview"].tap()
        XCTAssertFalse(app.buttons["overview-set-1-1"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Workout overview retains completed and pending sets"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
