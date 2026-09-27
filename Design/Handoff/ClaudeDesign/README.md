# Handoff: AscendFit — iOS 18 workout tracker UI

## Overview
AscendFit turns a conversation with an AI trainer (Claude, ChatGPT, Gemini, or the built-in trainer) into a trackable gym session. This package covers the full UI: Active Workout (idle / resting / PR), Today, Workout Preview, Trainer chat (card, provider picker, rate-limit error), Workout Complete, History + Exercise Detail, Connections + ChatGPT connect sheet, Lock Screen Live Activity + Dynamic Island, and a token/type/component sheet. Dark-first, with light mode for Active Workout, Today, and History.

## About the design files
`AscendFit.dc.html` (+ `ios-frame.jsx`, `support.js`) is a **design reference built in HTML** — a canvas of annotated iPhone mockups, not production code. Recreate these screens in the **SwiftUI / iOS 18** codebase using native materials, grouped backgrounds, SF Symbols, sheets (`presentationDetents`), Swift Charts, ActivityKit, and App Intents. Every screen is inline-styled with literal values, so any color / size / spacing can be read directly from the HTML.

Open the HTML in a browser to see all screens. Section **1** is the full design (already recolored to the chosen lilac palette). Section **2** shows the rejected palette explorations (2a sage, 2b ivory) — ignore them; **2c lilac is the chosen scheme** and is what section 1 uses.

## Fidelity
**High-fidelity.** Colors, type sizes, spacing, radii, and copy are final. Recreate pixel-accurately. Fonts render as system fallbacks in the browser; on device use SF Pro Rounded for numerals and SF Pro Text elsewhere.

## Design principles (must be visible in the build)
- Readable from arm's length: current set weight × reps is the largest element (72 pt). Everything secondary is small and quiet.
- One thumb: in-session tap targets ≥ 56 pt, primary button 60 pt, nav 44 pt. Swipes over menus.
- Calm, not gamified: no confetti, streaks, badges, flame icons, motivational copy.
- One accent, used only for "the next thing to do": active set, primary button, timer ring, PRs, "Set up" states.
- Materials, not cards: grouped tonal fills (r 16–20), thin dividers, **no borders, no shadows**.
- Hierarchy by size and weight, not color.

## Design tokens

### Color — dark (default)
| Token | Value | Use |
|---|---|---|
| bg | `#0B0B0F` | screen background (barely-violet near-black) |
| surface1 | `#15151B` | grouped fills, steppers, hero block, sheets |
| surface2 | `#201F27` | chips, secondary buttons, rest bar, pills |
| surface3 | `#2A2932` | user chat bubble, provider glyph circles |
| ink | `#F0EEF5` | primary text |
| ink2 | `rgba(240,238,245,0.62)` | secondary text, coach cues |
| ink3 | `rgba(240,238,245,0.40)` | captions, section labels, units |
| divider | `rgba(240,238,245,0.09)` | 1 px separators |
| tonal8 / tonal6 / tonal12 | `rgba(240,238,245,0.08 / 0.06 / 0.12)` | provenance badge fill / empty week cell / ring track |
| accent | `#B7A4FF` | lilac — primary button, active set, ring, PR |
| accentFill | `rgba(183,164,255,0.10)` | current set row, PR rows |
| accentFill14 / 16 | `rgba(183,164,255,0.14 / 0.16)` | today cell, PR pill |
| onAccent | `#140F2A` | text on accent fills |
| lockBg | `#121117` | lock screen wallpaper stand-in |
| liveActivity | `rgba(28,27,34,0.92)` | Live Activity card |

### Color — light
| Token | Value |
|---|---|
| bg | `#F2F1F5` |
| surface1 | `#FFFFFF` |
| surface2 | `#E8E6EE` |
| surface3 | `#DAD7E2` |
| ink | `#18161F` |
| ink2 | `rgba(24,22,31,0.62)` |
| ink3 | `rgba(24,22,31,0.42)` |
| divider | `rgba(24,22,31,0.10)` |
| accent (fill) | `#B7A4FF` with onAccent `#140F2A` |
| accentText | `#6A4FD6` (accent used as text, to hold 4.5:1) |

SwiftUI: one Color asset per token with dark/light appearances. Heat-strip and PR alphas are identical in both modes.

### Typography
| Style | Font | Size/line | Weight | Tracking | Use |
|---|---|---|---|---|---|
| hero | SF Pro Rounded | 72 / 76 | semibold | −2% | in-workout current set; unit "lb" 22 medium ink3; "×" 36 regular ink3 |
| display | SF Pro Rounded | 44 / 48 | semibold | −2% | est. 1RM; Complete stats use 34 |
| numeral | SF Pro Rounded | 22 / 26 | semibold | | inline metrics; stepper value 20; History day 20; set pills 14; set rows 15 |
| large title | SF Pro | 34 / 41 | bold | −2% | Today, History, Connections |
| title | SF Pro | 22 / 28 | semibold | −1% | exercise name; workout titles 30; sheet titles 22 |
| button | SF Pro | 19 | semibold | | primary; secondary 16; chips 14 |
| body | SF Pro | 15 / 20 | regular | | chat 15–17 |
| coach cue | SF Pro | 14 | regular italic | | ink2 |
| caption | SF Pro | 13 / 18 | regular | | ink3; section labels 11 uppercase +6% |
| elapsed | SF Mono | 15 | regular | +2% | top-bar timer, ink2 |
| timer numerals | SF Pro Rounded, tabular | 26 (bar) / 72 (sheet) / 40 (island expanded) / 15 (island compact, activity ring) | semibold | | |

`.font(.system(size: 72, weight: .semibold, design: .rounded))`, `.monospacedDigit()` for timers.

### Spacing & radii
- Space scale: 4 · 8 · 12 · 16 · 20 · 24 · 28 · 32
- Screen horizontal inset 20. Section gap 28–32. Status-bar clearance 60 (content starts at y=60 in the mocks). Bottom safe padding 34.
- Row heights: set row 46 · settings row 60 · history row 64 · list row (picker) 52
- Radii: pill 9999 · chip/small control 14 · control 18 · surface/card 20 · sheet 38 · Live Activity 24 · Dynamic Island expanded 44
- Hit targets: nav 44 · in-session ≥ 56 · primary 60 · stepper ± zones 64×64

## Components
- **PrimaryButton** — full width, h 60, r 18, accent bg, onAccent 19 semibold. Pressed: scale 0.98, opacity 0.9. Only one per screen.
- **SecondaryButton** — h 48–60, r 14–18, surface2 bg, ink 16–17 semibold.
- **Stepper** — h 64, r 18, surface1; grid `64 | 1fr | 64`; ± glyphs 30 rounded; center value 20 rounded semibold + 11 ink3 unit label ("lb · 5", "reps"). ±5 lb (2.5 optional in settings), ±1 rep. Long-press repeats; tap value opens numeric keypad.
- **SetPill** — h 30, r 15, surface2, 14 rounded semibold; top-set variant ink = accent; skipped variant tonal6 bg + ink3.
- **SetRow** — h 46, columns `24 | 1fr | 84 | 20`: set number 13 · planned 15 · actual 15 · ✓ in accent. Done: ink2, ✓. Current: accentFill bg (r 10, −4 px horizontal bleed), number in accent, ink text. Pending: ink3, "—". Swipe left = skip, swipe right = add set.
- **TimerRing** — stroke 3 (44 pt bar) / 4 (64 pt Live Activity) / 6 (240 pt sheet); track tonal12, progress accent, round caps, starts at 12 o'clock and drains clockwise.
- **RestBar** (collapsed) — h 72, r 22, surface2, inset 12 from edges/bottom; ring 44 + time 26 tabular + "Rest · next 155 × 8" 12 ink2 + "+30s" and "Skip" 48-pt tonal8 buttons.
- **RestSheet** (expanded) — medium/large detent, surface1, grabber; 240 ring with 72 time and "of 2:00"; −30s/+30s 60-pt secondary buttons; "Up next" block with next set + cue; PrimaryButton "Skip rest".
- **ProvenanceBadge** — h 24, r 12, tonal8 bg, 12 ink2, optional 6-pt dot. Text only ("from Claude · today", "ChatGPT", "Gemini", "AscendFit"). Never a logo.
- **WorkoutCard** (chat / Today) — w 300, surface1, r 20, padding 16; "WORKOUT" label 11 ink3 caps; title 20 semibold; meta 13 ink2; first 3 exercises as 30-pt rows with divider and "N sets" rounded ink3; "+ N more"; 48-pt accent "Review & Start" button (r 14).
- **ChatBubble** — user: surface3, r 20/20/6/20, padding 11×15, 15 regular, max-w 280, right-aligned. Trainer: **no bubble**, 15 text at 85% ink, max-w 300. Meta line under trainer messages 12 ink3 ("Claude · Opus · 0.4¢").
- **QuickPromptChip** — h 36, r 18, surface2, 14 regular, horizontally scrolling row above keyboard.
- **ProviderChip** (nav title) — h 32, r 16, surface2, 13 semibold "Claude · Opus ⌄"; tapping presents the picker sheet.
- **WeekStrip** — 7 columns, gap 8; day letter 11 ink3; cell h 40 r 12: done = surface1 + ✓ ink; today = accentFill14 + accent "·"; other = tonal6.
- **HeatStrip** — 12 columns (weeks) × 7 rows, gap 4, square cells r 4; empty tonal6 (light: surface2); intensity by volume quartile = accent at 0.12 / 0.30 / 0.55 / 0.90. Month labels 11 ink3 at Jun/Jul/Aug/Sep.
- **Inset grouped list** — surface1, r 18, rows h 60 with 1 px divider at 7% inside; 28-pt monochrome glyph circle (surface3, initials) leading; status trailing (ink2 "Connected", accent semibold "Set up"); chevron ink at 30%.

## Screens

### 1. Active Workout (idle) — `#1a`
Layout (top → bottom, inset 20): top bar h 44 (elapsed SF Mono 15 ink2 · "Exercise 3 of 7" 13 ink2 · overflow "···" 44×44); title block (+12): exercise 22 semibold, muscle group 13 ink3; hero (+28, centered): `155 lb × 8` at 72 rounded; "Set 2 of 4 · Working" 15 ink2 with "Working" in accent (+14); "Last time: 150 × 8, 8, 7" 13 ink3 (+6); two Steppers in a 2-col grid gap 12 (+24); PrimaryButton "Log set" (+14); coach cue 14 italic ink2 centered (+18); set table pinned to bottom (header row 11 caps ink3: SET / PLANNED / ACTUAL) + 4 SetRows; bottom padding 34.
Overflow menu: Swap exercise, Edit plan, End workout.
Alternatives explored (not chosen): `#1b` split columns with vertical steppers; `#1c` ledger with hero inside the set table.

### 2. Active Workout — resting, collapsed bar — `#1d`
Same as idle; hero + steppers at 55% opacity, status "Set 3 of 4 · Up next"; set table shows sets 1–2 done, 3 current. RestBar overlays bottom. 

### 3. Active Workout — resting, expanded sheet — `#1e`
Background dimmed to 35%; RestSheet from y=250 to bottom.

### 4. Active Workout — PR — `#1f`
Elapsed 31:47. Hero replaced by: "NEW BEST · 165 × 6" pill (h 26, r 13, accentFill16, accent 12 semibold +4%) → hero numerals **in accent** `165 lb × 6` → "Set 4 of 4 · Logged" → "Previous best: 160 × 6 · 3 weeks ago". Set table: 1–3 done, 4 = PR row (accentFill, ✓). Bottom: PrimaryButton "Next exercise · Incline DB Press" + text button "Add another set" (48, ink2).

### 5. Active Workout — light — `#1g`
Identical to idle with light tokens; "Working" and ✓ use accentText.

### 6. Today — queued — `#1h`
Header h 52: date 13 ink3 over "Today" 34 bold; 36-pt initials avatar (surface2) trailing. Hero block (+28): surface1, r 20, padding 22/20/20: ProvenanceBadge "from Claude · today"; title "Push Day A" 30 semibold (+14); "7 exercises · ~52 min" 15 ink2 (+8); trainer note 14 italic ink2 (+14); PrimaryButton "Start" (+22); text button "Preview workout" 14 ink2 h 40. "THIS WEEK" section (+32): label row (11 caps ink3 / "3 of 4 sessions" 13 ink3) + WeekStrip. Last session (+32, divider above, padding-top 16): "Pull Day A" 15 semibold / "Tuesday" 13 ink3; three metrics (22 rounded semibold + 11 ink3 label): 48 min · 14,320 lb · **1** PR (accent).

### 7. Today — empty — `#1i`
Same header. Centered copy at +72: "Nothing on the bench yet." 26 semibold; "You trained Tuesday and Thursday. Legs are due." 15 ink2. Buttons (+36, gap 10): PrimaryButton "Ask your trainer"; SecondaryButton (h 60, surface1) "Pick a workout". Hint 13 ink3 "or share a plan from ChatGPT, Claude or Gemini". WeekStrip pinned to bottom.

### 8. Today — light — `#1j`
Same as #6, hero surface = #FFFFFF, PR count in accentText.

### 9. Workout Preview — `#1k`
Nav h 44: "Close" 17 ink2 / "Edit all" 15 ink2. ProvenanceBadge "from Claude · Opus · just now"; title 30; "7 exercises · 24 sets · ~52 min" 15 ink2; trainer note 14 italic, divider below. Exercise rows (padding 16/0/14, divider): index 13 ink3 (w 16) · name 17 semibold · "Edit" chip (h 32, r 10, tonal6, 13 ink2); SetPills row (gap 6, indented 26); cue 14 italic ink2. Top set pill in accent. Trailing "+ 3 more · …" 13 ink3. Sticky bottom PrimaryButton "Looks good — Start" over a bg gradient fade (padding 12/20/34).
Interactions: tap pill → inline stepper row; Edit → per-exercise set editor; long-press/swipe row → Swap (search by muscle group, keep set scheme). Edits are recorded as "changed from plan" and sent back with results.

### 10. Trainer — chat with workout card — `#1l`
Nav: "‹ Today" 17 ink2 · ProviderChip "Claude · Opus" · "···". Messages column gap 14: user ChatBubble "Plan today. Chest felt fine after Tuesday."; trainer text "Good — bench moved well last week, so we add 5 lb on the top set. Here's Push Day A:"; WorkoutCard (Push Day A · 7 exercises · ~52 min · Barbell Bench Press 4 sets / Incline DB Press 3 sets / Overhead Press 3 sets / + 4 more · Review & Start); meta "Claude · Opus · 0.4¢". QuickPromptChips: "Plan today", "I only have 30 min", "Swap for dumbbells", "How did last week go?". Composer: field h 44 r 22 surface1 placeholder "Message your trainer" ink3 + 44-pt send circle surface2. System keyboard below.
Rule: any model output matching the workout JSON schema renders as a WorkoutCard, never prose.

### 11. Trainer — provider picker sheet — `#1m`
Medium-detent sheet (surface1, r 38 top, from y=170): grabber; "Trainer model" 22 semibold; "Cost is an estimate per message, billed to your own key." 13 ink2. Groups per provider (label 11 caps ink3 + status right: "Connected" ink2 / "Set up in Connections" accent). Model rows h 52 with divider: ✓ accent (w 20) · name 16 medium + desc 12 ink3 · cost 15 rounded ink2. Providers without a key at 35% opacity, no cost. Data: Claude — Opus 4.1 0.4¢ (selected), Sonnet 4.5 0.1¢; ChatGPT — GPT-5 0.3¢, GPT-5 mini 0.05¢; Gemini — Gemini 2.5 Pro "No API key". Bottom SecondaryButton "Manage keys in Connections" (h 52, r 16).

### 12. Trainer — rate-limit error — `#1n`
ProviderChip "ChatGPT · GPT-5". User bubble "I only have 30 min today". System card (w 300, surface1, r 20, padding 16): 8-pt ink3 dot + "ChatGPT is rate-limited" 15 semibold; body 14 ink2 "Your OpenAI key hit its per-minute quota. It usually clears in about a minute. Your message is saved."; accent button h 52 r 14 "Retry with Claude · Sonnet"; two 44-pt secondary buttons "Retry in 0:48" (live countdown) and "Use Gemini". Meta "Error 429 · 10:42". No red anywhere. Fallback = best connected provider at same tier or one below; transcript is forwarded.

### 13. Workout Complete — `#1o`
Nav: "Done" right, 17 ink2. "Push Day A · from Claude" 13 ink3; "Done for today." 30 semibold. Stats grid 3 cols (+28): 34 rounded semibold + unit 15 ink3 + label 12 ink3: 54 min · 16.1k lb · 23/24 sets. "PERSONAL RECORDS" (+30): block r 14 accentFill bleeding −12 px horizontally; rows h 52: lift 16 semibold · old 16 rounded ink2 · "→" ink3 · new 16 rounded semibold **accent** (Bench 160 × 6 → 165 × 6; Overhead Press 95 × 8 → 100 × 8); divider inside at accent 15%. Deviations list (+24, divider above): "Skipped — Cable Fly · set 3", "Changed from plan — Incline DB 55 → 50" (15, label ink2). Note field (+20): min-h 72, r 16, surface1, placeholder "Note for your trainer — how did it feel?". Bottom: PrimaryButton "Share with trainer" + text button "Done".
Share posts structured results (sets, PRs, skips, changes, note) to the authoring provider and opens the reply in Trainer.

### 14. History — `#1p`
Header h 52: "History" 34 bold / "Exercises" 15 ink2. Heat block (+24): "12 weeks" / "41 sessions" 13 ink3; HeatStrip; month labels. "THIS WEEK" list (+28): rows h 64: date column w 40 (dow 11 caps ink3, day 20 rounded semibold) · title 16 semibold + ProvenanceBadge (h 18, 10) · meta 13 ink3 "54 min · 16.1k lb · 23 sets" · PR count 13 accent semibold when > 0. Tab bar h 83, divider top: Today / History / Trainer (SF Symbols calendar, clock, bubble.left — placeholders in mock).

### 15. Exercise Detail — `#1q`
Nav "‹ Exercises". "Barbell Bench Press" 26 semibold; "Chest · Triceps · 38 sessions" 13 ink3. "ESTIMATED 1RM" / "6 months": value 198 lb (44 rounded) + "+12 since Jun" 14 accent semibold; chart 353×120: single 2-pt polyline ink2, round joins, accent 5-pt dot on latest point, labels "Mar"/"Sep" 11 ink3 at ends only, **no gridlines**. "VOLUME PER SESSION" (+40): 16 bars, gap 5, r 3, h 64 max, ink at 20% except latest = accent. "BEST SETS" (+32): rows h 48 with divider: Heaviest 165 × 6 (today) · Best 8 155 × 8 (Aug 29) · Most reps 135 × 14 (Jul 3). Swift Charts with `.chartOverlay` scrubbing → one value label above the finger.

### 16. History — light — `#1r`
Same as #14 with light tokens; heat empty cells = surface2.

### 17. Connections — `#1s`
Nav "‹ Settings"; "Connections" 34 bold; intro 15 ink2 "How workouts get into AscendFit, and which trainers can write them." Groups (label 11 caps ink3, list surface1 r 18, rows h 60): TRAINERS — Claude (Anthropic key · Opus, Sonnet · Connected), ChatGPT (OpenAI key · GPT-5 · Connected), Gemini (Google AI key · **Set up** accent semibold). IMPORT — Share Sheet (Share any plan text from another app · On). API KEYS — Anthropic `sk-ant-····9f2a · Aug 12` "In Keychain"; OpenAI `sk-····c41d · Jul 30` "In Keychain"; "Add a key…" row h 56 accent semibold. Footer 12 ink3 "Keys never leave this device. Spend this month: $1.84." Glyph circles: 28 pt surface3 with monochrome initials (C / G / Ge).

### 18. Connect ChatGPT — 3-step sheet — `#1t`
Large-detent sheet from y=150: grabber; "Connect ChatGPT" 22 semibold / "Cancel" 15 ink2; 3-segment progress (h 3, r 2, accent for done+current, tonal12 pending); "Step 2 of 3" 12 ink3. Steps (gap 18; inactive at 50%): 1 ✓ "Add your OpenAI key" + `sk-····c41d`; 2 (accent numbered circle 28) "Give ChatGPT the recipe" + body 14 ink2 + code block (r 14, bg, SF Mono 12 ink2: "When you write a workout, output it as AscendFit JSON (schema v1) and end with the link ascendfit://import?…") + 44-pt buttons "Copy" / "Open ChatGPT"; 3 "Send a test workout" — "We'll confirm when it lands." PrimaryButton "I've pasted it". Step 3 auto-completes on first inbound import. Claude/Gemini reuse the sheet with provider-specific copy.

### 19. Lock Screen Live Activity — `#1u`
Wallpaper stand-in lockBg; date 22 medium 85% ink; clock 88 rounded semibold −3%. Activity card (liveActivity bg, r 24, padding 16/18, gap 16): 64-pt TimerRing with 15 tabular time inside · "Rest · Bench Press" 12 ink2 / "Next: 155 × 8" 24 rounded semibold / "Set 3 of 4 · AscendFit" 12 ink3 · "+30s" button h 44 r 14 tonal10 (App Intent). Implement with `Text(timerInterval:)` and `ProgressView(timerInterval:)`. Ends with a 3-s "Go" state (ring full accent) then dismisses. One haptic, no sound.

### 20. Dynamic Island — `#1v`
Compact: leading 22-pt ring (stroke 2.5), trailing time 15 rounded semibold tabular in accent. Expanded (w 371, r 44, padding 16/20/18): 52-pt ring · "Rest · Bench Press" 12 ink2 + time 40 rounded semibold · "Next" 11 ink3 + "155 × 8" 20 rounded semibold right-aligned; button row (h 44, r 14, gap 8): −30s, +30s (tonal10), Skip (accent). Minimal: ring only.

### 21. Design system sheet — `#1w`
Reference only; all values above.

## Interactions & motion
- **Log set**: hero numerals slide up 24 pt and fade out; next set slides in from below — `.spring(response: 0.35, dampingFraction: 0.85)`. Logged SetRow gets ✓ with 120 ms ease. Then RestBar rises from below the safe area (same spring, 0.45 s) and hero/steppers dim to 55%.
- **Rest bar ↔ sheet**: tap time or drag up to expand; ring 44 → 240 via `matchedGeometryEffect`. Swipe down / tap scrim collapses.
- **Rest end**: bar slides away, hero returns to 100%, one haptic (`.success`), no sound by default.
- **PR**: numerals tint to accent over 0.25 s; NEW BEST pill emits one 14-pt ring pulse (1.2 s ease-out, `box-shadow`-style expanding ring) once. Nothing else.
- **Stepper**: ±5 lb / ±1 rep per tap; long-press repeats (accelerating); tap value → numeric keypad. Digit roll 0.18 s on change (#1b variant).
- **Set rows**: swipe left = Skip, swipe right = Add set.
- **Today → Active Workout**: Start uses `NavigationTransition.zoom` from the hero block; title morphs into exercise title.
- **Chat**: WorkoutCard fades in and rises 12 pt as it streams; Review & Start pushes Preview.
- **Complete**: the three stat numerals count up over 0.6 s on appear; PR rows fade in last.
- **Connect sheet**: active step expands 0.3 s; step 3 completes with checkmark on first import.
- Button pressed state: scale 0.98, opacity 0.9. Overflow menu is a native `Menu`.

## State
- `WorkoutSession`: exercises[], currentExerciseIndex, currentSetIndex, elapsed, restTimer (remaining, total, isExpanded), loggedSets[], prs[], skips[], deviations[].
- `Set`: planned (weight, reps), actual (weight, reps)?, state (pending / current / done / skipped / pr).
- `TrainerChat`: provider, model, messages[] (text | workoutCard | systemError), pendingRetry (countdown, fallbackProvider).
- `Providers`: per-provider key presence (Keychain), models with cost estimates, connection status.
- `Today`: queuedWorkout? (title, provenance, exerciseCount, duration, note), weekCompletion[7], lastSession summary.
- `History`: sessions[], heat[84] quartiles, per-exercise 1RM series, volume series, best sets.
- Rest timer must survive backgrounding (Live Activity + local notification at 0:00).

## Assets
No raster assets. Icons are SF Symbols (`ellipsis`, `chevron.left`, `chevron.right`, `checkmark`, `arrow.up`, `calendar`, `clock`, `bubble.left`, `square.and.arrow.up`). Provider marks are monochrome text initials in a 28-pt circle — never colored logos.

## Files
- `AscendFit — standalone.html` — single self-contained file; open in any browser, or upload to ChatGPT / Gemini / Claude as a reference. Section 1 = final design (lilac); section 2 = palette explorations (2c chosen).
- `screens/01…10-*.png` — one image per screen group (Active Workout directions, states, Today, Preview, Trainer, Complete, History, Connections, Live Activity, design sheet). Best for attaching to chat-based AI tools.
- `AscendFit.dc.html`, `ios-frame.jsx`, `support.js` — the editable source of the mock; not part of the app.
