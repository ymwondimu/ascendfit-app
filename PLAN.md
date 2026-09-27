# Ascend Fit — Current Execution Plan

**Current status:** JSON import, offline sharing and private-service text conversion client implemented; simulator contract verification complete, live service evaluation outstanding  
**Last updated:** September 27, 2026

This is the current-status index for Ascend Fit. It records where the work stands and what happens next; it does not duplicate the detailed implementation roadmap.

## Canonical documents

- [PROJECT.md](PROJECT.md) — stable product context: why, what, principles, scope, and architecture defaults.
- [implementation-roadmap.md](implementation-roadmap.md) — build order, phase details, and exit gates.
- [PRD.md](PRD.md) — current personal-MVP requirements draft; approval pending.
- [UI-SPEC.md](UI-SPEC.md) — approved production UI contract derived from the supplied handoff.
- [CONTINUATION.md](CONTINUATION.md) — implementation handoff, interaction decisions, verification baseline, and fresh-chat prompt.

## Locked starting decisions

- Ascend Fit begins as the execution layer for workouts authored by an existing trusted AI coach, not as another automatic workout generator.
- Paste and the iOS Share Sheet are the MVP import path.
- Every input compiles into one provider-neutral, versioned workout schema.
- Ambiguous training data requires human confirmation.
- Active workout state and completed-set events persist locally first and work offline.
- Protected backend calls handle AI parsing; provider keys never ship in the iPhone app.
- The first client is native iPhone software built with Swift and SwiftUI.
- The personal MVP precedes accounts, cloud sync, HealthKit, direct provider tools, an in-app coach, and Apple Watch.
- The product uses spacious editorial planning/import/history surfaces and a dark, high-focus gym mode.
- No production UI implementation begins until `UI-SPEC.md` is designed and approved.

## Immediate next sequence

1. Standardized JSON import, offline sharing and a consent-based private-service text conversion client are implemented. Configure/evaluate a real private service using the same format; live model accuracy remains unverified. The user authorized import work in parallel with reliability fixes on September 26.
2. Validate three manual workout loops on a physical iPhone using [DEVICE-VALIDATION.md](DEVICE-VALIDATION.md); simulator verification remains separate.
3. Expand the evaluation corpus from the first user-supplied workout example, preserving ambiguity rather than assuming units or bar mass.

After that foundation works reliably, continue through the ordered phases in the [implementation roadmap](implementation-roadmap.md).

## Progress checklist

- [x] Stable product context captured in [PROJECT.md](PROJECT.md)
- [x] Detailed implementation sequence captured in [implementation-roadmap.md](implementation-roadmap.md)
- [x] `PRD.md` written
- [ ] `PRD.md` approved
- [ ] Real anonymized import corpus collected and approved
- [x] Visual directions and component states supplied in the Claude Design handoff
- [x] Lilac-on-ink-violet production direction selected
- [x] `UI-SPEC.md` written from the approved handoff
- [x] `UI-SPEC.md` approved as the implementation baseline
- [x] Xcode and backend projects created
- [x] Canonical workout domain implemented and tested
- [x] Manual builder → Today → Start → Log Set → Rest flow works in the simulator
- [x] Saved Today plans persist in SQLite; starting atomically consumes the matching plan, and failed starts preserve it for retry
- [x] Manual builder uses a searchable 100-exercise catalog, compact summaries, set-detail editing, profile-based starting loads, first-set propagation, direct numeric editing, and native swipe deletion
- [x] First-launch training profile persists units, sex, height, body weight, and lifting experience
- [x] Today Settings supports persisted unit selection and training-profile editing through the shared profile editor; new manual workouts use the preference while saved workouts retain their units
- [x] Active workout preserves the current-set hero while showing exercise progress and a compact current-exercise set ledger
- [x] Active workout shows an exact previous-set result from the latest matching workout, respecting set position, role, side, equipment, and recorded units; missing or ambiguous matches stay hidden
- [x] Gym Focus Mode supports inline set-result editing with pending-set propagation, one-tap add-set, swipe deletion, exercise instructions, completed-result editing, undo, pause/resume, and confirmed finish/discard actions
- [x] Rest uses persisted deadlines with ±30-second controls, skip, completion haptic and VoiceOver announcement, local notification scheduling, and expired-rest relaunch cleanup
- [x] Active exercise shows short cues and an editable rest default before logging; presets, direct seconds entry, and Off apply to remaining/added sets and survive event replay
- [x] Completed sessions reload into searchable chronological history with exact planned-versus-actual set detail
- [x] Session commands serialize across asynchronous local writes; queued actions receive timestamps when processed to preserve replay order
- [x] Workout completion supports optional notes and a deterministic coach-ready system share
- [x] Completion persists in one event, supports retry after local-write failure, and recovers legacy interrupted finishing without inflating workout duration
- [x] Latest verified coverage: 67 Swift unit tests and six import/share UI regression tests pass (September 27); other 15 UI tests retain the September 26 baseline (21 known passing UI tests). Ten backend tests, syntax checks and 11 local contract cases pass. Text UI tests use controlled responses, not a live provider
- [x] Manual superset/circuit grouping and alternating execution, advanced set targets and planned effort/role/side
- [x] Compatible exercise replacement preserves the identity of already logged sets through replay, history, previous cues, and export
- [x] Pausing freezes remaining rest and shifts the resumed deadline; notification preference and cancellation follow workout state
- [x] History supports date filtering, exercise progress, exact comparable personal records, and versioned JSON/CSV sharing
- [x] Settings includes separate planning/gym appearance, notification controls, privacy copy, and confirmed local data deletion that preserves profile/preferences
- [x] Workout overview selects an unfinished set next, persists the choice, and returns to original/grouped order after logging
- [x] Optional actual RPE/RIR and verbatim set notes, completed-set metadata editing, and optional actual weight/duration entry
- [x] Manual tempo targets, twelve-week history activity/volume strip, per-unit volume bars, and record text in coach summaries
- [x] Backward wall-clock changes no longer lock out default session commands after recovery; explicit dates remain strictly validated
- [x] September 26 batch full simulator and visual verification complete
- [ ] Remaining local refinements: mid-session set-type/plan editing, estimated-1RM views where appropriate, full wall-clock timer/elapsed accuracy, and full accessibility audit
- [ ] Manual local workout tracker proven on device
- [x] Import implementation started in parallel with reliability at the user’s direction: shared JSON schema, offline paste/file review, exact source retention, and confirmed Lower A example
- [x] Foreground notification permission reconciliation implemented without unsolicited prompts
- [x] Import v0 full simulator and visual verification complete
- [x] Offline Share Extension capture, protected App Group inbox, duplicate/recovery handling, explicit import review, and shared-data deletion
- [x] Private-service text client, explicit transmission consent, safe retry/cancellation, source verification, multiple-workout selection and preserved review drafts
- [ ] Live provider evaluation, service/auth setup and physical Share Sheet host validation complete

## Maintenance rule

Update this document whenever current status, the next sequence, or checklist completion changes. Do not rewrite the implementation roadmap to report routine progress; change it only when build order or phase strategy materially changes.
