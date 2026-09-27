# Ascend Fit — Project Context

**Status:** Active development — canonical domain  
**Last updated:** September 5, 2026

This document is the stable source of truth for what Ascend Fit is, why it should exist, and the product and technical constraints that guide it. It intentionally does not repeat the build sequence in the [implementation roadmap](implementation-roadmap.md).

## Product thesis

Ascend Fit is an **AI-native workout execution layer** for iPhone. It turns a workout from ChatGPT, Claude, Gemini, or another trusted coach into a structured, editable plan, then becomes a focused and reliable companion while the user trains.

The initial wedge is not another automatic workout generator. The external AI remains the programming brain; Ascend Fit owns structured import, ambiguity review, gym execution, offline reliability, history, and clean performance feedback. An in-app coach may come later, after the core loop earns trust.

> Bring the coach you already trust. Import the workout once. Train without friction.

## Primary user job

When an existing trusted AI coach gives the user a workout, they need to bring it into a polished tracker with almost no retyping, execute every set quickly and reliably in the gym, and return accurate results to that coach.

The complete product loop is:

1. Receive a workout from an AI coach.
2. Import it in seconds.
3. Confirm only details that are genuinely ambiguous.
4. Train with a one-handed, interruption-safe tracker.
5. Preserve an accurate history.
6. Return a concise, structured completion summary to the coach.

## Non-negotiable principles

- **AI import is the hero.** It is prominent on the first screen and should take less than 30 seconds from paste or share to a ready workout.
- **Humans confirm ambiguity.** Ascend Fit does not silently invent exercises, units, weights, set schemes, or other training data.
- **Gym execution is local-first.** Starting, logging, resuming, and finishing an already imported workout must work offline. A weak connection cannot lose a completed set.
- **The interface is premium and one-handed.** Large targets, excellent contrast, haptics, minimal typing, and a focused dark gym mode are core behavior, not polish.
- **The workout contract is provider-neutral.** Every import path and future AI integration compiles into one canonical schema; providers remain adapters.
- **History belongs to the user.** Export, deletion, understandable privacy controls, and durable access to training history are first-class.

## Import ladder

Ascend Fit should work with every AI coach immediately, then add deeper integrations only where provider capabilities and user demand justify them.

### 1. Paste and Share Sheet — MVP

- Paste plain text copied from any chat.
- Accept shared text, pages, links, and supported attachments through an iOS Share Extension.
- Parse into the canonical schema, validate deterministically, resolve likely exercise matches, and open a human review.
- Preserve the source text for traceability.
- Let the user add the reviewed draft to Today.

This vendor-independent path is the hero MVP workflow.

### 2. Portable `WorkoutPlan v1` links and files — standardized JSON v0, broader sharing later

- Publish a small, versioned JSON interchange format. The September 26 user direction brings JSON paste/file upload forward as an offline v0; free-text parsing must produce the same contract.
- Support `.workoutplan` files and signed HTTPS universal links.
- Open an in-app preview when installed and a lightweight web preview otherwise.
- Allow users and compatible tools to share and import workouts without coupling to a model vendor.

### 3. Direct authenticated provider tools and plugins — later

- Expose narrowly scoped, authenticated backend tools for draft creation, recent workout lookup, exercise history, preferences, and import-link creation.
- Build provider-specific connectors as thin adapters over the same workout API.
- Require authorization, idempotency, and explicit control over which history a provider may access.
- Prove the public workout contract before building direct integrations.

### 4. In-app coach — later

- Add optional streaming chat only after the import-and-execution loop is stable.
- Give the coach controlled tool access to structured preferences and history.
- Send every generated workout through the same review and approval flow.

An in-app model API does **not** automatically inherit the user's consumer ChatGPT or Claude conversations. Context must be shared explicitly, supplied through an authorized external integration, or developed in a separate coaching thread inside Ascend Fit.

## Canonical workout contract

The canonical contract is the product's spine. Imported text, manual building, portable files, shared links, and direct provider tools must all produce the same versioned representation.

### Core entities

- **ExerciseDefinition:** Canonical name, aliases, equipment, movement pattern, muscles, modality, unilateral status, instructions, and media references.
- **WorkoutDraft:** Source, title, date, notes, exercises, parsing confidence, and unresolved items.
- **PlannedExercise:** Exercise reference, order, group or superset identifier, instructions, rest target, and progression note.
- **PlannedSet:** Set type, target reps, weight and unit, duration, distance, tempo, RPE/RIR target, and warm-up or working status.
- **WorkoutSession:** Start and end times, state, elapsed time, active exercise, and source draft.
- **CompletedSet:** Actual reps, weight and unit, duration or distance, RPE/RIR, completion time, notes, and skipped state.
- **WorkoutSummary:** Duration, volume, completed, modified, and skipped sets, personal records, and user notes.
- **ImportSource:** Paste/share/provider origin, source URL or conversation reference when available, and original text for traceability.

### Required set types

- Standard reps and weight
- Bodyweight and assisted bodyweight
- Warm-up sets
- AMRAP
- Timed sets
- Distance- or duration-based work
- Per-side and unilateral work
- Supersets and circuits
- Optional target RPE or RIR

### Import behavior

The importer sanitizes and classifies input, requests strict schema-conforming output, resolves exercise aliases, normalizes units without changing meaning, applies deterministic domain validation, assigns field-level confidence, and surfaces ambiguities for review. It saves both the structured result and original source. A draft never becomes today's workout automatically when uncertain fields remain.

## MVP scope

The personal MVP delivers the smallest complete AI workout → review → gym execution → history → coach feedback loop:

- Basic onboarding for units and essential preferences
- Paste import and iOS Share Extension
- AI-assisted extraction, deterministic validation, and confidence-aware review
- Manual corrections and basic manual workout creation
- Today, workout overview, and high-focus active workout mode
- Complete, edit, undo, skip, and add set actions
- Required set types, including unilateral work and supersets
- Rest timer, notifications, pause/resume, and crash or relaunch recovery
- Local history, workout detail, and previous exercise performance
- Coach-ready completion summary
- User export of structured workout data

### Explicit MVP non-goals

- In-app conversational coach
- Automatic workout programming or progression
- Direct authenticated ChatGPT, Claude, or Gemini integrations
- Apple Watch app
- Social features or trainer-client sharing
- Full exercise video library
- Complex recovery, readiness, or medical analysis
- Subscription or paywall
- Fitbod-class analytics and program depth

## Architecture defaults

- **Client:** Native Swift and SwiftUI for iPhone.
- **Session model:** A unidirectional `WorkoutSession` state machine for predictable complete, edit, undo, pause, timer, and recovery behavior.
- **Local truth:** Explicit local persistence and an append-only event log are authoritative during live workouts. Timers recover from timestamps rather than depending on a continuously running process.
- **Storage boundaries:** Repository interfaces isolate screens from persistence so later sync does not require a UI rewrite.
- **Share handoff:** App Groups transfer data safely from the Share Extension.
- **Model access:** Parsing calls go through a protected backend; provider keys never ship in the app binary.
- **Provider abstraction:** A server-side adapter such as `interpretWorkout(text, schema, userContext)` hides the initial model and supports future providers only when justified.
- **Backend:** Authenticated parsing first, with rate limits, usage budgets, abuse controls, idempotency, and observability before public release.
- **Cloud:** Account-backed sync follows the personal MVP. When added, it synchronizes idempotent events and resolves conflicts by event identity rather than overwriting an entire workout.
- **System integrations:** HealthKit, Live Activities, App Intents, and Apple Watch follow only after the phone tracking loop is stable.

## Experience and visual direction

### Current status

The first mockup was a basic flow preview and remains rejected as a final design.

The user-provided Claude Design handoff is now the approved implementation baseline. Its selected direction is **Lilac on ink-violet**: dark-first low-chroma surfaces, restrained violet accent, strong numeric typography, tonal grouping, native Apple patterns, and a calm one-handed workout hierarchy. Light appearances use warm violet-neutral surfaces and a darker violet for accessible accent text. The full implementation contract is in [UI-SPEC.md](UI-SPEC.md).

The Ascend Fit product name and wordmark remain placeholders until naming and brand work are resolved.

### Reference lessons

- **Hevy:** Learn from its efficient set logging and low-friction workout mechanics.
- **Ladder:** Learn from its immersive pacing and clear now/next hierarchy.
- **Gentler Streak:** Learn from its distinctive humanity, emotional warmth, and data storytelling.
- **SmartGym:** Learn from its native Apple polish and system coherence.
- **Fitbod:** Learn from its feature depth while avoiding its visual and interaction density.

These are lessons, not instructions to clone a competitor.

### Locked experience

1. **Planning, import, and history:** Spacious, calm surfaces with strong editorial hierarchy in the user's selected appearance.
2. **Gym execution:** A dark-first, high-contrast, high-focus mode optimized for one-handed use, fast set completion, glanceable now/next context, and reliable timers; an accessible light appearance is also supported.

[UI-SPEC.md](UI-SPEC.md) defines the approved tokens, components, interactions, states, scope adaptations, and accessibility behavior required before and during production UI implementation.

## Quality bars and targets

- Clear workouts are structurally correct at least 90% of the time in the early proof-of-concept corpus and greater than 95% by public beta.
- Median clear-workout import requires fewer than one manual correction.
- Median paste/share-to-ready time is under 30 seconds.
- Normal set completion requires one tap and no keyboard.
- Set logging feels immediate because persistence occurs locally before network work.
- Lost completed sets: zero across lock, backgrounding, force-quit, clock changes, poor connectivity, or backend outage.
- An interrupted workout resumes in under two seconds after launch.
- Parser evaluation covers tables, prose, Markdown, shorthand, units, ranges, warm-ups, AMRAP, circuits, unknown aliases, multiple workouts, contradictions, and malicious or irrelevant embedded text.
- Core state, undo, timers, Share Extension handoff, offline recovery, duplicate import prevention, unit conversion, accessibility, export, and deletion receive dedicated tests.

## Privacy, safety, and trust

- Ascend Fit is a workout tracking and coaching tool, not medical care; it does not diagnose injuries or guarantee outcomes.
- Serious symptoms or injury language receives clear escalation guidance.
- Only necessary context is sent to model providers, and the product explains what is transmitted.
- Private workouts, health data, and chat content are not used for training by default.
- Raw prompts and health data remain separate from product analytics.
- Provider access to history is narrow, authorized, and revocable.
- Users can inspect, export, and delete their data.
- AI-created or AI-parsed drafts require user confirmation before becoming today's workout.

## Core metrics

**North star:** Imported workouts completed per weekly active user.

Supporting measures:

- Time from pasted or shared text to ready workout
- Structured import success on clear inputs
- Exercise-match accuracy and ambiguity recall
- Manual corrections per import
- Imported workout start and completion rates
- Set-log response time and lost-set count
- Percentage of users who import a second workout within seven days
- Crash-free sessions and recovery success

Chat engagement is not a success metric. Ascend Fit succeeds when users spend less time managing the app and more time training.

## Principal risks

- **Exercise alias matching:** Real inputs name the same movement in inconsistent ways. A curated catalog, rich aliases, confidence thresholds, and custom or text-only fallback paths are necessary.
- **Ambiguous source text:** Missing units, contradictory instructions, multiple workouts, and unconventional shorthand can produce plausible but wrong output. Field-level confidence and human confirmation are mandatory.
- **Timer and session reliability:** Backgrounding, device lock, termination, time changes, and offline use threaten the live workout. Timestamp-derived timers, immediate local events, recovery tests, and undoable actions must be designed into the domain.
- **Scope creep:** Coaching, watch, video, social, readiness, and advanced analytics can distract from the import-to-completion loop. They remain deferred until the core loop proves retention.
- **Cross-provider expectations:** Users may assume direct access to consumer chat history or identical capabilities across providers. The product must explain permission boundaries and keep integrations behind a common, provider-neutral contract.
- **Model correctness and cost:** Structured output reduces syntax errors but not domain mistakes. Deterministic validation, evaluation corpora, budgets, observability, and provider abstraction remain required.
- **Design convergence:** A compelling moodboard can be mistaken for a complete UI contract. Real-device prototypes and explicit UI approval must precede production screens.

## Open decisions

These require explicit resolution before or during product-definition work:

- Final product name, wordmark, and brand direction
- Approved visual direction and complete UI contract
- Minimum supported iOS version
- Strength-only boundary versus initial cardio or mobility support
- Anonymous local mode versus Sign in with Apple for the first personal build
- Hosted parsing only versus optional bring-your-own-key during private alpha
- Exact timing and conflict policy for account-backed cloud sync
- Initial model provider and model-selection criteria
- Exercise catalog seed size, licensing, and custom-exercise behavior
- Public-launch pricing and monetization hypothesis
- What user context direct provider tools may read and how consent is communicated

## Document relationships

- **[PROJECT.md](PROJECT.md):** Why Ascend Fit exists, what it must do, and the durable product and architecture constraints.
- **[implementation-roadmap.md](implementation-roadmap.md):** The ordered phases, exit gates, and delivery sequence.
- **[PRD.md](PRD.md):** The personal-MVP requirements, acceptance criteria, boundaries, and measurable outcomes; currently awaiting approval.
- **[UI-SPEC.md](UI-SPEC.md):** The approved visual, interaction, state, accessibility, and responsive behavior contract derived from the supplied handoff.

Changes to durable product intent belong here. Execution progress belongs in [PLAN.md](PLAN.md). Build sequencing should be updated in the roadmap only when the delivery strategy itself changes.
