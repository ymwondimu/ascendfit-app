import XCTest

@MainActor
final class AscendFitUITests: XCTestCase {
    func testSettingsPersistUnitsAndProfileForNewWorkouts() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        app.buttons["Settings"].tap()
        app.segmentedControls.buttons["kg / cm"].tap()
        app.buttons["settings-training-profile"].tap()
        let height = app.textFields["Height in cm"]
        XCTAssertTrue(height.waitForExistence(timeout: 2))
        height.tap()
        height.typeText("178")
        let weight = app.textFields["Body weight in kg"]
        weight.tap()
        weight.typeText("82")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.segmentedControls.buttons["lb / in"].waitForExistence(timeout: 2))
        app.segmentedControls.buttons["lb / in"].tap()
        app.buttons["settings-training-profile"].tap()
        XCTAssertTrue(app.textFields["Height in in"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["Height in in"].value as? String, "70.1")
        XCTAssertEqual(app.textFields["Body weight in lb"].value as? String, "180.8")
        app.buttons["Not now"].tap()
        app.segmentedControls.buttons["kg / cm"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["kg / cm"].isSelected)
        app.buttons["settings-training-profile"].tap()
        XCTAssertTrue(app.textFields["Height in cm"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["Height in cm"].value as? String, "178")
        XCTAssertEqual(app.textFields["Body weight in kg"].value as? String, "82")
        app.buttons["Not now"].tap()
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Settings with saved training profile"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons["Done"].tap()
        app.buttons["Build manually"].tap()
        app.buttons["add-first-exercise"].tap()
        app.buttons["exercise-1"].tap()
        app.buttons["Done"].tap()
        app.buttons["builder-exercise-1"].tap()
        XCTAssertTrue(app.staticTexts["WEIGHT KG"].waitForExistence(timeout: 2))
    }

    func testFirstLaunchCollectsTheTrainingProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-onboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Set your baseline."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sex"].exists)
        XCTAssertTrue(app.textFields["Height, in"].exists)
        XCTAssertTrue(app.textFields["Body weight, lb"].exists)
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
    }

    func testTodayPresentsPrimaryActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your next session starts here."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Import workout"].exists)
        XCTAssertTrue(app.buttons["Build manually"].exists)
    }

    func testManualWorkoutCanBeScheduled() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()

        app.buttons["Build manually"].tap()

        let addExerciseButton = app.buttons["add-first-exercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Weight unit"].exists)
        addExerciseButton.tap()

        let backSquat = app.buttons["exercise-1"]
        XCTAssertTrue(backSquat.waitForExistence(timeout: 2))
        backSquat.tap()
        app.buttons["Done"].tap()

        let exerciseSummary = app.buttons["builder-exercise-1"]
        XCTAssertTrue(exerciseSummary.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["builder-exercise-summary-1"].exists)
        exerciseSummary.tap()

        XCTAssertTrue(app.textFields["Set 1 reps"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["WEIGHT LB"].exists)
        app.navigationBars["Back Squat"].buttons.element(boundBy: 0).tap()

        app.buttons["Save workout"].tap()

        XCTAssertTrue(app.staticTexts["Today's Workout"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Back Squat"].exists)
        XCTAssertTrue(app.staticTexts["today-exercise-summary-Back Squat"].exists)
        XCTAssertTrue(app.buttons["Start workout"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Back Squat"].exists)
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 3))
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()
        XCTAssertTrue(app.staticTexts["Set 2 of 3"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1 of 3 complete"].exists)
    }

    func testLoggingSetShowsRestThenAdvances() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan", "--ui-testing-previous-performance"]
        app.launch()

        let startButton = app.buttons["Start workout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        let logButton = app.buttons["Log set"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        let previous = app.staticTexts["previous-set-performance"]
        XCTAssertTrue(previous.waitForExistence(timeout: 3))
        XCTAssertTrue(previous.label.contains("95 lb × 7"))
        XCTAssertTrue(app.staticTexts["exercise-cues"].label.contains("Brace your trunk"))
        app.buttons["exercise-rest-default"].tap()
        XCTAssertTrue(app.buttons["Rest 120 seconds"].waitForExistence(timeout: 2))
        app.buttons["Rest 120 seconds"].tap()
        app.buttons["Save rest time"].tap()
        XCTAssertTrue(app.buttons["exercise-rest-default"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["exercise-rest-default"].label.contains("120 sec"))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Active workout with previous performance"
        capture.lifetime = .keepAlways
        add(capture)
        logButton.tap()

        let skipRestButton = app.buttons["Skip rest"]
        XCTAssertTrue(skipRestButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["shorten-rest"].exists)
        XCTAssertTrue(app.buttons["extend-rest"].exists)
        app.buttons["extend-rest"].tap()
        skipRestButton.tap()

        XCTAssertTrue(app.staticTexts["Set 2 of 3"].waitForExistence(timeout: 3))
        XCTAssertFalse(previous.exists)
        XCTAssertTrue(app.buttons["exercise-rest-default"].label.contains("120 sec"))
        XCTAssertTrue(app.staticTexts["Exercise 1 of 2"].exists)
        XCTAssertTrue(app.staticTexts["1 of 3 complete"].exists)
    }

    func testEverySetCanBeReachedWithLogActionPinned() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan"]
        app.launch()
        app.buttons["Start workout"].tap()

        let thirdSet = app.staticTexts["3"]
        for _ in 0..<5 where !thirdSet.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(thirdSet.isHittable)
        XCTAssertTrue(app.buttons["Log set"].isHittable)
    }

    func testGymControlsEditAddDeleteShowInfoPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed-plan"]
        app.launch()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()

        XCTAssertTrue(app.textFields["edit-set-load"].waitForExistence(timeout: 3))
        app.buttons["increase-set-load"].tap()
        XCTAssertTrue(app.staticTexts["105 lb × 8"].waitForExistence(timeout: 2))

        app.buttons["add-set"].tap()
        XCTAssertTrue(app.staticTexts["Set 1 of 4"].waitForExistence(timeout: 2))

        let currentRow = app.buttons["set-details"]
        for _ in 0..<4 where !currentRow.isHittable { app.swipeUp() }
        currentRow.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Set 1 of 3"].waitForExistence(timeout: 2))

        app.buttons["exercise-info"].tap()
        XCTAssertTrue(app.staticTexts["A barbell squat performed with the bar supported across the upper back."].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()

        app.buttons["active-workout-menu"].tap()
        app.buttons["Pause workout"].tap()
        XCTAssertTrue(app.staticTexts["Workout paused"].waitForExistence(timeout: 2))
        app.buttons["Resume workout"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 2))

        app.buttons["decrease-set-reps"].tap()
        XCTAssertTrue(app.staticTexts["105 lb × 7"].waitForExistence(timeout: 2))
        app.buttons["Log set"].tap()
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 3))
        app.buttons["Skip rest"].tap()
        XCTAssertTrue(app.staticTexts["105 lb × 7"].waitForExistence(timeout: 3))
    }

    func testInterruptedFinishCanRecoverAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-interrupted-finish"]
        app.launchEnvironment["ASCEND_FIT_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.staticTexts["Finish saving your workout"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Finish saving your workout"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Log set"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Recovered workout completion"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons["Finish workout"].tap()
        XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Lower A"].waitForExistence(timeout: 3))
        app.staticTexts["Lower A"].tap()
        XCTAssertTrue(app.staticTexts["100 lb × 8"].waitForExistence(timeout: 3))
    }

    func testCompletedWorkoutAppearsInHistoryWithCoachSummary() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-completion-plan"]
        app.launch()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 3))
        app.buttons["Log set"].tap()

        XCTAssertTrue(app.staticTexts["How many more reps could you have done?"].waitForExistence(timeout: 3))
        app.buttons["Four or more reps left"].tap()
        XCTAssertTrue(app.staticTexts["All sets logged"].waitForExistence(timeout: 3))
        app.buttons["Finish workout"].tap()
        XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["share-coach-update"].exists)
        app.buttons["Done"].tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Push Session"].waitForExistence(timeout: 3))
        app.staticTexts["Push Session"].tap()
        XCTAssertTrue(app.buttons["copy-coach-summary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["4+ reps left"].exists)
    }
}
