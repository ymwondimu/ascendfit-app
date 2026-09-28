# Ascend Fit workout interchange and private import API

The offline v0 accepts one versioned JSON format through paste or `.json` upload. The app validates the same [WorkoutPlan v1 schema](schema/workout-plan-v1.schema.json), previews it, and requires confirmation before saving to Today. No provider connection is needed.

Use [the ChatGPT prompt](examples/CHATGPT-WORKOUT-PROMPT.md) in your coaching conversation. Resolve missing mandatory data and alternative exercises before asking for the final file. The app determines a default workout name from the exercises during review; a user can enter a personal name before saving. Unspecified rest is null, not an invented recommendation.

Every field has the same spelling and type. Nullable fields must be present as null; unknown fields and future schema versions are rejected. Missing units, incompatible targets, duplicate IDs and invalid grouping cannot become runnable plans. Import review can explicitly keep an exact source exercise name as custom instead of forcing a library match. Source JSON is retained inside the saved local plan and included in exports. JSON interchange and archival history export are different formats.

## Local verification

```bash
npm test
npm run check
npm run evaluate
```

Evaluation checks three example contract fixtures and eight explicitly synthetic edge cases: missing units, two workouts, irrelevant/adversarial classification, fabricated source evidence, inconsistent grouping/tempo, and low confidence. The unit suite also verifies invalid requests never reach the provider and malformed provider output cannot become a workout. These are deterministic output-contract checks, not evidence that a live model rejects adversarial text or reaches the roadmap's 20 representative clear-workout gate. Broader approved examples and live-provider evaluation remain outstanding.

A multiple-workout envelope can contain valid plans, but still requires explicit client-side selection. `ready` describes complete, unblocked contract data; it does not authorize scheduling the first workout automatically.

## Optional server-side free-text interpretation

`GET /health` reports readiness. `POST /v1/imports/interpret` requires `Authorization: Bearer <IMPORT_ACCESS_TOKEN>` and `Content-Type: application/json`:

```json
{"schemaVersion":1,"text":"the workout text","sourceKind":"paste","sourceURL":null}
```

The response uses the same schema envelope with a separately attached `source` object. Original source text never appears in ordinary logs. Explicit source evidence is required for interpreted load units. Incomplete or uncertain fields return blocking issues instead of guessed runnable values.

Set `IMPORT_ACCESS_TOKEN`, `OPENAI_API_KEY`, and `OPENAI_MODEL` in the server environment; keys never belong in the iPhone app. No model is selected implicitly. Missing configuration produces an actionable error. The app now has a separate Workout text mode with explicit transmission consent, cancellation, retry and locally preserved source. Its private service client calls this endpoint only when configured; standard JSON review remains entirely offline. Returned source must match exactly and the schema is checked again on-device. Multiple-workout responses require selection. Blocking issues/uncertain confidence still prevent acceptance; clarify the source and convert again or obtain a definite JSON file.

No endpoint or token is bundled by default. For a DEBUG simulator build, launch the app with process environment `ASCEND_IMPORT_SERVICE_URL` and `ASCEND_IMPORT_ACCESS_TOKEN` (via matching `SIMCTL_CHILD_` variables when using simctl launch). HTTPS is required except explicit simulator loopback development. These values are a private service address/access token, never the provider API key. For signed private device builds, set the generated Info.plist `AscendImportServiceURL` and provision a Keychain generic-password item with service `com.ascendfit.import.access` and account `private-service`. The app reads this item; an account/token enrollment flow is not yet implemented. Keep service access secrets outside source control. Public authentication and deployment remain separate work.

The client uses an ephemeral session with no cache/cookie store, refuses redirects, caps responses and does not display raw server error bodies. UI tests inject deterministic transport only under `--ui-testing`; normal builds never use those fixtures. This implementation has not been enabled against a live provider or evaluated for model accuracy.

```bash
npm start
```

The private development server binds only to `127.0.0.1:8787` (override `PORT`). It has per-address rate limits, a process-local daily request budget, concurrency limits, request/body timeouts and output size limits. Limits reset when the process restarts and are not distributed production accounting. Deploying a public service requires durable auth/budget controls and HTTPS infrastructure. No service deployment or paid live provider calls have been performed.
