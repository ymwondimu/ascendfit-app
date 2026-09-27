# Ascend Fit — Personal MVP Product Requirements

**Status:** Draft for approval  
**Version:** 0.1  
**Date:** September 5, 2026

## Purpose

This document defines the first complete, testable version of Ascend Fit. It converts the durable product context in [PROJECT.md](PROJECT.md) into requirements and acceptance criteria. Build order remains in [implementation-roadmap.md](implementation-roadmap.md), while current progress remains in [PLAN.md](PLAN.md).

## Product promise

Ascend Fit lets a strength trainee take a workout from an AI coach they already trust, turn it into a structured plan with almost no retyping, execute it reliably in the gym, and return an accurate result to that coach.

The personal MVP succeeds only when this entire loop works on one iPhone:

> Import → review ambiguity → train offline → recover from interruption → inspect history → copy a coach-ready summary.

## Target user and primary scenario

The initial user is a strength trainee who already asks ChatGPT, Claude, Gemini, or another AI coach to write workouts but does not want to track sets in chat or manually rebuild the workout in a conventional fitness app.

The primary scenario is a same-day workout:

1. The user receives a workout as text from an external AI coach.
2. They paste or share it into Ascend Fit.
3. Ascend Fit structures clear details and asks about uncertain ones.
4. The user adds the reviewed workout to Today.
5. They complete the workout with one-handed controls, including rest periods and interruptions.
6. Ascend Fit saves exact results and produces a summary the user can paste back to the coach.

## Release boundary

### Included in the personal MVP

- Native iPhone app using Swift and SwiftUI
- Anonymous, local-first onboarding with units and basic preferences
- Paste import and iOS Share Extension capture
- Protected backend interpretation of workout text
- Deterministic schema and domain validation after model extraction
- Confidence-aware import review with explicit ambiguity resolution
- Basic manual workout creation and correction
- Today, workout overview, and resume-active-workout states
- One-handed gym focus mode
- Complete, edit, undo, skip, and add-set actions
- Warm-up, weighted, bodyweight, assisted, AMRAP, timed, distance/duration, unilateral, drop/failure, superset, and circuit structures
- Rest timer with pause, extend, skip, notification, and relaunch recovery
- Immediate local persistence and append-only session events
- Local workout history and previous exercise performance
- Deterministic workout completion summary
- Coach-ready plain-text summary
- User-owned JSON and CSV export

### Explicit non-goals

- Automatic workout programming or progression
- In-app conversational coach
- Direct authenticated ChatGPT, Claude, or Gemini tools/plugins
- Importing a user's existing consumer AI conversation history automatically
- Accounts or multi-device cloud sync
- HealthKit
- Apple Watch
- Social features or trainer-client sharing
- Full exercise video library
- Advanced recovery, readiness, or medical analysis
- Subscription, paywall, or monetization flow
- Fitbod-class program depth or analytics

These are deferred until the import-to-completion loop is reliable and repeatedly useful.

## Starting product decisions

- **Platform:** Native iPhone app with SwiftUI.
- **Minimum OS:** iOS 18 is the provisional deployment target.
- **Training scope:** Strength training first, with duration-based accessories; not a general cardio platform.
- **Identity:** Anonymous local mode for the personal MVP; Sign in with Apple enters before public beta.
- **AI access:** Hosted interpretation through a protected backend; no provider key in the app and no bring-your-own-key flow in the personal MVP.
- **Provider strategy:** One initial model behind a provider-neutral adapter.
- **Cloud:** Active workouts remain local-first; account-backed sync follows the personal MVP.
- **Commercial model:** No paywall during personal use and early TestFlight validation.
- **Brand:** “Ascend Fit” and its wordmark remain working placeholders.

## Canonical workout contract

All imported, shared, and manually built workouts use one versioned `WorkoutPlan v1` contract. The client domain does not contain model-provider types.

### Required entities

- `ExerciseDefinition`
- `WorkoutDraft`
- `PlannedWorkout`
- `PlannedExercise`
- `PlannedSet`
- `WorkoutSession`
- `CompletedSet`
- `SessionEvent`
- `WorkoutSummary`
- `ImportSource`
- `UnresolvedField`

Every stored entity and event uses a stable UUID. The original import text is retained with its draft for traceability and excluded from ordinary analytics and logs.

### Required set representations

- Warm-up
- Standard weighted
- Bodyweight
- Assisted bodyweight
- AMRAP
- Timed
- Distance
- Drop set
- Failure set
- Bilateral, alternating, and per-side/unilateral work
- Superset and circuit grouping
- Optional RPE or RIR targets and actuals

## Functional requirements

### Onboarding and preferences

- **ONB-01:** A first-time user can choose pounds or kilograms and enter the app without creating an account.
- **ONB-02:** The selected unit preference persists across relaunches and can be changed later.
- **ONB-03:** The app explains that Ascend Fit tracks workouts and is not medical care.

### Workout capture and import

September 26 user direction prioritizes an offline v0: standardized WorkoutPlan v1 JSON pasted or uploaded, deterministic validation, review, and explicit Today acceptance. Free-text AI extraction and Share Sheet capture follow as adapters into that same contract. This sequencing change does not imply those broader requirements are complete.

- **IMP-01:** A user can paste plain workout text into an import capture screen.
- **IMP-02:** A user can send supported text or a shared item to Ascend Fit through the iOS Share Sheet.
- **IMP-03:** Import preserves source type and original text without placing raw text in ordinary logs or analytics.
- **IMP-04:** The backend rejects oversized, empty, irrelevant, or unsupported input with an actionable response.
- **IMP-05:** The interpreter classifies whether input contains zero, one, or multiple workouts.
- **IMP-06:** Clear input is converted into `WorkoutPlan v1` through strict structured output and deterministic validation.
- **IMP-07:** Exercise names are matched through a curated canonical catalog and alias table.
- **IMP-08:** A low-confidence exercise match is never silently forced; the user can select a match, create a custom exercise, or preserve a text-only exercise.
- **IMP-09:** Missing units, conflicting values, unsupported structures, and other uncertainties appear as field-level decisions in review.
- **IMP-10:** A user can correct exercise mapping, order, grouping, sets, reps, load, unit, rest, duration, distance, and notes before acceptance.
- **IMP-11:** A draft with unresolved required fields cannot become today's workout.
- **IMP-12:** Repeated ingestion of the same shared payload does not create duplicate drafts.
- **IMP-13:** A user can cancel and retry an import without corrupting an existing workout.

### Manual planning and Today

- **PLAN-01:** A user can create a basic workout manually without a network connection.
- **PLAN-02:** A user can add, remove, reorder, and group exercises and sets before starting.
- **PLAN-03:** Today clearly presents the primary import action when no workout exists.
- **PLAN-04:** Today shows a reviewed planned workout with title, estimated duration, exercises, and a start action.
- **PLAN-05:** Today prioritizes resume when an unfinished active workout exists.

### Workout execution

- **EXEC-01:** A user can start a reviewed or manually created workout without network access.
- **EXEC-02:** Gym mode shows the current exercise, current set, target values, and previous performance at a glance.
- **EXEC-03:** A normal set can be completed with one thumb, one tap, and no keyboard.
- **EXEC-04:** A user can edit actual values, undo an accidental completion, skip a set or exercise, add a set, and replace an exercise.
- **EXEC-05:** Superset and circuit progression preserves group order and makes the next movement clear.
- **EXEC-06:** Completing a set persists its event locally before the interface reports success.
- **EXEC-07:** A user can pause and resume a workout without changing recorded elapsed workout time incorrectly.
- **EXEC-08:** A user can end or discard an unfinished workout only through an explicit destructive confirmation.
- **EXEC-09:** The active session restores after backgrounding, device lock, force-quit, or relaunch.
- **EXEC-10:** The entire active workout can be completed with no network connection.

### Rest timing

- **REST-01:** Completing an eligible set starts its configured rest period automatically.
- **REST-02:** A user can pause, extend, skip, or disable the current rest period.
- **REST-03:** Rest completion produces an accessible in-app signal and a local notification when backgrounded or locked.
- **REST-04:** Rest state restores from a stored deadline after relaunch and remains correct across wall-clock or timezone changes.

### Completion, history, and export

- **HIST-01:** Finishing a workout creates a summary with duration, completed, modified, and skipped sets, total volume where meaningful, and user notes.
- **HIST-02:** A user can find prior workouts chronologically and inspect exact completed-set details.
- **HIST-03:** A user can view the most recent relevant performance for an exercise.
- **HIST-04:** A user can copy a deterministic coach-ready summary of planned versus actual work, changes, RPE/RIR, notes, and records.
- **HIST-05:** Pain or discomfort notes are reproduced exactly and never interpreted as a diagnosis.
- **HIST-06:** A user can export their workout data as versioned JSON and practical CSV.

### Reliability, privacy, and accessibility

- **QUAL-01:** No confirmed completed set is lost across backgrounding, force-quit, device lock, network loss, or backend outage.
- **QUAL-02:** Active-session restoration completes in under two seconds on supported devices under normal local test conditions.
- **QUAL-03:** Primary controls provide at least a 44-point comfortable target and do not depend on color alone.
- **QUAL-04:** Critical flows support VoiceOver, Dynamic Type through accessibility sizes, increased contrast, and reduced motion.
- **QUAL-05:** Raw workout or prompt text is absent from analytics, crash metadata, and normal application logs.
- **QUAL-06:** Users can inspect and delete local workout and import data.
- **QUAL-07:** AI-created or parsed work always remains a draft until explicit user approval.

## Core experience states

The production UI contract must account for these states before screen implementation:

- **Today:** first launch, no workout, planned workout, active workout, completed workout, offline.
- **Import:** empty, reading, matching, clear success, unresolved fields, unknown exercise, missing unit, multiple workouts, failure, duplicate, offline queue.
- **Workout:** not started, active, resting, paused, edited target, skipped item, superset transition, offline, personal record, finish confirmation, discarded, relaunch recovery.
- **History:** empty, workout list/calendar, detail, exercise history, progress with insufficient data.

## Acceptance criteria

### Product loop

- A representative clear workout can be pasted, reviewed, added to Today, completed offline, found in history, and summarized without developer intervention.
- The user completes at least 10 real gym sessions in the personal build without returning to another app for core set tracking.
- At least three manually created workouts are completed before AI import is connected to the tracker.

### Import quality

- The initial proof-of-concept parses at least 90% of clear corpus workouts without structural correction.
- Public-beta readiness requires greater than 95% structural correctness on clear inputs.
- Median manual corrections for a clear import are fewer than one.
- Median paste/share-to-ready time is under 30 seconds.
- Every intentionally ambiguous corpus case is surfaced for confirmation rather than guessed silently.
- At least 20 representative clear workouts can be pasted and started without structural correction before the importer phase exits.

### Gym reliability

- Normal set completion is one tap with no keyboard.
- Common rep or weight adjustment takes no more than two taps before value entry.
- Confirmed set logging feels immediate and writes locally before any network operation.
- Automated interruption tests and real-device exercises produce zero lost completed sets.
- A relaunch during rest restores the correct session and deadline-derived remaining time.

### Accessibility and safety

- All primary actions have meaningful accessibility labels and comfortable targets.
- Essential status remains understandable without color.
- Large text does not hide the current set or primary completion action.
- Reduced motion removes nonessential movement without hiding state changes.
- Safety, privacy, and AI-transmission language is understandable during onboarding and import.

## Test strategy

Tests should be small, deterministic, and non-redundant. Prefer one test per important behavior or boundary over broad duplicated matrices.

- **Domain unit tests:** Value validation, set variants, session transitions, undo, summaries, and deadline-derived rest state.
- **Persistence tests:** Event append, reconstruction, migration, idempotent fixture import, and deletion.
- **Parser contract tests:** Strict schema decoding, deterministic validation, alias resolution, ambiguity detection, and unsupported-version handling.
- **Backend tests:** Input limits, provider-adapter contract, error mapping, redaction, idempotency, and health check.
- **UI tests:** Only the critical import-to-start and complete-set flows; detailed state logic stays in unit tests.
- **Snapshot tests:** A small set of anchor components across light/dark and one accessibility text size, avoiding combinatorial duplication.
- **Manual checks:** Physical-iPhone one-handed use, device lock, notification timing, force-quit recovery, bright gym lighting, and real Share Sheet hosts.

## Import evaluation corpus

Before parser implementation, assemble 50–100 anonymized real workout outputs from at least ChatGPT, Claude, and Gemini. The permanent corpus must cover:

- Bullets, tables, prose, Markdown, and shorthand
- Pounds, kilograms, mixed units, and missing units
- Rep ranges, RPE/RIR, AMRAP, warm-up ramps, drop sets, and failure sets
- Supersets, circuits, unilateral movements, duration, and distance
- Unknown exercises and common aliases
- Multiple workouts in one message
- Contradictory, incomplete, irrelevant, and adversarial source text

Synthetic fixtures may cover edge cases but do not replace the real corpus. Private information must be removed before examples enter version control.

## Metrics

**North star:** Imported workouts completed per weekly active user.

Track without raw prompt or health content:

- Import started, review completed, workout started, and workout completed
- Time to ready
- Corrections per import
- Exercise-match accuracy and ambiguity recall in the evaluation harness
- Second import within seven days
- Crash-free workout sessions
- Restoration success and lost-set count
- Parser latency and estimated provider cost

## Approval gate

This PRD is approved when the product promise, personal-MVP boundary, starting decisions, functional requirements, and measurable acceptance criteria are accepted. Approval unlocks visual-direction exploration and `UI-SPEC.md`; production UI implementation still waits for the UI contract itself to be approved.

Open items that do not block the personal-MVP contract are tracked in [PROJECT.md](PROJECT.md), including final naming/brand, public-launch pricing, long-term sync policy, and direct-provider permission design.
