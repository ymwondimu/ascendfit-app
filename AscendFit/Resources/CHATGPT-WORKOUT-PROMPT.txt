# Copy this prompt into ChatGPT with your workout

Ready-file mode: prepare exactly one definite workout. Before emitting JSON, ask me to resolve missing required values or alternative exercises. Do not put “bike or treadmill” or unresolved loads/units in a ready file. Once confirmed, use classification single, exactly one workout, no blocking issues, and only high-confidence entries (or an empty confidence array). Preserve explicitly prescribed rep ranges. Null optional rest means unspecified; do not invent a rest recommendation.

The review-draft rules below apply only if I explicitly request a draft for unresolved input.

Convert the workout below into an Ascend Fit WorkoutPlan v1 JSON file. Return only valid JSON (no Markdown fences), suitable to save as `workout.json`. Do not design or change the workout. Do not guess weights, units, bar mass, missing repetitions, alternatives, or pain instructions. Preserve exercise and workout notes, especially instructions to stop or skip. Exclude explicitly skipped exercises from the exercise list.

Use exactly this envelope (all keys required):
`{"schemaVersion":1,"classification":"single","workouts":[],"issues":[],"confidence":[]}`
Classification is `none`, `single`, or `multiple` and must agree with the number of workouts. Split separately titled workouts instead of merging them. Every workout, exercise, set, group and issue gets a valid UUID string; IDs are unique except a shared group UUID. No additional keys. All fields below must exist: use JSON null when optional, unknown, or not applicable. Never substitute zero for an unknown value.

Each workout: `{"id":"UUID","title":"...","notes":null,"exercises":[]}`.
Each exercise: `{"id":"UUID","name":"source exercise name","equipment":null,"notes":null,"group":null,"sets":[]}`.
Expand “3 sets” into three set objects. Keep warm-ups explicit. Preserve exercise order.
Group: null, or `{"id":"shared UUID","kind":"superset" or "circuit","position":0}`; grouped exercises must be adjacent and positions run 0, 1, 2… within each group.

Every set contains ALL these keys:
`{"id":"UUID","kind":"weighted","role":"working","side":"bilateral","reps":{"min":8,"max":8},"load":{"amount":50,"unit":"kg"},"durationSeconds":null,"distance":null,"effort":null,"tempo":null,"restSeconds":null}`

- `kind`: weighted, bodyweight, assistedBodyweight, amrap, timed, distance.
- `role`: warmUp, working, drop, failure. For ordinary explicitly described working sets use working. If role or side is unclear, identify your interpretation for review instead of hiding it.
- `side`: bilateral, left, right, alternating, perSide. “8/side” means perSide with 8 reps, never 16.
- `reps`: null or `{min:positive integer,max:positive integer}`; exact reps have equal min/max. Used only by weighted, bodyweight, assistedBodyweight. Preserve ranges. AMRAP has null reps.
- `load`: null or `{amount:nonnegative number,unit:"kg"|"lb"|null}`. Means assistance for assistedBodyweight. For unweighted AMRAP/timed use null. “Bar” without specified mass is null with a blocking issue. A numeric load with missing units keeps its number and uses null unit with a blocking issue. Units on one exercise do not imply units on others. Do not convert units.
- `durationSeconds`: null or positive integer; used by timed and as optional target for distance. Convert explicitly stated minutes to seconds.
- `distance`: null or `{amount:positive number,unit:"m"|"km"|"mi"|null}`; used only by distance sets.
- `effort`: null or `{kind:"rpe"|"rir",value:number}`; range 0–10, RIR must be an integer. Do not invent effort targets.
- `tempo`: null or `{eccentric:phase,bottomPause:phase,concentric:phase,topPause:phase}`. Each phase is `{kind:"controlled",seconds:nonnegative number}` or `{kind:"explosive",seconds:null}`. A qualitative instruction such as “slow” stays verbatim in exercise notes; do not invent seconds.
- `restSeconds`: null or nonnegative integer. Null means unspecified, not a default rest recommendation. Zero means explicitly no rest.

Allowed target combinations: weighted=reps+load; bodyweight=reps; assistedBodyweight=reps+load; amrap=optional load; timed=durationSeconds+optional load; distance=distance+optional durationSeconds. Other target fields must be null. Unknown REQUIRED values stay null and receive blocking issues; this is a review draft, never a silently filled-in plan.

Each issue: `{"id":"UUID","path":"/workouts/0/exercises/0/sets/0/load/unit","code":"missing_unit","message":"Which unit is this load in?","blocking":true,"sourceQuote":"exact excerpt from the workout"}`. Use JSON Pointer paths. Alternatives, contradictions, missing required fields, uncertain exercise mapping, or inferred role/side need blocking review issues. Do not say an issue is resolved. Preserve workout stop instructions verbatim in notes, without diagnosis.

Each confidence entry: `{"path":"/workouts/0/exercises/0","level":"high"|"medium"|"low","sourceQuote":"exact excerpt"}`. Include exercise/source mappings and uncertain fields; medium/low confidence always requires review. Quotes must be exact substrings of the workout. Do not invent confidence percentages. Empty issues is allowed only when all required data is explicit and unambiguous.

Limits: at most 5 workouts per file, 30 exercises/workout, 50 sets/exercise, 300 issues and 500 confidence entries. Do not silently truncate; describe unsupported portions as blocking issues. Titles/names max 200 characters, notes/quotes max 12,000. Output schemaVersion 1 only. Do not include a source object: Ascend Fit preserves the file you import.

WORKOUT TO CONVERT:
[Paste your workout here]
