# Ascend Fit — UI Implementation Contract

**Status:** Campaign redesign approved for implementation; the original handoff remains a behavior reference
**Version:** 2.0
**Date:** September 27, 2026
**Source:** [Final Campaign mockup](Design/Campaign/campaign-native-sets.png) and [interaction notes](Design/Campaign/README.md)

## Purpose and authority

This document defines the native SwiftUI interface contract. The September 27 Campaign direction replaces the original Lilac-on-ink-violet visual treatment; the original handoff still describes behavior and states that the new mockup does not depict.

When sources disagree, use this order:

1. [PRD.md](PRD.md) controls product scope and required behavior.
2. [PROJECT.md](PROJECT.md) controls durable principles and architecture constraints.
3. This document controls UI composition and interaction behavior.
4. The [Campaign mockup](Design/Campaign/campaign-native-sets.png) and [interaction notes](Design/Campaign/README.md) control visual fidelity and tactile behavior.
5. The [original handoff boards](Design/Handoff/ClaudeDesign/screens/) fill gaps in screen coverage without overriding Campaign styling.

Native platform behavior, accessibility, data safety, and truthful product states take precedence over pixel matching.

## Selected direction

The implementation uses the user-approved **Campaign** direction:

- Dark-first ink and charcoal surfaces, with citron reserved for the immediate primary action and small orientation labels.
- Lilac identifies current sets, secondary controls, selections, and progress details.
- A single native system font family carries every screen. Numeric values use tabular figures; typography and exercise order provide hierarchy.
- Primary buttons have a restrained satin highlight, soft contact shadow, and subtle pressed response. They should feel weighted without glowing or jumping.
- Tonal cards and compact steppers keep gym controls dense enough for one-handed use while preserving 56-point hit regions.
- Locally available movement imagery may enrich Today or an active exercise only when it accurately depicts that movement. Every screen needs a strong no-photo treatment.
- Keep native SF Symbols, sheets, navigation, Dynamic Type, VoiceOver, and light appearance support.

The active screen keeps a stacked exercise hero with compact paired steppers, an integrated list of **every** set, and a Log set action fixed to the bottom safe area. The set rows use bare numbers (`1`, `2`, `3`) without repeating “Set.” Scrolling must never move the Log set action.

After the final working set of a rep-based exercise, show a short optional sheet asking “How many more reps could you have done?” Clarify that only reps with good form count. Offer `0`, `1`, `2`, `3`, `4+`, and Skip. Keep the acronym RPE out of this main flow; imported RPE targets and advanced set editing remain available. Store `4+` as a lower bound rather than an exact four.

## MVP scope adaptation

The handoff contains future product concepts in addition to the personal MVP. Visual references do not expand release scope.

### Implement in the personal MVP

- Onboarding and units
- Today: empty, queued, active/resume, completed, and offline states
- Paste/import capture and parsing progress
- Confidence-aware import review and workout preview
- Manual workout construction and correction
- Active workout: idle, resting, paused, PR, skipped/edited, offline, and recovery states
- Rest bar and expanded rest sheet
- Workout completion and coach-ready share/copy
- History, session detail, and exercise detail
- Settings and local data controls
- Dark and light appearance

### Preserve as later-phase references only

- Conversational Trainer screen and provider picker
- Bring-your-own API key and Connections flows
- Automatic provider fallback and rate-limit chat recovery
- Direct sending of results to an authoring provider
- Live Activity and Dynamic Island

For the personal MVP, “Share with trainer” means the system share sheet or copying a deterministic summary. It does not post through a connected provider.

## Navigation

Use a native tab shell with two MVP destinations:

1. **Today** — workout import, manual creation, queued workout, and active-workout resume.
2. **History** — workout history and exercise progress.

Settings opens from the Today avatar. Do not ship a disabled or placeholder Trainer tab. A future Coach destination may join the tab shell only when conversational coaching enters scope.

Active Workout and import review are focused destinations pushed or presented above the tab shell. They do not show the tab bar.

## Color tokens

Implement semantic colors through `AppTheme` with light and dark appearances. Views reference semantic names only.

| Token | Dark | Light | Use |
|---|---|---|---|
| `background` | `#090E12` | `#F3F4EF` | Screen background |
| `surfacePrimary` | `#161C21` | `#FFFFFF` | Grouped surfaces, steppers, sheets |
| `surfaceSecondary` | `#23282F` | `#E8E9E4` | Chips, secondary controls, rest bar |
| `surfaceTertiary` | `#31343D` | `#DADCD8` | Raised tonal controls |
| `contentPrimary` | `#F7F8F4` | `#11171B` | Primary content |
| `contentSecondary` | 68% primary | 66% primary | Secondary content and cues |
| `contentTertiary` | 46% primary | 47% primary | Captions, units, section labels |
| `actionFill` | `#DBF165` | `#DBF165` | Primary action and immediate orientation |
| `accentContent` | `#BCA9FF` | `#6043B3` | Lilac secondary emphasis and current set |
| `onAccent` | `#13190D` | `#13190D` | Content on citron action |
| `accentTint10` | 10% lilac | 10% lilac | Current rows and subtle selection |
| `warning` | semantic amber | semantic amber | Import ambiguity only; pair with icon/text |
| `destructive` | semantic red | semantic red | Destructive confirmations only |

The warning and destructive roles are additions required by product semantics. The primary accent must not imply an error.

## Typography

Use Dynamic Type-aware system styles wherever possible. Use `@ScaledMetric` for custom display sizes and preserve the hierarchy at accessibility sizes.

| Style | Base specification | Use |
|---|---|---|
| Hero | SF Pro Rounded, 72/76, semibold, −2%, tabular when numeric | Current load and reps |
| Display | SF Pro Rounded, 44/48, semibold, −2% | 1RM and major statistics |
| Metric | SF Pro Rounded, 22/26, semibold, tabular where numeric | Inline metrics and stepper values |
| Large title | SF Pro, 34/41, bold, −2% | Today, History, Settings |
| Title | SF Pro, 22/28, semibold, −1% | Exercise and sheet titles |
| Workout title | SF Pro, 30, semibold | Planned workout titles |
| Primary button | SF Pro, 19, semibold | Main action |
| Secondary button | SF Pro, 16, semibold | Secondary action |
| Body | SF Pro, 15/20, regular | Standard content |
| Coach cue | SF Pro, 14, regular italic | Imported instructions |
| Caption | SF Pro, 13/18, regular | Supporting metadata |
| Section label | SF Pro, 11, regular, uppercase, +6% | Group labels |
| Elapsed | SF Mono, 15, regular, +2%, tabular | Elapsed workout time |
| Timer | SF Pro Rounded, 26/72, semibold, tabular | Rest bar and sheet |

At large accessibility sizes, the hero may reduce from 72 points to preserve the current value and primary action, but it must remain the strongest element. Never truncate load, reps, timer, or exercise names without providing the full accessible value.

## Spacing, shape, and sizing

- Spacing scale: 4, 8, 12, 16, 20, 24, 28, 32.
- Standard horizontal screen inset: 20.
- Major section gap: 28–32.
- Bottom safe-area padding: at least 12 beyond system inset; mock reference is 34 total.
- Set row height: 46 visual, with at least 56-point interactive container in gym mode.
- Settings row: 60.
- History row: 64 minimum.
- Small pill radius: capsule.
- Chip radius: 14–15.
- Control radius: 18.
- Grouped surface radius: 20.
- Sheet top radius: system presentation radius; 38-point visual reference.
- Navigation target: at least 44×44.
- In-session target: at least 56×56.
- Primary button: 60 high.
- Stepper decrement/increment zones: 64×64.

Use tonal grouping and inset dividers. The restrained primary-action shadow is decorative; ordinary cards stay flat.

## Core component contracts

### Primary action

- Full available width, 60 high, 22 radius.
- Quiet citron gradient with `onAccent` label, a fine top-edge highlight and short downward shadow.
- Exactly one primary filled action per screen or sheet.
- Press feedback: settle to 0.99 scale and shorten the shadow; respect Reduce Motion.
- Disabled state uses a tonal surface and explicit accessibility state; do not rely on opacity alone.

### Secondary action

- 48–60 high, 14–18 radius, `surfaceSecondary` background.
- Primary content label; no outline or shadow.

### Numeric stepper

- Compact tonal track with distinct circular decrement/increment surfaces.
- Each visible circle sits within an independent target at least 56 points high/wide in gym mode.
- Weight defaults to ±5 lb or configured metric increment; reps use ±1.
- Long press repeats with controlled acceleration.
- Tapping the value opens a purpose-built numeric editor.
- VoiceOver exposes decrement, current value/unit, and increment as clear actions.

### Set pill

- 30 high, capsule shape, 14-point rounded semibold numerals.
- Default uses `surfaceSecondary`; highlighted top set uses `accentContent`; skipped uses tertiary content.

### Set row

- Columns: bare set number, target or actual, state.
- Done uses secondary content plus accent checkmark.
- Current uses `accentTint10`, accent index, and primary values.
- Pending uses tertiary content and an explicit “Up next” label.
- Show all sets for the current exercise in a single section, including completed and upcoming rows; let the screen scroll under the fixed Log set dock.
- Swipe left skips; swipe right adds a set. Both actions also exist in an accessible context menu.
- Destructive swipe requires confirmation when it would remove recorded data.

### Provenance badge

- 24 high, capsule, subtle tonal fill, 12-point secondary label.
- Text-only source such as “from Claude · today”; no provider logos and no implication of an authenticated integration.

### Rest timer

- Ring drains clockwise from 12 o'clock using accent over a 12%-content track.
- Collapsed rest bar is 72 high, floats 12 points above the bottom safe area, and contains ring, time, next set, extend, and skip.
- Expanded rest sheet uses a 240-point ring, large tabular time, ±30-second actions, up-next content, and a single primary Skip Rest action.
- Remaining time derives from stored dates/monotonic elapsed state, not a decrementing persisted counter.
- Expiration gives one success haptic. Sound is off by default.

### Empty, loading, offline, warning, and error states

- State title names the condition without blame.
- Supporting text says what is preserved and what the user can do next.
- Import ambiguity uses warm warning treatment, a field label, and explicit choices.
- Provider/backend failure never blocks manual tracking or an already imported workout.
- Offline state is persistent but quiet; it must not resemble failure when local actions remain available.

## Screen contracts

### Onboarding

- One short value proposition and explicit “not medical care” language.
- Unit choice is the only required setup decision.
- Continue enters local mode without account creation.
- Privacy detail is available before continuing.

### Today — empty

- Header follows the supplied Today design: date, large title, and settings avatar.
- Primary message is calm and factual.
- Primary action is **Import workout**.
- Secondary action is **Build manually**.
- Supporting copy may explain paste/share from ChatGPT, Claude, or Gemini without implying direct integration.
- The week strip remains near the bottom when history exists; omit or explain it on true first launch.

This intentionally replaces the handoff's “Ask your trainer” action because conversational coaching is not in the personal MVP.

### Today — planned

- Use the supplied queued-workout hero composition.
- Show provenance, workout title, exercise count, estimated duration, and imported coach note.
- Primary action is Start; secondary action is Preview Workout.
- Show the week strip and most recent workout summary below.

### Today — active

- Resume is the dominant action.
- Show elapsed time, completed/total sets, and current exercise.
- Starting a second workout requires resolving the active session first.

### Import capture

- Large paste region with explicit paste action; do not read clipboard contents before user action.
- Support text and shared-item provenance appear quietly.
- Parsing stages: Reading → Matching exercises → Checking details.
- Cancel remains available and preserves any prior planned or active workout.
- Offline capture may queue source locally but must state that interpretation waits for connectivity.

### Import review and workout preview

- Base layout follows the supplied Workout Preview board.
- Header includes close and Edit All.
- Show provenance, title, exercise/set count, estimated duration, and source note.
- Clear exercises use compact rows and set pills.
- Unresolved fields appear inline directly beneath the affected exercise or set, not in a detached error summary.
- Each unresolved row states the source phrase, the uncertain field, and 2–3 concrete choices plus manual entry where appropriate.
- Unknown exercises offer Match Existing, Create Custom, and Keep as Text.
- Sticky primary action reads **Add to Today** after import and **Save workout** for manual editing.
- The primary action remains disabled while required unresolved fields remain, with an accessible explanation.

### Manual workout builder

- Reuse preview rows and editors rather than creating a separate visual language.
- Empty builder starts with workout title and Add Exercise.
- Exercise search, custom exercise, set type, values, rest, grouping, and notes are progressively disclosed.
- Reorder and delete are available through native edit mode and accessible actions.

### Active workout — idle

- Match selected handoff variant 1a.
- Top row: elapsed time, exercise progress, native overflow menu.
- Exercise title and muscle groups follow.
- Short exercise cues appear beneath the title in smaller secondary text. Use exercise notes when available, otherwise catalog cues or the exercise description.
- A compact “Rest between sets” control opens a native editor with seconds entry, quick presets, and Off. It changes automatic rest for the remaining sets of the current exercise in this workout, including added sets, and persists through relaunch.
- The 72-point load × reps hero is readable at arm's length.
- Status and previous performance remain subordinate.
- Paired weight and reps steppers sit above the single Log Set action.
- Imported exercise cue follows the primary action.
- Set ledger anchors toward the bottom without hiding the primary action at large text sizes.
- Overflow menu: Replace Exercise, Edit Plan, Pause/Resume, End Workout.

### Active workout — resting

- Completed rows update immediately; next set becomes current.
- Hero and steppers dim to 55% while the Rest Bar owns the accent.
- Tapping time or dragging upward opens the Rest Sheet.
- At expiration, dismiss rest state, restore full emphasis, and announce “Rest complete. Set N is next.”

### Active workout — PR

- Use the supplied restrained treatment: one New Best capsule, accent hero values, comparison to the prior record, and tinted recorded row.
- One pulse animation is allowed; no confetti, sound, or repeated celebration.
- If this was the final set, Next Exercise or Finish Workout becomes the primary action.

### Workout complete

- Follow the supplied completion hierarchy: factual heading, duration/volume/sets, records, deviations, and optional note.
- Primary action is **Share coach update**; it opens the system share sheet for deterministic text.
- Secondary action is Done.
- Pain/discomfort notes remain verbatim and are not analyzed in this screen.

### History

- Use the supplied 12-week heat strip and chronological rows.
- Heat intensity represents volume quartiles, not streaks.
- Rows show date, title, provenance, duration, volume, set count, and PR count when present.
- Empty history explains that completed workouts appear here and links back to Today.

### Session detail

- Show exact completed sets, skipped/changed items, elapsed duration, notes, and coach-ready summary actions.
- Preserve source and planned-versus-actual distinctions.
- Export and delete are available through the overflow menu; delete requires confirmation.

### Exercise detail

- Follow the supplied chart composition: estimated 1RM, thin line without gridlines, latest accent point, volume bars, and best-set rows.
- Low-data state shows recent exact sets instead of manufacturing a trend.
- Chart scrubbing announces one date/value pair and supplies a textual summary for VoiceOver.

### Settings and local data

- Unit preference, rest defaults, appearance, notifications, privacy explanation, export, and delete-local-data.
- Do not show provider API keys or connection status in the personal MVP.

## Motion and feedback

- Default spring: response 0.35, damping fraction 0.85.
- Log Set: current hero moves up 24 points and fades; next target enters from below; checkmark appears over 120 ms.
- Rest Bar enters from the bottom over approximately 0.45 seconds.
- Rest Bar and Rest Sheet ring may use matched geometry.
- PR values tint over 0.25 seconds; one ring pulse lasts 1.2 seconds.
- Completion metrics may count up once over 0.6 seconds.
- Reduced Motion replaces translation, scaling, matched-geometry, pulses, and counting with short opacity changes or immediate updates.
- Haptics: selection for stepper, success for completed set/rest end, warning for unresolved destructive actions, and error only for failed local operations.

## Accessibility

- Support VoiceOver and Dynamic Type through accessibility sizes.
- Maintain logical reading order independent of visual overlay order.
- Every icon-only control has a label and, where needed, a hint.
- Touch targets meet 44 points globally and 56 points for gym actions.
- Status never depends on color alone; use labels, shapes, and symbols.
- Accent text in light mode uses `accentContent`, not the lighter fill color.
- Charts include textual summaries and selectable values.
- Timers announce meaningful minute/second changes without speaking every tick.
- Swipe-only operations have buttons or accessibility actions.
- Focus moves to the next set after Log Set and to the Rest Sheet title when expanded.
- High-priority content remains visible at large text sizes; layouts may stack instead of scaling everything down.

## Content rules

- Tone is calm, direct, and factual.
- Do not nag, shame, diagnose, or promise results.
- Use “coach” for the external source in product copy; reserve “Trainer” as a future in-app feature name.
- Provenance labels describe how content arrived, not an affiliation.
- Preserve imported cues verbatim when safe; distinguish them visually from app instructions.
- Error messages say what was saved and offer a next action.

## Implementation notes

- Build with SwiftUI and native navigation, menus, sheets, alerts, swipe actions, and sharing.
- Use SF Symbols only for MVP icons; the handoff's text placeholders are not assets.
- Use `Canvas` or Swift Charts for lightweight charting only after history data exists.
- Keep design primitives in a `DesignSystem` boundary and feature-specific composition in feature modules.
- Keep active-workout rendering driven by the domain state machine; views do not own session truth.
- Store display-ready source provenance separately from provider adapter identifiers.

## Lean UI verification

Avoid a combinatorial snapshot suite. Use:

- One dark and one light snapshot for the selected Active Workout layout.
- One snapshot for active rest state.
- One snapshot for import review with an ambiguity.
- One snapshot for Today planned.
- One accessibility-size snapshot for the active workout.
- Two UI smoke tests: import review → Add to Today → Start, and Log Set → rest → next set.

Everything else should be verified through small state/domain tests plus targeted manual checks on a physical iPhone.

## Handoff gaps resolved by this contract

The supplied boards do not show every MVP requirement. This specification adds the missing onboarding, import capture, ambiguity resolution, active/resume Today state, manual builder, offline/error/recovery states, session detail, settings/data controls, and accessibility adaptations while retaining the supplied visual language.

The supplied Trainer, Connections, and Live Activity boards remain useful future references but are not acceptance criteria for the personal MVP.
