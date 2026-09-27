import XCTest

@MainActor
final class AppearanceAccessibilityUITests: XCTestCase {
    func testAppearancePersistsAndLargeTextWorkoutCanLog() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        app.buttons["Settings"].tap()
        let appearance = app.buttons["settings-appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 3))
        appearance.tap()
        app.buttons["Dark"].tap()
        app.buttons["settings-gym-appearance"].tap()
        app.buttons["Light"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        app.buttons["Settings"].tap()
        reveal(appearance, in: app)
        XCTAssertTrue(appearance.label.contains("Dark") || (appearance.value as? String) == "Dark")
        let gym = app.buttons["settings-gym-appearance"]
        reveal(gym, in: app)
        XCTAssertTrue(gym.label.contains("Light") || (gym.value as? String) == "Light")
        capture(app, named: "Dark planning settings with accessibility text")
        app.buttons["Done"].tap()
        let start = app.buttons["Start workout"]
        reveal(start, in: app)
        start.tap()
        let log = app.buttons["Log set"]
        XCTAssertTrue(log.waitForExistence(timeout: 3))
        reveal(log, in: app)
        capture(app, named: "Light gym with accessibility text and reachable log action")
        log.tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
