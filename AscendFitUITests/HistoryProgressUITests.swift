import XCTest

@MainActor
final class HistoryProgressUITests: XCTestCase {
    func testActivityDayFiltersHistoryAndExerciseVolumeShowsExactLowData() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-previous-performance"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Last 12 weeks"].waitForExistence(timeout: 3))
        let yesterday = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86_400))
        let day = app.buttons["history-day-\(yesterday.timeIntervalSince1970)"]
        XCTAssertTrue(day.waitForExistence(timeout: 3))
        day.tap()
        let clear = app.buttons["history-clear-date"]
        reveal(clear, in: app)
        XCTAssertTrue(clear.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Twelve-week history with selected day"
        attachment.lifetime = .keepAlways
        add(attachment)
        clear.tap()
        let progress = app.buttons["exercise-progress"]
        reveal(progress, in: app)
        progress.tap()
        XCTAssertTrue(app.staticTexts["Back Squat"].waitForExistence(timeout: 3))
        app.staticTexts["Back Squat"].tap()
        XCTAssertTrue(app.staticTexts["More history needed"].waitForExistence(timeout: 3))
        let summary = app.staticTexts["exercise-volume-summary"]
        reveal(summary, in: app)
        XCTAssertTrue(summary.label.contains("665 lb × reps"))
        XCTAssertTrue(summary.label.contains("1 workout"))
        let volume = XCTAttachment(screenshot: app.screenshot())
        volume.name = "Exact exercise volume with one workout"
        volume.lifetime = .keepAlways
        add(volume)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
