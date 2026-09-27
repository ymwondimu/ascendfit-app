# Ascend Fit

Ascend Fit turns workouts from an existing AI coach into structured, editable plans and a focused, offline-first iPhone tracker.

## Import a workout now

1. In Today, open **Import workout → Format help → Copy ChatGPT prompt**.
2. Paste the prompt into your coaching chat and resolve missing units or alternative exercises there. Ask for one definite WorkoutPlan v1 JSON file.
3. Paste the JSON into Ascend Fit or choose its `.json` file. Review the visible targets, keep unmatched names as custom or select a library match, then **Add to Today**.
4. Start and train offline. Your source stays with the local workout.

The [confirmed Lower A file](Backend/examples/lower-a-ready.workout.json) is ready to try: pounds, 45 lb bar, and a five-minute bike warm-up. The [format prompt](Backend/examples/CHATGPT-WORKOUT-PROMPT.md) and [schema](Backend/schema/workout-plan-v1.schema.json) are reusable. This offline v0 needs no provider account or backend. You can also share workout text or a JSON file using **Add to Ascend Fit → Save for review**, then open Ascend Fit and tap **Review shared workout**. Shared JSON uses the same offline review. Plain text is captured safely but still needs conversion to the standard JSON; the new **Workout text** mode can convert it after explicit consent when a private import service is configured. Unconfigured builds keep JSON import available offline; live model evaluation and service setup remain outstanding. Shared conversation links may contain no workout, so the extension explains when copying is required. Pending shares expire after seven days. Signed device builds must provision the `group.com.ascendfit.app` App Group for both app and extension.

## Local development

Prerequisites:

- Xcode 26 or newer with an iOS simulator
- XcodeGen
- Node.js 22 or newer
- Python 3 only for previewing the supplied static design handoff

Common commands:

```bash
make generate       # Regenerate AscendFit.xcodeproj from project.yml
make check          # Check backend JavaScript syntax
make test-backend   # Run the small backend test suite
make test-ios       # Run unit and UI smoke tests
make preview-design # Serve the design handoff at a stable localhost URL
```

The product contract is in [PROJECT.md](PROJECT.md), current progress is in [PLAN.md](PLAN.md), and the approved interface baseline is in [UI-SPEC.md](UI-SPEC.md). For a fresh development chat, start with [CONTINUATION.md](CONTINUATION.md).
