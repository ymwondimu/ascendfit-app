import { randomUUID } from "node:crypto";
import { validateSchema } from "./schema.mjs";

export function validateWorkoutImport(input, { sourceText } = {}) {
  const structuralErrors = validateSchema(input);
  if (structuralErrors.length) return { valid: false, structuralErrors, value: null };
  const value = structuredClone(input);
  const issues = value.issues;
  const issue = (path, code, message) => {
    if (!issues.some(item => item.path === path && item.code === code))
      issues.push({ id: randomUUID(), path, code, message, blocking: true, sourceQuote: null });
  };
  const seen = new Set();
  const unique = (id, path) => {
    if (seen.has(id.toLowerCase())) issue(path, "duplicate_id", "Each workout, exercise and set must have a unique UUID.");
    seen.add(id.toLowerCase());
  };
  const count = value.workouts.length;
  if (value.classification !== (count === 0 ? "none" : count === 1 ? "single" : "multiple"))
    issue("/classification", "workout_count", "Workout classification does not match the number of workouts.");
  value.workouts.forEach((workout, w) => {
    const wp = `/workouts/${w}`;
    unique(workout.id, `${wp}/id`);
    const groups = new Map();
    workout.exercises.forEach((exercise, e) => {
      const ep = `${wp}/exercises/${e}`;
      unique(exercise.id, `${ep}/id`);
      if (/\b(?:or|and\/or)\b/i.test(exercise.name)) issue(`${ep}/name`, "alternative_exercise", "Choose one definite exercise instead of alternative movement names.");
      if (exercise.group) {
        const members = groups.get(exercise.group.id) ?? [];
        members.push({ ...exercise.group, index: e, path: `${ep}/group` });
        groups.set(exercise.group.id, members);
      }
      exercise.sets.forEach((set, s) => {
        const sp = `${ep}/sets/${s}`;
        unique(set.id, `${sp}/id`);
        if (["weighted", "bodyweight", "assistedBodyweight"].includes(set.kind) && !set.reps)
          issue(`${sp}/reps`, "missing_reps", "Confirm the repetition target.");
        if (set.reps && set.reps.min > set.reps.max) issue(`${sp}/reps`, "invalid_range", "Minimum repetitions cannot exceed maximum repetitions.");
        if (["weighted", "assistedBodyweight"].includes(set.kind) && !set.load)
          issue(`${sp}/load`, "missing_load", "Confirm the load or assistance; bar mass is not assumed.");
        if (set.load && !set.load.unit) issue(`${sp}/load/unit`, "missing_unit", "Choose the mass unit explicitly.");
        if (sourceText !== undefined && set.load?.unit) {
          const unitPath = `${sp}/load/unit`;
          const evidence = value.confidence.filter(field => unitPath === field.path || unitPath.startsWith(`${field.path}/`))
            .filter(field => field.sourceQuote && sourceText.includes(field.sourceQuote));
          const pattern = set.load.unit === "lb" ? /\b(?:lb|lbs|pound|pounds)\b/i : /\b(?:kg|kgs|kilogram|kilograms)\b/i;
          if (!evidence.some(field => pattern.test(field.sourceQuote))) {
            set.load.unit = null;
            issue(unitPath, "unverified_unit", "The mass unit has no explicit source evidence for this field. Confirm it before scheduling.");
          }
        }
        if (set.kind === "timed" && !set.durationSeconds) issue(`${sp}/durationSeconds`, "missing_duration", "Confirm the duration in seconds.");
        if (set.kind === "distance" && !set.distance) issue(`${sp}/distance`, "missing_distance", "Confirm the distance target.");
        if (set.distance && !set.distance.unit) issue(`${sp}/distance/unit`, "missing_unit", "Choose the distance unit explicitly.");
        if (set.effort?.kind === "rir" && !Number.isInteger(set.effort.value)) issue(`${sp}/effort/value`, "invalid_rir", "Reps in reserve must be a whole number.");
        const permitted = {
          weighted: ["reps", "load"], bodyweight: ["reps"], assistedBodyweight: ["reps", "load"],
          amrap: ["load"], timed: ["durationSeconds", "load"], distance: ["distance", "durationSeconds"],
        }[set.kind];
        for (const field of ["reps", "load", "durationSeconds", "distance"])
          if (set[field] !== null && !permitted.includes(field)) issue(`${sp}/${field}`, "incompatible_target", "This target is incompatible with the set type. Correct it rather than silently dropping it.");
        if (set.tempo) for (const [key, phase] of Object.entries(set.tempo)) {
          if (phase.kind === "controlled" && phase.seconds === null || phase.kind === "explosive" && phase.seconds !== null)
            issue(`${sp}/tempo/${key}`, "invalid_tempo", "Controlled phases need seconds; explosive phases must use null seconds.");
        }
      });
    });
    for (const members of groups.values()) {
      const positions = members.map(item => item.position);
      if (members.length < 2 || new Set(members.map(item => item.kind)).size !== 1 || positions.some((p, i) => p !== i)
          || members.some((item, i) => i > 0 && item.index !== members[i - 1].index + 1))
        issue(members[0].path, "invalid_group", "A group requires adjacent exercises with one group kind and consecutive zero-based positions.");
    }
  });
  for (const field of value.confidence) {
    if (field.level !== "high") issue(field.path, "confirm_interpretation", "Confirm this uncertain interpretation before scheduling.");
  }
  if (sourceText !== undefined) {
    for (const field of [...value.confidence, ...input.issues]) {
      if (field.sourceQuote && !sourceText.includes(field.sourceQuote))
        issue(field.path, "unverified_source", "The source quote could not be verified against the original text.");
    }
  }
  return { valid: true, structuralErrors: [], value, ready: count > 0 && !issues.some(item => item.blocking) };
}
