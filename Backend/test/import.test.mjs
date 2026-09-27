import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import { Readable } from "node:stream";
import { EventEmitter } from "node:events";
import { validateWorkoutImport } from "../src/validation.mjs";
import { validateSchema, portableSchema } from "../src/schema.mjs";
import { createRequestHandler } from "../src/app.mjs";
import { createOpenAIProvider } from "../src/provider.mjs";
const fixture = name => JSON.parse(readFileSync(new URL(`../examples/${name}.workout.json`, import.meta.url), "utf8"));

test("portable schema artifact matches source and confirmed Lower A retains exact instructions and ranges", () => {
  assert.deepEqual(JSON.parse(readFileSync(new URL("../schema/workout-plan-v1.schema.json", import.meta.url))), portableSchema);
  const value = fixture("lower-a-ready");
  const result = validateWorkoutImport(value);
  assert.equal(result.ready, true);
  assert.equal(value.workouts[0].exercises.length, 13);
  const exercises = value.workouts[0].exercises;
  assert.equal(exercises[0].name, "Stationary Bike");
  assert.equal(exercises[0].sets[0].durationSeconds, 300);
  assert.deepEqual(exercises[3].sets[0].load, { amount: 45, unit: "lb" });
  assert.deepEqual(exercises[5].sets[1].reps, { min: 3, max: 4 });
  assert.deepEqual(exercises[11].sets[0].reps, { min: 15, max: 20 });
  assert.deepEqual(exercises[12].sets[0].reps, { min: 12, max: 15 });
  assert.ok(exercises.flatMap(e => e.sets).every(s => s.restSeconds === null && (!s.load || s.load.unit === "lb")));
  assert.ok(value.workouts[0].notes.includes("If pain returns during squats, deadlifts, or leg press, stop that exercise rather than trying to work through it."));
  assert.ok(!exercises.some(e => /lunges/i.test(e.name)));
});

test("original ambiguous example stays blocked and global stray pounds cannot authorize other weights", () => {
  const original = fixture("lower-a-review");
  const text = readFileSync(new URL("../examples/lower-a-source.txt", import.meta.url), "utf8");
  const result = validateWorkoutImport(original, { sourceText: text });
  assert.equal(result.ready, false);
  assert.equal(result.value.workouts[0].exercises[4].sets[0].load.unit, null);
  assert.equal(result.value.workouts[0].exercises[12].sets[0].load.unit, "lb");
  const guessed = structuredClone(original);
  guessed.workouts[0].exercises[4].sets[0].load.unit = "lb";
  assert.equal(validateWorkoutImport(guessed, { sourceText: text }).value.workouts[0].exercises[4].sets[0].load.unit, null);
});

test("future versions/unknown fields rejected; invalid targets/duplicate IDs/group structure cannot become ready", () => {
  const value = fixture("simple-strength");
  assert.ok(validateSchema({ ...value, schemaVersion: 2 }).length);
  assert.ok(validateSchema({ ...value, injected: true }).length);
  value.workouts[0].exercises[0].name = "Bike or Treadmill";
  const set = value.workouts[0].exercises[0].sets[0];
  set.reps = { min: 10, max: 5 }; set.effort = { kind: "rir", value: 1.5 }; set.durationSeconds = 20;
  value.workouts[0].exercises[0].sets[1].id = set.id;
  value.workouts[0].exercises[0].group = { id: value.workouts[0].id, kind: "superset", position: 0 };
  const result = validateWorkoutImport(value);
  assert.equal(result.ready, false);
  for (const code of ["invalid_range", "invalid_rir", "incompatible_target", "duplicate_id", "invalid_group", "alternative_exercise"]) assert.ok(result.value.issues.some(i => i.code === code));
});

test("all domain variants, effort, tempo and valid grouping validate without erasing targets", () => {
  const value = fixture("simple-strength");
  const base = value.workouts[0].exercises[0].sets[0];
  const variants = [
    { kind: "weighted", reps: { min: 8, max: 10 }, load: { amount: 20, unit: "kg" } },
    { kind: "bodyweight", reps: { min: 10, max: 10 } },
    { kind: "assistedBodyweight", reps: { min: 6, max: 6 }, load: { amount: 15, unit: "lb" } },
    { kind: "amrap", load: { amount: 10, unit: "kg" } },
    { kind: "timed", durationSeconds: 30 },
    { kind: "distance", distance: { amount: 1.5, unit: "km" }, durationSeconds: 500 },
  ].map((fields, index) => ({ ...base, id: `00000000-0000-4000-8000-00000000000${index}`, reps: null, load: null, durationSeconds: null, distance: null, ...fields }));
  variants[0].tempo = { eccentric: { kind: "controlled", seconds: 3 }, bottomPause: { kind: "controlled", seconds: 0 }, concentric: { kind: "explosive", seconds: null }, topPause: { kind: "controlled", seconds: 1 } };
  variants[0].effort = { kind: "rpe", value: 8.5 };
  value.workouts[0].exercises[0].sets = variants;
  value.workouts[0].exercises.forEach((e, index) => { e.group = { id: "90000000-0000-4000-8000-000000000000", kind: "circuit", position: index }; });
  assert.equal(validateWorkoutImport(value).ready, true);
  value.workouts[0].exercises[0].group.position = 1;
  value.workouts[0].exercises[1].group.position = 0;
  assert.equal(validateWorkoutImport(value).ready, false);
});

async function invoke(handler, input = {}, overrides = {}) {
  const raw = JSON.stringify(input);
  const request = Readable.from([Buffer.from(raw)]);
  request.method = "POST"; request.url = "/v1/imports/interpret";
  request.headers = { authorization: "Bearer test-private-token", "content-type": "application/json", ...overrides.headers };
  request.socket = { remoteAddress: "127.0.0.1" };
  const response = new EventEmitter();
  response.writeHead = (status, headers) => { response.status = status; response.headers = headers; };
  response.end = raw => { response.body = JSON.parse(raw); response.writableEnded = true; };
  await handler(request, response);
  return response;
}
const requestBody = { schemaVersion: 1, text: "Squat 3x8 50 kg", sourceKind: "paste", sourceURL: null };

test("API protects credentials, rate/body/budget limits and preserves source without logging", async () => {
  let calls = 0;
  const handler = createRequestHandler({ accessToken: "test-private-token", maxRequestsPerWindow: 2, provider: async () => { calls++; return fixture("simple-strength"); } });
  assert.equal((await invoke(handler, requestBody, { headers: { authorization: "Bearer wrong" } })).status, 401);
  assert.equal((await invoke(handler, requestBody, { headers: { "content-length": "999999" } })).status, 413);
  const response = await invoke(handler, requestBody);
  assert.equal(response.status, 200);
  assert.deepEqual(response.body.source, { kind: "paste", originalText: requestBody.text, sourceURL: null });
  assert.equal((await invoke(handler, requestBody)).status, 429);
  assert.equal(calls, 1);
  const budget = createRequestHandler({ accessToken: "test-private-token", maxDailyRequests: 1, provider: async () => fixture("simple-strength") });
  assert.equal((await invoke(budget, requestBody)).status, 200);
  assert.equal((await invoke(budget, requestBody)).status, 429);
});

test("OpenAI adapter has explicit configuration, strict schema, no storage and generic safe errors", async () => {
  await assert.rejects(createOpenAIProvider({})("text"), error => error.code === "import_not_configured");
  let sent;
  const provider = createOpenAIProvider({ apiKey: "test-only-key", model: "test-only-model", fetchImpl: async (url, options) => {
    sent = JSON.parse(options.body);
    assert.equal(url, "https://api.openai.com/v1/responses");
    return new Response(JSON.stringify({ status: "completed", output: [{ content: [{ type: "output_text", text: JSON.stringify(fixture("simple-strength")) }] }] }), { status: 200 });
  } });
  assert.equal((await provider("workout data")).schemaVersion, 1);
  assert.equal(sent.store, false);
  assert.equal(sent.text.format.strict, true);
  const { $schema, $id, title, ...expectedSchema } = portableSchema;
  assert.deepEqual(sent.text.format.schema, expectedSchema);
  const failing = createOpenAIProvider({ apiKey: "test-only-key", model: "test-only-model", fetchImpl: async () => new Response("secret upstream detail", { status: 500 }) });
  await assert.rejects(failing("text"), error => error.code === "provider_unavailable" && !error.message.includes("secret"));
});

test("synthetic uncertainty, selection and source-evidence contracts remain explicit", async () => {
  const { syntheticImportCases } = await import("./fixtures/synthetic-import-cases.mjs");
  for (const entry of syntheticImportCases()) {
    const before = structuredClone(entry.value);
    const result = validateWorkoutImport(entry.value, entry.sourceText === undefined ? {} : { sourceText: entry.sourceText });
    assert.equal(result.valid, true, entry.name);
    assert.equal(result.ready, entry.ready, entry.name);
    assert.deepEqual(entry.value, before, "validation must not mutate the captured draft");
    if (entry.classification) assert.equal(result.value.classification, entry.classification, entry.name);
    for (const code of entry.codes ?? []) assert.ok(result.value.issues.some(issue => issue.code === code && issue.blocking), `${entry.name}: ${code}`);
  }
});

test("API rejects malformed inputs before provider calls and does not turn invalid output into a workout", async () => {
  let calls = 0;
  const handler = createRequestHandler({ accessToken: "test-private-token", maxRequestsPerWindow: 20, provider: async () => { calls++; return { schemaVersion: 99 }; } });
  for (const change of [{ text: " " }, { text: "a".repeat(12001) }, { text: "bad\u0000text" }, { sourceURL: "http://example.com" }, { sourceKind: "unknown" }, { unexpected: true }]) {
    assert.equal((await invoke(handler, { ...requestBody, ...change })).status, 400);
  }
  assert.equal(calls, 0);
  const response = await invoke(handler, requestBody);
  assert.equal(response.status, 502);
  assert.equal(response.body.error.code, "invalid_interpretation");
  assert.equal(calls, 1);
});
