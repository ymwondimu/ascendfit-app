# Ascend Fit

Ascend Fit turns a workout from your existing coach into an editable plan and a focused iPhone tracker. You can also build a workout yourself. Planned and active workouts stay on your phone, so you can train without a network connection.

## Use the app

1. Set your training profile on first launch. You can change your preferred units and profile later in Settings.
2. On Today, choose **Import workout** or **Build manually**. For an import, paste a standard Ascend Fit workout JSON file or choose a `.json` file. **Format help → Copy ChatGPT prompt** gives your coach the exact format to return. You can also share workout text or JSON to Ascend Fit for later review. Plain text conversion requires a separately configured private service and your explicit consent.
3. Review the exercises, targets, and any unresolved details before adding an import to Today. Imported workouts receive a name based on their exercises: **Upper Body**, **Lower Body**, or **Full Body**. You can edit the name in review. Manually built workouts have an editable name before saving.
4. Start the saved workout from Today. Log sets, adjust targets, add or remove sets, change the rest between sets, pause, and resume. The active session and rest timer recover after you leave the app.
5. Finish to see your results. History shows past workouts and progress; you can share a coach-ready summary or export your data from Settings.

The [WorkoutPlan v1 schema](Backend/schema/workout-plan-v1.schema.json) defines the repeatable import format. JSON paste and file import work offline without a provider account. The [ChatGPT format prompt](Backend/examples/CHATGPT-WORKOUT-PROMPT.md) is included in the app. Imported source text stays with the local workout. A configured private service can convert plain text, but live provider evaluation and service setup remain separate work.

## Local development

Prerequisites: Xcode 26.3 with an iOS simulator, XcodeGen, and Node.js 22 or newer.

```bash
make generate       # Regenerate the Xcode project
make check          # Check backend JavaScript syntax
make test-backend   # Run backend tests
make test-ios       # Run iOS tests
```

See [PROJECT.md](PROJECT.md) for product goals, [PLAN.md](PLAN.md) for current status, [UI-SPEC.md](UI-SPEC.md) for the approved interface direction, and [CONTINUATION.md](CONTINUATION.md) for the implementation handoff. Private import-service configuration is documented in [Backend/README.md](Backend/README.md).
