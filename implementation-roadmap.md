# AI-Native Workout App — Detailed Implementation Roadmap

Date: September 5, 2026

## Recommended delivery target

Build in two releases:

- **Personal MVP:** approximately 8–10 focused development weeks. It must complete the entire AI workout → import review → gym execution → history loop on one iPhone.
- **Public App Store v1:** approximately 12–16 total weeks, after personal use and a small TestFlight beta. It adds accounts, cloud safety, HealthKit, accessibility hardening, support, privacy controls, and production monitoring.

These are planning ranges for one focused developer using coding assistance, not fixed commitments. The plan deliberately keeps direct ChatGPT plugins, a full in-app coach, Apple Watch, social features, and automatic programming out of public v1.

## Locked working assumptions

Use these unless product testing changes them:

- Native iPhone app built with Swift and SwiftUI.
- Current Xcode and SDK, with iOS 18 as the provisional minimum deployment target.
- Strength training first; support duration-based accessories, but not a complete cardio platform.
- Local-first workout execution: an active workout never depends on the network.
- Hosted AI parsing through a protected backend; no provider API key inside the app binary.
- One initial model provider behind a provider-neutral adapter.
- Supabase/PostgreSQL for the public backend and authentication.
- GRDB/SQLite for explicit local schemas, migrations, and an append-only workout event log.
- Sign in with Apple enters before the public beta, not before the first personal build.
- The approved production direction is “Lilac on ink-violet,” as specified in `UI-SPEC.md`; continue validating it on a physical iPhone as each critical flow is implemented.

## Phase 0 — Convert the concept into an executable product contract

**Duration:** 3–5 days

### Step 0.1: Write the v1 product requirements document

Define the exact user promise:

> Import a strength workout from any AI coach, resolve only ambiguous details, track it reliably in the gym, and return a useful completion summary.

Document:

- Target user and primary scenario.
- MVP feature boundary.
- Explicit non-goals.
- Import success definition.
- Gym reliability definition.
- Privacy principles.
- App Store v1 versus later roadmap.

### Step 0.2: Collect real source material

Export or copy 50–100 real workout outputs from ChatGPT, Claude, and Gemini. Include:

- Bullets, tables, prose, and Markdown.
- Pounds, kilograms, mixed units, and missing units.
- Rep ranges, RPE/RIR, AMRAP, warm-up ramps, and drop sets.
- Supersets and circuits.
- Unilateral movements.
- Incomplete or contradictory workouts.
- Messages containing several days of programming instead of one workout.

Remove private information before the examples enter the test corpus.

### Step 0.3: Define measurable v1 outcomes

- Clear workout imports are structurally correct at least 95% of the time by public beta.
- Median clear-workout import requires fewer than one manual correction.
- Median share/paste to ready-to-start time is under 30 seconds.
- Normal set completion requires one tap and no keyboard.
- No completed set is lost after backgrounding, force-quitting, or losing connectivity.
- A user can resume an interrupted workout in under two seconds after launch.

### Exit gate

The PRD, sample corpus, MVP boundary, and measurable outcomes are approved before screen design or implementation begins.

## Phase 1 — Establish the product’s visual and interaction system

**Duration:** 1–2 weeks

UI design runs before engineering for each critical flow. Do not begin by building a generic component library.

### Step 1.1: Develop three distinct visual directions

Produce moodboards and one Today-screen study for each:

1. **Editorial Athlete — recommended:** warm mineral surfaces, graphite gym mode, violet identity, coral timing accents, bold editorial hierarchy.
2. **Night Performance:** deep black, cool blue, sharp high-energy typography, more technical and aggressive.
3. **Calm Precision:** light neutral surfaces, navy/teal, more native and clinical.

Evaluate each against differentiation, gym legibility, emotional tone, App Store recognizability, dark mode, and accessibility. Select one direction; do not blend all three.

### Step 1.2: Define design foundations

Create design tokens and usage rules for:

- Semantic color roles: background, primary content, secondary content, primary action, progress, success, warning, destructive, and rest timer.
- Light and dark appearances.
- Typography: editorial display, interface text, and tabular workout numerals.
- Spacing scale and alignment grid.
- Corner-radius hierarchy.
- Standard content materials versus floating navigation/control materials.
- Icon style and stroke weight.
- Motion duration, easing, reduced-motion behavior.
- Haptic meanings: selection, completed set, rest finished, warning, destructive confirmation.
- Chart styling.
- Photography or exercise-illustration direction.
- Product writing voice.

### Step 1.3: Design the full state inventory

Design every important state, not only ideal screenshots.

#### Today

- First launch with no workout.
- Planned workout ready.
- Active workout to resume.
- Completed workout.
- Offline state.

#### Import

- Empty paste/share capture.
- Reading and matching.
- Successful import with no issues.
- One or several unresolved fields.
- Unknown exercise.
- Missing units.
- Multiple workouts detected.
- Parsing failure.
- Duplicate import.

#### Active workout

- Warm-up set.
- Working set.
- Current rest period.
- Paused workout.
- Edited target.
- Skipped set/exercise.
- Superset transition.
- Offline indicator.
- Personal record.
- End-workout confirmation.
- Relaunch recovery.

#### History

- Empty history.
- Workout list/calendar.
- Workout detail.
- Exercise detail and prior performance.
- Progress trend with insufficient data.

### Step 1.4: Design six high-fidelity anchor screens

1. Today
2. Import capture
3. AI import review
4. Gym focus mode
5. Workout completion
6. History/exercise progress

Use realistic exercises and long titles. Validate at standard and large Dynamic Type sizes.

### Step 1.5: Prototype the two critical flows

#### Flow A: External AI to gym

Share workout → parsing → review ambiguity → add to Today → start workout.

#### Flow B: Complete one exercise

View target and previous performance → edit if necessary → complete set → rest timer → next set → undo.

### Step 1.6: Test in a real gym

Use the prototype on a physical iPhone while training. Test:

- One-handed reach.
- Sweaty or chalky hands.
- Bright overhead lighting.
- Dark mode.
- Music playing.
- Locking and unlocking between sets.
- Large text.
- Interruptions and equipment changes.

### UI exit gate

- The primary hierarchy is understandable in a five-second glance.
- Every primary control has at least a 44-point comfortable target.
- A normal set can be completed one-handed with one tap.
- Common weight and rep adjustments take no more than two taps before entry.
- No essential status depends on color alone.
- Import ambiguities are obvious without looking like errors.
- The selected art direction is approved before production components are built.

## Phase 2 — Set up the engineering foundation

**Duration:** 3–4 days

### Step 2.1: Create the projects

Create:

- iOS application target.
- Share Extension target.
- Unit-test and UI-test targets.
- Backend service.
- Database migrations.
- Separate development and production configuration.

### Step 2.2: Establish module boundaries

Recommended iOS modules:

- `AppShell`
- `DesignSystem`
- `WorkoutDomain`
- `WorkoutSession`
- `WorkoutImport`
- `ExerciseCatalog`
- `History`
- `LocalStore`
- `Sync`
- `SystemIntegrations`

Keep model-provider details out of the iOS domain layer.

### Step 2.3: Add quality automation

- SwiftFormat or equivalent formatting.
- SwiftLint with a small, intentional rule set.
- Swift Testing/XCTest.
- Snapshot tests for anchor screens.
- Backend linting, type checking, and tests.
- Continuous integration on every pull request.
- Debug-only seed-data and failure-state menus.

### Step 2.4: Establish environments and secrets

- Never store provider keys in source control or the iOS app.
- Add server-side secret management.
- Add separate development and production database projects.
- Redact raw import text from normal logs.
- Assign stable installation and request IDs without using email addresses in telemetry.

### Exit gate

The empty app, Share Extension, backend health check, migrations, and CI all build and test successfully.

## Phase 3 — Build the canonical workout domain

**Duration:** 1 week

This phase is the foundation for manual workouts, AI imports, shared links, and future plugins.

### Step 3.1: Define value types

- Weight and unit.
- Rep target and rep range.
- Duration and distance.
- RPE and RIR.
- Tempo.
- Rest duration.
- Exercise side: bilateral, left, right, alternating, per-side.

### Step 3.2: Define entities

- Exercise definition and aliases.
- Workout draft.
- Planned workout/exercise/set.
- Workout session.
- Completed set.
- Session event.
- Workout summary.
- Import source and unresolved field.

### Step 3.3: Model set variants

Support from the beginning:

- Warm-up
- Standard weighted
- Bodyweight
- Assisted bodyweight
- AMRAP
- Timed
- Distance
- Drop set
- Failure set
- Superset/circuit grouping

### Step 3.4: Implement the workout-session state machine

Explicit states:

- Not started
- Active
- Resting
- Paused
- Completing
- Completed
- Discarded

Explicit events:

- Start, pause, resume, complete set, edit set, undo, skip, add set, replace exercise, start/end rest, finish, and discard.

### Step 3.5: Build persistence and migrations

- Store every meaningful session change locally before updating the UI.
- Use stable UUIDs.
- Append session events for reliable reconstruction and later synchronization.
- Store timer deadlines, not continuously decremented values.
- Add fixture import/export for automated tests.

### Exit gate

Domain tests can construct, run, interrupt, restore, finish, and summarize a workout without any UI or network.

## Phase 4 — Build the reusable premium UI system

**Duration:** 1 week, overlapping late Phase 3

Build only components proven by the high-fidelity designs.

### Step 4.1: Implement foundations

- Semantic colors and appearance switching.
- Typography styles and tabular numerals.
- Spacing and radius tokens.
- Motion and reduced-motion helpers.
- Haptic service.
- Accessibility labels and traits.

### Step 4.2: Implement core components

- App navigation shell and floating tab bar.
- Workout hero.
- Primary and secondary actions.
- Movement row.
- Set progression rail.
- Large weight/reps target display.
- Numeric editor/stepper.
- Rest timer dock.
- Import provenance label.
- Ambiguity/decision row.
- Empty, loading, offline, and error states.
- Progress chart primitives.

### Step 4.3: Add a component gallery

Create an internal screen that renders every component in:

- Light and dark mode.
- Default and accessibility text sizes.
- Normal, pressed, disabled, warning, and completed states.
- Short and long localized content.

### Exit gate

Snapshot tests cover anchor components, and the gallery demonstrates that the visual system remains coherent across state and appearance changes.

## Phase 5 — Build the local workout tracker first

**Duration:** 2 weeks

Do this before AI import so the importer targets a working execution system.

### Step 5.1: Build Today

- Empty state.
- Planned-workout hero.
- Start/resume actions.
- Workout overview with exercise order and set summaries.
- Manual workout creation entry point.

### Step 5.2: Build Gym Focus Mode

- Current exercise and set.
- Previous-performance comparison.
- Large target load and reps.
- Complete, edit, undo, skip, and add set.
- Overview and exercise navigation.
- Superset progression.

### Step 5.3: Build the rest system

- Exercise-level default rest.
- Automatic rest after set completion.
- Pause, extend, skip, and disable.
- Haptic/audio completion.
- Local notification when backgrounded or locked.
- Correct restoration after app relaunch.

### Step 5.4: Build completion

- Duration, completed sets, skipped/modified sets, and total volume.
- Optional RIR/effort and notes.
- Personal-record detection.
- Coach-ready plain-text summary.

### Step 5.5: Test destructive and interrupted paths

- Accidental complete and undo.
- End unfinished workout.
- Force-quit during rest.
- Phone clock/timezone changes.
- Low-memory termination.
- No network for the entire session.

### Exit gate

Complete three manually created real workouts. No core action requires the backend, and no completed set is lost.

## Phase 6 — Build the AI workout importer

**Duration:** 1.5–2 weeks

**September 26 sequencing update:** The user authorized import work in parallel with local reliability/device validation. Prioritize an offline v0: one versioned JSON interchange schema, paste/file capture, deterministic validation, source-preserving review, and explicit acceptance into Today. The external coach can emit this standard format directly. Free-text AI interpretation then becomes an adapter into the same schema. Physical-device and corpus gates remain required evidence for their respective capabilities; they no longer block implementation of structured import.

### Step 6.1: Finalize `WorkoutPlan v1` JSON Schema

The schema must represent every domain feature supported by the tracker. Version the schema and reject unsupported future versions cleanly.

### Step 6.2: Implement the backend interpretation pipeline

1. Authenticate or rate-limit the request.
2. Sanitize and size-limit the text.
3. Classify whether it contains zero, one, or several workouts.
4. Request strict schema output from the provider.
5. Resolve exercise aliases.
6. Normalize units while preserving the source value.
7. Run deterministic validation.
8. Return structured fields, unresolved issues, field confidence, and source traceability.

### Step 6.3: Seed the exercise catalog

- Begin with approximately 300–500 common strength exercises.
- Include equipment, muscles, movement pattern, unilateral behavior, and aliases.
- Add custom exercise support.
- Never force a low-confidence exercise match.

### Step 6.4: Build import capture UI

- Paste text.
- Recognize clipboard content only after explicit user action.
- Show concise parsing stages.
- Cancel and retry.
- Avoid exposing model/provider implementation details.

### Step 6.5: Build import review UI

- Show a natural-language import summary.
- Render validated movements quietly.
- Surface only unresolved decisions prominently.
- Offer history-informed corrections.
- Allow exercise remapping and custom exercise creation.
- Save original source with the draft.
- Require confirmation before adding to Today.

### Step 6.6: Build the evaluation harness

Run the saved corpus on every parser or schema change. Measure:

- Workout detection.
- Exercise mapping.
- Sets/reps/load accuracy.
- Unit accuracy.
- Superset structure.
- Ambiguity detection.
- Unsafe or irrelevant input rejection.
- Latency and estimated cost.

### Exit gate

At least 20 representative clear workouts can be pasted and started without structural correction. Every ambiguous test case is surfaced rather than silently guessed.

## Phase 7 — Add the iOS Share Extension

**Duration:** 3–5 days

### Step 7.1: Accept supported inputs

- Plain text.
- Shared URLs.
- Rich text where text extraction is possible.

### Step 7.2: Transfer safely into the app

- Store the pending import in the shared App Group container.
- Give it an idempotency key.
- Open the app to the import flow.
- Remove the pending payload after successful ingestion.

### Step 7.3: Handle realistic host behavior

- ChatGPT/Claude/Gemini share behavior may differ.
- A shared link may not expose conversation contents; explain when paste is required.
- Support cancellation, duplicate shares, expired payloads, and offline capture.
- Queue parsing until connectivity returns.

### Exit gate

Test share and paste from ChatGPT, Claude, Gemini, Safari, Notes, Messages, and email on a physical device.

## Phase 8 — Build history and the coaching feedback loop

**Duration:** 1 week

### Step 8.1: History

- Chronological list and simple calendar navigation.
- Workout summary/detail.
- Exact completed-set history.
- Search by workout or exercise.

### Step 8.2: Exercise progress

- Last performance.
- Best weight, estimated one-rep max where appropriate, total volume, and rep history.
- Honest empty and low-data states.
- Charts with accessible summaries.

### Step 8.3: Coach-ready summaries

Generate a deterministic summary containing:

- Planned versus actual work.
- Modified or skipped sets.
- RPE/RIR and notes.
- Personal records.
- Pain or discomfort notes exactly as entered, without diagnosis.

Offer Copy, Share, and later Send to connected coach.

### Exit gate

A completed workout can be found, inspected, exported, and summarized accurately without AI assistance.

## Personal MVP checkpoint

At the end of Phase 8, distribute a private TestFlight build and use it for at least 10 complete sessions over multiple weeks.

Record friction immediately after each session:

- Where did the app require unnecessary attention?
- Which values were hard to edit?
- Was the rest timer trustworthy?
- Did import require corrections?
- Did you ever reopen Fitbod, and why?

Do not proceed directly to public launch if the core loop still feels like a prototype.

## Phase 9 — Add accounts, backend persistence, and sync

**Duration:** 1–2 weeks

### Step 9.1: Authentication

- Sign in with Apple.
- Optional anonymous/local-first onboarding with a clear upgrade path.
- Account deletion inside the app.

### Step 9.2: Server schema

- Users and preferences.
- Exercise mappings and custom exercises.
- Workout drafts, plans, sessions, and events.
- Import source metadata.
- Sync cursors and idempotency records.

### Step 9.3: Event synchronization

- Upload local events when connected.
- Download remote changes incrementally.
- Resolve by entity/event identity instead of replacing an entire workout.
- Test offline edits, reinstall, sign-out, and multi-device conflict scenarios.

### Step 9.4: Privacy controls

- Data export.
- Account and cloud-data deletion.
- Clear AI-provider transmission disclosure.
- Retention policy for raw import text.
- No raw workout or prompt text in product analytics.

### Exit gate

Two devices converge on the same history without losing local workout events, and account deletion removes cloud data according to policy.

## Phase 10 — Add HealthKit and iOS system integration

**Duration:** 3–5 days

### Step 10.1: HealthKit

- Explain the benefit before permission.
- Request only required read/write types.
- Write completed workout summaries.
- Prevent duplicate exports.
- Keep granular set data in the app.

### Step 10.2: System experience

- Rest-timer notifications.
- Live Activity for an active workout after the main flow is stable.
- App Intents for “Start today’s workout” and “Import clipboard workout” only if they remain reliable.
- Deep links for Today, active workout, and imported draft.

### Exit gate

Permissions are understandable, denial does not break the app, and the same workout is never exported twice.

## Phase 11 — Public-beta hardening

**Duration:** 1–2 weeks

### Step 11.1: Accessibility audit

- VoiceOver order and meaningful labels.
- Dynamic Type through accessibility sizes.
- Differentiate without color.
- Increased contrast and reduced transparency.
- Reduced motion.
- Minimum comfortable touch sizes.

### Step 11.2: Reliability and performance

- Launch and active-session restoration.
- Large workout histories.
- Background/foreground stress tests.
- Parser timeouts and provider outages.
- Database migrations from every beta version.
- Battery and notification behavior.

### Step 11.3: Production observability

- Crash reporting.
- Privacy-preserving funnel events: import started, review completed, workout started/completed.
- Parser quality and latency metrics without storing raw prompts in analytics.
- Cost alerts and rate limits.
- Support diagnostics users can explicitly share.

### Step 11.4: Small external TestFlight cohort

Recruit 10–30 lifters with different programming styles. Require each to complete at least two imported workouts.

Test whether a new user can:

- Understand the product without developer explanation.
- Import from their preferred AI.
- Resolve ambiguity correctly.
- Complete and later find the workout.

### Exit gate

All launch-blocking issues are resolved, crash-free workout sessions meet the target, and users demonstrate repeat import behavior.

## Phase 12 — App Store v1

**Duration:** 3–5 days plus review time

### Step 12.1: Product and legal preparation

- Final name and trademark/domain checks.
- Privacy policy and terms.
- Support URL and contact flow.
- App privacy disclosures.
- Health and fitness positioning that avoids medical claims.
- AI disclosure and safety copy.

### Step 12.2: App Store presentation

Tell one visual story across screenshots:

1. Bring the coach you already use.
2. Turn any AI response into a workout.
3. Resolve only what needs attention.
4. Train with a focused premium interface.
5. Return accurate results to your coach.

Create the App Store assets from the same visual system as the product, not as a separate marketing style.

### Step 12.3: Controlled release

- Use phased release.
- Monitor crashes, imports, provider latency/cost, and support requests.
- Do not add major features during launch stabilization.

## Post-v1 sequence

Build in this order only after repeat use is established:

1. Signed WorkoutPlan links and sharing.
2. OAuth-protected workout API.
3. ChatGPT plugin/MCP tools for direct draft creation and history lookup.
4. One additional AI-provider integration.
5. In-app coach using the same tools and schema.
6. Apple Watch companion.
7. Programs/templates and richer exercise media.
8. More advanced progression and recovery logic.

## Suggested issue/epic structure

### Epic 1: Product and UI contract

- PRD, sample corpus, UI states, high-fidelity prototype, usability test.

### Epic 2: Domain and persistence

- Schema, state machine, event log, restore, summary.

### Epic 3: Workout execution

- Today, focus mode, editing, rest timer, completion.

### Epic 4: AI import

- JSON Schema, backend adapter, validator, catalog matching, review.

### Epic 5: Cross-app capture

- Share Extension, App Group queue, deep links, duplicate handling.

### Epic 6: History and feedback

- History, exercise progress, coach-ready summaries, export.

### Epic 7: Public platform

- Auth, sync, privacy, HealthKit, observability.

### Epic 8: Launch

- Accessibility, external beta, App Store materials, phased release.

## Definition of done for every feature

A feature is complete only when:

- All designed states are implemented.
- Loading, empty, offline, failure, and recovery paths are handled.
- Unit and UI tests cover the critical behavior.
- Accessibility labels, Dynamic Type, and reduced motion are verified.
- Analytics and logging do not expose raw health or prompt data.
- It is tested on a physical iPhone.
- Product copy is final.
- The feature passes its measurable acceptance criteria.

## Immediate next action

Before creating the Xcode project, produce two documents:

1. `PRD.md` — locked MVP requirements, non-goals, user stories, and measurable acceptance criteria.
2. `UI-SPEC.md` — chosen visual direction, screen/state inventory, design tokens, component contracts, motion/haptics, and accessibility rules.

Once those are approved, initialize the repository and execute Phases 2–5 to reach the first manually trackable workout before connecting AI import.
