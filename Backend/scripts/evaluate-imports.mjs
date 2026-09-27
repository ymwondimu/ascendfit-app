import { readFileSync } from "node:fs";
import { validateWorkoutImport } from "../src/validation.mjs";
import { syntheticImportCases } from "../test/fixtures/synthetic-import-cases.mjs";
const cases = [
  { name: "simple-strength", ready: true },
  { name: "lower-a-ready", ready: true },
  { name: "lower-a-review", ready: false },
];
const fixtures = cases.map(entry => ({ ...entry, value: JSON.parse(readFileSync(new URL(`../examples/${entry.name}.workout.json`, import.meta.url), "utf8")) }));
let failed = false;
for (const entry of [...fixtures, ...syntheticImportCases()]) {
  const { value } = entry;
  const result = validateWorkoutImport(value, entry.sourceText === undefined ? {} : { sourceText: entry.sourceText });
  const passed = result.valid && result.ready === entry.ready
    && (!entry.classification || result.value.classification === entry.classification)
    && (entry.codes ?? []).every(code => result.value.issues.some(issue => issue.code === code));
  const sets = value.workouts.flatMap(workout => workout.exercises).flatMap(exercise => exercise.sets).length;
  console.log(`${passed ? "PASS" : "FAIL"} ${entry.name}: ${sets} sets; ${result.ready ? "ready" : "blocked"}`);
  if (!passed) failed = true;
}
// Contract fixture checks only: no provider call, source text logging, or cost.
if (failed) process.exitCode = 1;
