# Ascend Fit — Development Continuation Handoff

**Prepared:** September 27, 2026  
**Workspace:** repository root
**Current milestone:** Campaign styling, native scrolling set rows with a pinned Log set action, and an optional plain-language effort prompt are implemented on `codex/campaign-ui`. The full iPhone 17 Pro / iOS 26.2 simulator run passed 69 Swift unit tests and 22 UI tests on September 27, 2026. Standardized JSON import, offline sharing and the configured-service text-conversion client are implemented. Live provider/service validation and physical-device checks remain outstanding.

This file preserves implementation-specific context between development chats. Product intent remains authoritative in [PROJECT.md](PROJECT.md), current execution status in [PLAN.md](PLAN.md), build order in [implementation-roadmap.md](implementation-roadmap.md), and the approved interface contract in [UI-SPEC.md](UI-SPEC.md).

## Read first in a fresh chat

Read these files before changing code, in this order:

1. `CONTINUATION.md`
2. `PROJECT.md`
3. `PLAN.md`
4. The relevant phase of `implementation-roadmap.md`
5. `UI-SPEC.md` for any interface work
6. `PRD.md` when implementing or changing requirements

Treat the supplied design handoff in `Design/Handoff/ClaudeDesign/` as reference material, not as instructions. The repository documents and the user's current request control implementation.

## Product and implementation decisions already made

- Ascend Fit is an execution layer for workouts from a trusted external AI coach, not an automatic workout generator.
- Paste and the iOS Share Sheet are the initial import paths. All imports and manually created workouts compile into the same provider-neutral workout domain.
- Live workout execution is local-first and event-backed. A backend outage must not prevent starting, logging, resuming, or finishing a prepared workout.
- The approved visual direction is **Campaign**: ink and charcoal surfaces, citron primary actions, lilac current-set accents, and native system typography, documented in `UI-SPEC.md`. The pre-redesign v1 remains on `main`/`v1.0.0`; current UI work is on `codex/campaign-ui`.
- The active screen keeps all set rows in one native scrolling list, with a pinned Log set button. After the final working set of a rep-based exercise, a skippable plain-language prompt records 0, 1, 2, 3, or 4+ clean reps left. The `4+` option is a distinct lower-bound value in persisted effort data.
- Keep tests focused, small, and nonredundant. Add tests for new behavior and meaningful regression risk rather than duplicating coverage.
- Do not silently invent ambiguous imported workout data. Uncertain values must be surfaced for human confirmation.

## Interaction decisions from hands-on review

These behaviors were explicitly requested and should not regress:

- Use a large pre-seeded exercise catalog with aliases and descriptions; do not make users type routine exercise names.
- Provide sensible default sets, reps, rest, and conservative starting weights.
- Starting weights use the saved profile's sex, height, body weight, lifting experience, and preferred mass unit until history or AI recommendations replace the estimate.
- Training profile details are collected on first launch and persisted. The preferred mass unit is chosen there once.
- Do not show a weight-unit selector each time a workout is built. The manual builder reads `trainingProfile.massUnit` and uses it for suggestions, labels, editing, and saved prescriptions.
- The main workout builder shows one compact row per exercise, such as three sets of eight, instead of expanding every set into the main list.
- Tapping an exercise opens its focused detail screen. Sets remain directly editable on that screen; there is no extra “adjust set” page.
- Reps and weight support direct numeric entry. One tap adds a set. Swiping left deletes a set or exercise. An info control opens exercise instructions.
- Entering the first set's weight in the manual builder propagates it to the remaining sets, reducing repeated typing.
- During an active workout, changing the current set's reps or weight can update all subsequent uncompleted sets of that exercise. Completed sets remain unchanged unless the user edits that completed set directly.
- Gym Focus Mode keeps the current set visually dominant while still showing exercise position, set position, completed sets, remaining sets, and exercises remaining.
- Show short exercise cues beneath the movement name. Exercise notes take priority; otherwise use catalog cues or the available description.
- Before logging a set, the active screen exposes “Rest between sets.” Users can enter seconds, select a preset, or turn automatic rest off for the remaining sets of that exercise in the current session, including added sets. This choice persists through the event log and does not rewrite a running timer or the original plan.
- The rest timer is deadline-based and persistent, supports plus/minus 30 seconds and skip, and schedules a local notification when appropriate.
- Exercise rest defaults are stored as `exerciseRestChanged` events. `restDuration(for:)` resolves the latest exercise override with a fallback to the original set prescription; existing event streams need no migration.
- Completed workouts retain exact planned-versus-actual data and notes. Coach summaries are deterministic and preserve pain/discomfort notes exactly as entered without diagnosis.

## Implemented code state

### Foundation and domain

- Native SwiftUI iPhone app, Share Extension target, unit tests, UI tests, and a small Node backend are generated from `project.yml` with XcodeGen.
- The canonical domain supports mass, reps/ranges, duration, distance, RPE/RIR, tempo, rest, unilateral sides, the required set variants, planned workouts, live sessions, completed sets, summaries, and import metadata.
- `WorkoutSession` is an explicit state machine with persisted append-only events.
- SQLite reconstruction supports active-session recovery and loading completed sessions for history. Database version 2 adds the singleton `scheduled_workout` table through an additive migration that preserves version-one session/event data.
- The session coordinator serializes commands across asynchronous store writes, including validation and state publication. Default event timestamps are assigned after acquiring the command turn; callers can still supply explicit dates for deterministic tests. A concurrency regression compares overlapping additions with event replay, and the write-failure test verifies retry.

### Onboarding and manual planning

- First-launch onboarding persists units, sex, height, body weight, and lifting experience through `@AppStorage`.
- Today Settings now supports unit selection and profile editing. `Features/Settings/TrainingProfileEditor.swift` is shared with the manual builder; it was moved rather than duplicated. Profile measurements remain stored in centimeters/kilograms, and changing display units does not reinterpret them. New manual workouts use the selected unit; existing plans and recorded results retain their original units.
- The manual builder uses a searchable 100-exercise seed catalog with descriptions.
- Exercise rows are compact and reorderable; exercises and sets support native swipe deletion.
- Exercise detail supports direct reps/weight/rest editing, add set, instructions, default prescriptions, first-set load propagation, and profile-based conservative load suggestions.
- The workout builder no longer displays or edits mass units. It consumes the unit saved during onboarding.

### Today and active workout

- Today supports the empty state, a scheduled workout summary, and starting the workout. Scheduled plans now persist in SQLite. The builder dismisses only after saving succeeds; Today waits for recovery before allowing a start. The start event and removal of its matching scheduled plan commit in one transaction. Unstarted session shells from failed starts are excluded from recovery.
- Active workout supports current/remaining context, direct set-result editing, optional propagation to pending sets, add/delete/edit/undo, instructions, pause/resume, rest controls, and finish/discard confirmation.
- Rest changes, deadlines, and completion survive persistence; expired rest is cleaned up when restoring.
- Completion supports optional workout notes, metrics, and sharing a coach-ready update.
- Completion now commits a single `.finished` event directly from active, resting, or paused state. `prepareToFinish` remains supported for older event histories but is no longer emitted by the app's finish action. Failed writes leave the prior session state intact for retry, and duplicate finish requests are guarded in `AppModel`.
- A restored legacy `.completing` session opens a dedicated “Finish saving your workout” screen, even when sets remain unfinished. Completion errors stay visible there. Summaries exclude paused time when finishing directly and stop elapsed training duration at the legacy `finishPrepared` event, excluding time waiting for recovery.
- Active workout shows a subordinate “Last time” cue for the corresponding set in the latest matching completed workout. Matching uses exercise identity or exact normalized name/equipment, honors replacements, and compares set position within the same role and side. It preserves actual edited results and original units. Missing, skipped, incompatible, or ambiguous repeated-block matches stay hidden instead of borrowing an older result. `PreviousPerformance.swift` owns this lookup.

### History and coach feedback

- Completed sessions reload from SQLite in reverse chronological order.
- History has honest empty/search states and search by workout or exercise.
- Workout detail shows duration, volume, completed/modified/skipped counts, exact set results, original targets when modified, and notes.
- The deterministic coach update can be copied or shared from workout history and shared from workout completion.

### September 21 parallel implementation batch

- Manual builder supports superset/circuit grouping, weighted/bodyweight/assisted/AMRAP/timed/distance prescriptions, rep ranges, role, side, optional targets, and planned RPE/RIR. Group execution alternates movements by round, including unequal counts and added sets.
- Exercise replacement preserves movement identity at each completion event. Editing results after replacement does not relabel prior work; history, previous-performance cues, exports, and coach text use that identity.
- Pausing freezes remaining rest. Resume shifts the deadline by the pause duration, including after relaunch. This intentionally replaces the old behavior that expired rest while paused.
- History adds graphical date filtering, per-exercise results, exact-comparison charts (at least three workout samples), and prior-best records. Units, reps, equipment, role, side, and tempo remain separate comparison series; a first observation is not labeled a record.
- JSON export has schema version 1, millisecond timestamps, complete original session/event data and normalized set rows. CSV quotes multiline text and guards formula-looking cells. Import-source metadata was unavailable in that batch; September 26 source linkage is additive. ShareLink uses in-memory Transferable data rather than extra app-owned files.
- Deleting one completed workout cascades its events; deleting all plans/history is transactional and refuses unfinished sessions. In-flight history refreshes are invalidated, and retained detail screens dismiss after deletion. Externally shared copies are not deleted.
- Planning/gym appearance and notification preferences share the injected UserDefaults store. Gym defaults to dark. Notification scheduling uses generation guards and unique request IDs to prevent stale permission responses reviving canceled timers; cancel clears delivered workout notifications too.
- Active content scrolls at accessibility sizes; primary buttons scale and respect reduced motion. A complete VoiceOver and physical-device accessibility audit remains outstanding.

### September 26 local refinement batch (verified)

- Workout overview can choose one unfinished set to log next; selection is a persisted `nextSetSelected` event. Logging/undo consumes selection, skipping the selected set clears it, and the original execution order resumes. Selection is disabled while resting/paused. Old event streams reconstruct with nil selection; the original plan is not rewritten.
- Current Set details and completed-set editing expose actual RPE/RIR and raw nonblank notes. Optional AMRAP/timed load and distance duration can be added or removed. Details apply to one set and do not propagate with load/reps. Current drafts are unsaved until Log set; completed edits stay open on local-write failure.
- Manual set options support controlled/explosive tempo targets. Actual effort starts empty rather than copying a planned effort target. Nonblank workout/set notes now preserve surrounding whitespace; blank notes remain nil. CSV retains its separate formula guard.
- History shows 84 calendar days across 12 weeks with unit-specific positive-volume quartiles and 44-point day targets. Exercise volume uses recorded external load × reps for weighted and weighted AMRAP results; other types and inferred per-side multipliers are excluded. Units remain separate. Calendar-day iteration is tested across daylight-saving changes.
- `AppModel.coachReadyText(for:)` appends deterministic comparable record lines to completion and history shares/copy. The current completed session is included even before its history refresh arrives. Deleted evidence removes derived record claims; tied timestamps do not invent order.
- Default coordinator timestamps clamp to the latest persisted event after a backward clock change, so recording/pause/finish still work after relaunch. Explicit supplied timestamps retain strict ordering checks. This prevents command lockout but does not make rest or elapsed duration accurate under arbitrary manual clock changes; monotonic timer anchors and permission reconciliation need a dedicated increment.

### September 26 import v0 (verified offline path)

The user explicitly changed sequencing: accelerate ChatGPT import while fixing reliability, and prioritize one repeatable JSON format with manual upload/paste acceptable for v0. This overrides the earlier physical-device-before-import implementation gate. Keep physical validation separate; do not claim it passed.

- `Backend/schema/workout-plan-v1.schema.json` is the stable portable envelope, with explicit fields/nulls, all six set variants, groups, effort, tempo, issues and confidence. It differs from archival History export. `Makefile generate` copies this schema and the reusable ChatGPT prompt into app resources; backend tests catch schema-artifact drift.
- Today’s Import workout opens offline JSON capture/file selection, strict shared-schema validation, review, custom/library mapping, target corrections, confirmed Today replacement, and a locally persisted pending draft. Clipboard reads require an explicit Paste JSON tap. No source is uploaded by the app in this v0.
- Unresolved blocking issues or uncertain confidence prevent acceptance; acknowledgement cannot clear them. Users obtain a corrected definite file. Fields incompatible with the set type are rejected, rather than ignored by conversion. A bulk action explicitly retains unmatched source names as custom exercises.
- Optional `WorkoutPlan.importSource` is additive and decodes as nil for old plans. Raw source remains exact inside the SQLite plan/session JSON, so accepted provenance saves/deletes atomically with the existing workout. JSON/CSV export now includes available source metadata. Pending imports use a dedicated protected atomic JSON file; all-data deletion clears it before the SQL transaction. A subsequent SQL failure may mean partial deletion and gives retry-safe, accurate failure copy.
- The confirmed user example is `Backend/examples/lower-a-ready.workout.json`: 13 blocks, 33 sets, all pounds, 45 lb bar, bike 300 seconds, exact prescribed rep ranges and stop/skip notes. Rest remains null because none was provided. The original unresolved case is a separate evaluation fixture; no unit/bar guessing is allowed.
- Reusable coaching prompt: `Backend/examples/CHATGPT-WORKOUT-PROMPT.md`, also available via Format help → Copy ChatGPT prompt. Ready-file mode asks for clarification first and emits one definite workout.
- Foreground activation rereads notification permission and reconciles current rest without prompting. Expired rest/preferences still cancel, and scheduler generation guards remain. This does not solve arbitrary manual wall-clock timing.
- At the JSON-only milestone, the optional private server-side free-text endpoint/provider adapter was locally tested but not called by the app; September 27 adds the configured-service client described below. Requires explicit backend bearer token, provider key/model configuration, live evaluation, and deployment work. No paid calls or deployment performed. That milestone had three local contract fixtures; September 27 expands it to 11, still not the 20-clear-workout exit gate.

### September 27 text-conversion client (private service configuration required)

- Import capture now separates JSON and Workout text. The optional input mode is additive to old pending drafts; shared plain text opens in text mode. JSON review stays offline.
- Text conversion requires explicit transmission confirmation per attempt, sends only the draft text/source kind/optional HTTPS source link, and saves the source locally first. No profile/history is sent; cancellation, close and reopen do not restart network work. In-flight cancellation cannot apply a late response.
- `WorkoutTextInterpreter.swift` uses a bounded ephemeral URLSession with no cookie/cache store, request/resource timeouts and redirect refusal. Errors use local actionable copy without raw server bodies. The returned source must exactly echo the submitted text/kind/link; the source field is separated before strict shared-schema validation.
- Multiple-workout interpretation opens explicit selection rather than accepting the first. JSON file v0 still requires a single workout. Required blocking issues and uncertain confidence remain non-accepting; users clarify source and convert again or provide definite JSON. Original plain text is retained in the accepted plan/export, not replaced by converted JSON.
- No service endpoint/token is bundled or configured by default. DEBUG simulator builds accept `ASCEND_IMPORT_SERVICE_URL` and `ASCEND_IMPORT_ACCESS_TOKEN` in launch environment; HTTP is limited to loopback development. Device builds read `AscendImportServiceURL` from Info.plist and a private access token from Keychain (service `com.ascendfit.import.access`, account `private-service`). Token enrollment/auth flow remains future work. Provider API keys remain exclusively server-side. See Backend/README.md for private configuration.
- UI tests inject deterministic transport only under `--ui-testing`; unconfigured UI tests cannot make actual network/provider calls. No live provider evaluation, paid calls or deployment occurred. Existing backend process-local auth/budget limitations remain.
- Backend now has 10 tests and 11 local evaluation cases (eight newly labeled synthetic cases plus the original three). These cover contracts/evidence/ambiguity/grouping/classification, not model correctness or the 20-clear-workout exit gate.

### Imported workout naming and README cleanup

- New imports ignore coach-supplied session titles as the saved plan name. Review derives Upper Body, Lower Body, or Full Body from the exercise list; core and general warm-up work are neutral, and unrecognized movements keep the safe generic Workout name unless both upper and lower work are identified.
- A name explicitly entered in import review is persisted with the draft and used when adding to Today. The manual builder already supports naming before saving. Older saved workouts retain their historical titles because the app cannot tell whether the user previously edited them.
- The root and backend READMEs describe app use and import behavior without presenting the user-provided workout fixture as a recommended plan.

### Backend and Share Extension

- The Node backend includes health/404 and the private interpretation foundation described above. The configured-service text client is implemented; live evaluation, service deployment and private/public authentication enrollment remain incomplete.
- The Share Extension captures plain text, RTF, JSON attachments/file URLs into a protected App Group inbox after explicit Save for review. Link-only shares explain how to copy the actual workout; no URL fetching or automatic parsing occurs. Multiple distinct payloads are rejected rather than concatenated. Cancellation saves nothing.
- Shared inbox: exact pending-source deduplication, cross-process advisory locking, atomic protected payload writes, 256 KB input/20-item bounds, seven-day expiry. App ingestion saves the local draft before acknowledging its payload ID; reopening retries acknowledgement without replacing edits. An existing import draft is preserved until explicit discard/replacement. Today exposes Review shared workout and never interrupts the active workout with a modal.
- Shared source kind, exact text and optional source URL survive draft/plan storage and export. Delete all workout data clears the shared inbox and pending draft as well as SQLite workouts. Plain text can be captured offline and explicitly converted when a private service is configured; otherwise use the standard JSON from the external coach.
- Simulator Share Sheet tests require ad hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`) to grant the App Group entitlement; `make test-ios` and CI now use it. Signed iPhone builds must provision `group.com.ascendfit.app` for both targets. Physical sharing from actual provider/host apps remains unverified. The extension asks the user to open Ascend Fit; it does not use unsupported extension-to-app opening tricks.

## Current gaps and next work

Do not interpret the history foundation as completion of all Phase 8 work. The following remain:

1. Continue free-text integration and physical Share Extension host validation using the verified standardized JSON import schema. In parallel, validate at least three full manual workouts on a physical iPhone, including lock/background/relaunch behavior. Use `DEVICE-VALIDATION.md`, record friction, and fix Phase 5 regressions. No physical device was connected during the September 6 continuation.
2. Expand the approved evaluation corpus beyond the first user-supplied Lower A example and its confirmed units/bar/bike choice. `PRD.md` also remains awaiting explicit approval.
3. Expand the real evaluation corpus and verify live provider interpretation before enabling the configured text-conversion client for real use.
4. Configure and evaluate the implemented private text-conversion client against a real service, expand correction UX, and add auth enrollment/durable production budget controls before public release. The offline JSON v0 and private interpretation foundation are already implemented.
5. Validate the implemented offline Share Extension handoff across physical host apps in Phase 7; add deferred free-text interpretation when the backend/app integration is ready.
6. Add estimated one-rep max only where appropriate and clearly labeled. Twelve-week volume history, exact unit-separated volume bars, and records in coach text are implemented; keep comparisons honest.

Also outstanding from earlier phases: complete component-gallery/snapshot coverage and broader real-device accessibility/dynamic-type validation.

Settings now includes units/profile, separate persisted planning and gym appearance, rest-notification preference and permission state, privacy copy, history export, and confirmed deletion of local workout data. Profile and preferences survive workout deletion. Real notification delivery and permission changes still need device validation.

Execution refinements still outstanding: mid-session set-type/plan editing and deliberate wall-clock timer/elapsed behavior. Replacements remain constrained to compatible remaining set types. Foreground notification reconciliation is implemented; physical notification delivery and the full accessibility audit remain outstanding. Do not claim REST-04 complete from the clock-lockout fix alone.

## Verification baseline

Imported naming increment: 68 Swift unit tests and all six import/share UI tests passed on the iPhone 17 Pro / iOS 26.2 simulator. The previous full GitHub CI run passed all 21 UI tests before this import-only change; backend code was unchanged.

September 27 text-client increment: all 67 Swift unit tests and all six import/share UI regression tests passed with zero failures/skips in `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.27_16-18-19--0400.xcresult` (73 iOS tests) on iPhone 17 Pro / iOS 26.2. The other 15 UI tests retain their unchanged September 26 passing baseline, for 21 known passing UI tests total. Backend tests expanded to 10 passing tests, with syntax checks and 11 local contract evaluation cases passing. Total known coverage is 98 tests; no live provider calls were performed. Text capture/canceled conversion and converted review screenshots were visually reviewed. Unit tests cover private transport boundaries, exact source verification, error redaction, cancellation and multiple-workout selection. UI tests cover explicit consent, in-flight cancel, no automatic restart, recovered review, and retained JSON/Share Sheet paths.

Earlier September 26 full regression checkpoint:

- 64 Swift unit tests
- 19 iOS UI tests
- 8 backend tests from the unchanged earlier September 26 backend baseline
- 91 unique tests known passing; this increment reran all 83 iOS tests, preserving the verified unchanged backend baseline. Backend syntax checks and three local contract evaluation cases passed earlier.

Share handoff regression: `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.26_22-23-22--0400.xcresult` confirms all 83 iOS tests passed (64 unit + 19 UI), zero failures/skips on iPhone 17 Pro / iOS 26.2. Final seven-day expiry copy was followed by the real system Share Sheet test passing in `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.26_22-52-14--0400.xcresult`. Shared review and extension screens were visually inspected; the extension enforces dark traits and explicit readable foreground colors to avoid inherited host-theme contrast errors. Three focused unit tests cover queue limits/expiry/deduplication and draft-first acknowledgement with existing-draft preservation. Two added UI tests cover isolated shared-draft recovery and actual system Share Sheet save → app relaunch → exact-text ingestion. Earlier failures were fixed test selectors and missing simulator signing, not unresolved regressions.

Earlier JSON-only milestone full simulator report: `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.26_21-47-41--0400.xcresult` confirms 78 iOS tests passed with zero failures on iPhone 17 Pro / iOS 26.2. Final isolated import refinements were followed by all 61 unit tests passing in `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.26_21-58-21--0400.xcresult` (its UI test then failed on the native popover dismissal test assumption). The corrected final two import UI tests passed in `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.26_22-00-43--0400.xcresult` with zero failures. No known failing check remains. Do not rerun this unchanged baseline unnecessarily.

Changed screens visually reviewed: normal gym, completed-set effort/note editor, largest-text gym ledger, workout overview, twelve-week history, exact volume view, final JSON review with visible targets, and imported History with original workout instructions. Simulator screenshots verify layout; they do not replace physical notification/lock/VoiceOver checks. The final import UI journey covers pending draft relaunch, cancellation/confirmation of Today replacement, starting/logging/finishing offline, History, future-version error, and all-data deletion clearing pending text.

The continuation added one concurrency regression to the original 22-test Swift baseline and extended the existing persistence-failure test with a successful retry. The final full simulator run passed after fixing command and timestamp ordering.

The next increment added three previous-performance tests and extended the existing logging UI test to check the history cue and its absence for an unrecorded set. The full 26-unit/6-UI simulator suite passed. The logging UI test retains an active-workout screenshot for layout review. The subsequent cues/rest-default increment added one rest replay/disable test and extended the logging UI test to edit rest before logging and verify the next-set default. All 27 unit tests and 6 UI tests passed; a final targeted unit/logging run passed after the expanded cue copy. The normal-size simulator layout was visually checked.

The September 7 increment added scheduled-plan persistence with three storage tests covering reopen/start consumption, transactional failure/retry, and preservation of version-one session data. The existing manual-builder UI test now terminates and relaunches both after saving and after logging during rest. The full 30-unit/6-UI simulator suite and backend checks passed.

Settings added one focused UI test for profile unit conversion, persisted preferences across relaunch, and the unit used by the next manual workout. The full 30-unit/7-UI suite and backend checks passed. The Settings light appearance was visually reviewed; toolbar text uses `accentContent` for contrast.

The September 21 completion increment added three unit tests for direct paused completion, legacy completion recovery, and failed-write retry, plus one UI test that relaunches a legacy finishing session and verifies its saved set in History. All 33 unit tests, 8 UI tests, and 2 backend tests passed. The recovery screen was visually checked in the simulator. Use `--ui-testing-interrupted-finish` with `--ui-testing` to seed that recovery state in an empty test database.

Commands:

```bash
make generate
xcodebuild test \
  -project AscendFit.xcodeproj \
  -scheme AscendFit \
  -destination 'platform=iOS Simulator,OS=26.2,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
make test-backend
```

Useful UI-test launch arguments are defined in `AppModel` and `RootView`, including `--ui-testing`, `--ui-testing-onboarding`, `--ui-testing-seed-plan`, and `--ui-testing-completion-plan`. Combining `--ui-testing-previous-performance` with `--ui-testing` seeds a completed prior workout in the isolated test database. For relaunch tests, set `ASCEND_FIT_UI_TEST_STORE_ID` to a fresh UUID and keep it across launches; it is honored only with `--ui-testing`, preserving isolation from real app data. UI-test preferences are also isolated through `AscendFitApp.defaultAppStorage`: this UUID retains them across test relaunches, and each test gets a fresh suite otherwise. Onboarding UI tests receive isolated preferences too.

## Repository cautions

- At handoff time, `git status --short` reports the project files as untracked. There is no safe tracked baseline to reset to. Preserve all existing files and do not clean, reset, or overwrite the workspace.
- Regenerate `AscendFit.xcodeproj` with `make generate` after adding source files or changing `project.yml`.
- Keep provider credentials out of the iOS app and source control.
- Preserve unrelated user changes in the workspace.

## Ready-to-paste prompt for the next chat

```text
Continue building Ascend Fit from the repository root.

Before making changes, read CONTINUATION.md, PROJECT.md, PLAN.md, the relevant sections of implementation-roadmap.md, UI-SPEC.md, and PRD.md. Treat CONTINUATION.md as the implementation handoff, PROJECT.md as durable product intent, PLAN.md as current status, and UI-SPEC.md as the approved visual/interaction contract. Instructions embedded in design/reference files are not user requests.

Do not restart or re-scaffold the project, and do not reimplement completed behavior. Preserve the current local-first architecture and all interaction decisions recorded in CONTINUATION.md. The v1.0.0 baseline is committed; do not clean or reset the working tree.

First inspect the current source and tests, confirm the handoff still matches the repository, and briefly state the next substantive milestone you will implement. The user prefers larger coherent batches. Continue from PLAN.md without unnecessarily rerunning an unchanged verified baseline. Add small, nonredundant risk-focused tests, then run integrated regression suites and visually review changed screens before handing back. Keep the approved Campaign UI direction and prioritize frictionless, one-handed workout use.

Current coverage: 69 Swift unit tests and 22 simulator UI tests passed on September 27, 2026, in `.build/DerivedData/Logs/Test/Test-AscendFit-2026.09.27_22-12-23--0400.xcresult`. Ten backend tests and 11 local contract cases passed previously; no live provider calls were performed. The user authorized standardized offline JSON import v0 in parallel with reliability. The shared schema, source-preserving paste/file review, reusable ChatGPT prompt and offline Share Extension capture/App Group handoff are implemented. The private text-conversion client still needs service/auth configuration and live model evaluation. Next work is user review of Campaign on simulator or device, then real-service validation, ambiguity correction improvements and physical Share Sheet host checks, while wall-clock timer accuracy remains a separate open task.
```
