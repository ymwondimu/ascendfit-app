import XCTest

@MainActor
final class WorkoutImportUITests: XCTestCase {
    func testJSONReviewRecoversAndBecomesAnOfflineWorkout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        app.buttons["Import a different workout"].tap()
        XCTAssertTrue(app.buttons["Format help"].waitForExistence(timeout: 3))
        app.buttons["Format help"].tap()
        XCTAssertTrue(app.buttons["Copy ChatGPT prompt"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        let source = app.textViews["import-source"]
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        source.tap()
        source.typeText(Self.workoutJSON)
        // Dismiss the keyboard by scrolling to the explicit review action.
        let review = app.buttons["import-review-json"]
        for _ in 0..<4 where !review.isHittable { app.swipeUp() }
        review.tap()
        XCTAssertTrue(app.navigationBars["Review workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 set · 145 lb × 8"].exists)
        capture("Standard JSON import preview", in: app)
        app.buttons["Close"].tap()
        app.terminate()
        app.launch()
        app.buttons["Import a different workout"].tap()
        XCTAssertTrue(app.navigationBars["Review workout"].waitForExistence(timeout: 3))
        let add = app.buttons["import-add-to-today"]
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.buttons["Replace with reviewed workout"].waitForExistence(timeout: 3))
        // iOS 26 renders this confirmation as a popover; tapping outside
        // cancels without selecting the replacement action.
        app.otherElements["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["Replace with reviewed workout"].exists)
        XCTAssertTrue(add.isEnabled)
        add.tap()
        app.buttons["Replace with reviewed workout"].tap()
        XCTAssertTrue(app.staticTexts["Lower Body"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.staticTexts["145 lb × 8"].waitForExistence(timeout: 3))
        app.buttons["Log set"].tap()
        if app.buttons["Skip for now"].waitForExistence(timeout: 2) {
            app.buttons["Skip for now"].tap()
        }
        XCTAssertTrue(app.staticTexts["All sets logged"].waitForExistence(timeout: 3))
        app.buttons["Finish workout"].tap()
        XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.tabBars.buttons["History"].tap()
        app.staticTexts["Lower Body"].tap()
        XCTAssertTrue(app.buttons["copy-coach-summary"].waitForExistence(timeout: 3))
        capture("Imported workout saved in History", in: app)
    }

    func testShareExtensionCapturesTextFromTheSystemShareSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-share-host"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["ASCEND_FIT_UI_TEST_SHARED_TEXT"] = Self.workoutJSON
        app.launch()
        app.buttons["Share fixture"].tap()
        let extensionCell = app.cells["Ascend Fit"]
        XCTAssertTrue(extensionCell.waitForExistence(timeout: 5))
        extensionCell.tap()
        let save = app.buttons["shareSaveForReview"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        capture("Offline Share Extension capture", in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved for review"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Review shared workout"].waitForExistence(timeout: 5))
        app.buttons["Review shared workout"].tap()
        XCTAssertTrue(app.textViews["import-source"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["import-source"].value as? String, Self.workoutJSON)
    }

    func testSharedWorkoutIsCapturedOfflineAndRestoredWithoutRepeatingTheHandoff() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["ASCEND_FIT_UI_TEST_SHARED_TEXT"] = Self.workoutJSON
        app.launch()
        XCTAssertTrue(app.buttons["Review shared workout"].waitForExistence(timeout: 5))
        app.buttons["Review shared workout"].tap()
        XCTAssertTrue(app.textViews["import-source"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textViews["import-source"].value as? String, Self.workoutJSON)
        app.buttons["import-review-json"].tap()
        XCTAssertTrue(app.navigationBars["Review workout"].waitForExistence(timeout: 5))
        capture("Shared workout review", in: app)
        app.buttons["Close"].tap()
        XCTAssertFalse(app.buttons["Review shared workout"].exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ASCEND_FIT_UI_TEST_SHARED_TEXT")
        app.launch()
        XCTAssertFalse(app.buttons["Review shared workout"].exists)
        app.buttons["Import workout"].tap()
        XCTAssertTrue(app.navigationBars["Review workout"].waitForExistence(timeout: 5))
        let add = app.buttons["import-add-to-today"]
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        add.tap()
        XCTAssertTrue(app.staticTexts["Lower Body"].waitForExistence(timeout: 5))
    }

    func testDeletingLocalDataAlsoClearsAnUnacceptedImportDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        app.buttons["Import workout"].tap()
        let source = app.textViews["import-source"]
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        source.tap()
        source.typeText("{\"schemaVersion\":2}")
        let review = app.buttons["import-review-json"]
        for _ in 0..<4 where !review.isHittable { app.swipeUp() }
        review.tap()
        XCTAssertTrue(app.staticTexts["Workout format version 2 is not supported. Ask for schemaVersion 1."].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
        app.buttons["Settings"].tap()
        let delete = app.buttons["settings-delete-workout-data"]
        for _ in 0..<6 where !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.buttons["Delete all workouts"].tap()
        XCTAssertTrue(app.staticTexts["All local workout plans and history were deleted."].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.buttons["Import workout"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        XCTAssertEqual(source.value as? String, "")
    }

    func testTextConversionRequiresConsentAndReviewSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["ASCEND_FIT_UI_TEST_INTERPRETATION"] = Self.workoutJSON
        app.launch()
        app.buttons["Import workout"].tap()
        app.buttons["Workout text"].tap()
        let source = app.textViews["import-source"]
        source.tap(); source.typeText("Back squat: 145 lb x 8 x 1")
        let convert = app.buttons["import-review-json"]
        convert.tap()
        XCTAssertTrue(app.buttons["Send text and convert"].waitForExistence(timeout: 3))
        app.otherElements["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        XCTAssertFalse(app.navigationBars["Review workout"].exists)
        convert.tap(); app.buttons["Send text and convert"].tap()
        XCTAssertTrue(app.navigationBars["Review workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 set · 145 lb × 8"].exists)
        capture("Converted text review preserves source", in: app)
        app.buttons["Close"].tap(); app.terminate(); app.launch()
        app.buttons["Import workout"].tap()
        XCTAssertTrue(app.navigationBars["Review workout"].waitForExistence(timeout: 3))
        let add = app.buttons["import-add-to-today"]
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        add.tap()
        XCTAssertTrue(app.staticTexts["Lower Body"].waitForExistence(timeout: 3))
    }

    func testCancelledConversionKeepsTextAndDoesNotResumeOnReopen() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["ASCEND_FIT_UI_TEST_INTERPRETATION"] = Self.workoutJSON
        app.launchEnvironment["ASCEND_FIT_UI_TEST_CONVERSION_DELAY"] = "yes"
        app.launch()
        app.buttons["Import workout"].tap(); app.buttons["Workout text"].tap()
        let source = app.textViews["import-source"]
        source.tap(); source.typeText("Back squat: 145 lb x 8 x 1")
        app.buttons["import-review-json"].tap(); app.buttons["Send text and convert"].tap()
        XCTAssertTrue(app.buttons["Cancel conversion"].waitForExistence(timeout: 3))
        app.buttons["Cancel conversion"].tap()
        XCTAssertTrue(app.buttons["import-review-json"].isEnabled)
        app.buttons["Close"].tap(); app.terminate(); app.launch()
        app.buttons["Import workout"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        XCTAssertEqual(source.value as? String, "Back squat: 145 lb x 8 x 1")
        XCTAssertFalse(app.navigationBars["Review workout"].exists)
        capture("Canceled conversion retains local text", in: app)
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static let workoutJSON = #"{"schemaVersion":1,"classification":"single","workouts":[{"id":"11111111-1111-4111-8111-111111111111","title":"Imported Strength","notes":"Stop if discomfort returns.","exercises":[{"id":"22222222-2222-4222-8222-222222222222","name":"Back Squat","equipment":null,"notes":null,"group":null,"sets":[{"id":"33333333-3333-4333-8333-333333333333","kind":"weighted","role":"working","side":"bilateral","reps":{"min":8,"max":8},"load":{"amount":145,"unit":"lb"},"durationSeconds":null,"distance":null,"effort":null,"tempo":null,"restSeconds":0}]}]}],"issues":[],"confidence":[]}"#
}
