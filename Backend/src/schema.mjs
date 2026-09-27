// Provider-neutral DTO. All optional keys are explicit null for strict output.
const str = { type: "string" };
const text = { type: "string", maxLength: 12000 };
const enumeration = (...values) => ({ type: "string", enum: values });
const number = (minimum, maximum, integer = false) => ({ type: integer ? "integer" : "number", minimum, maximum });
const nullable = schema => ({ anyOf: [schema, { type: "null" }] });
const object = properties => ({ type: "object", properties, required: Object.keys(properties), additionalProperties: false });
const array = (items, maxItems, minItems = 0) => ({ type: "array", items, minItems, maxItems });
const uuid = { type: "string", pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$" };
const phase = object({ kind: enumeration("controlled", "explosive"), seconds: nullable(number(0, 600)) });
const set = object({
  id: uuid, kind: enumeration("weighted", "bodyweight", "assistedBodyweight", "amrap", "timed", "distance"),
  role: enumeration("warmUp", "working", "drop", "failure"),
  side: enumeration("bilateral", "left", "right", "alternating", "perSide"),
  reps: nullable(object({ min: number(1, 10000, true), max: number(1, 10000, true) })),
  load: nullable(object({ amount: number(0, 100000), unit: nullable(enumeration("kg", "lb")) })),
  durationSeconds: nullable(number(1, 86400, true)),
  distance: nullable(object({ amount: number(0.000001, 1000000), unit: nullable(enumeration("m", "km", "mi")) })),
  effort: nullable(object({ kind: enumeration("rpe", "rir"), value: number(0, 10) })),
  tempo: nullable(object({ eccentric: phase, bottomPause: phase, concentric: phase, topPause: phase })),
  restSeconds: nullable(number(0, 86400, true)),
});
export const workoutSchema = object({
  id: uuid, title: { type: "string", minLength: 1, maxLength: 200 }, notes: nullable(text),
  exercises: array(object({
    id: uuid, name: { type: "string", minLength: 1, maxLength: 200 }, equipment: nullable(text), notes: nullable(text),
    group: nullable(object({ id: uuid, kind: enumeration("superset", "circuit"), position: number(0, 29, true) })),
    sets: array(set, 50, 1),
  }), 30, 1),
});
export const interpretationSchema = object({
  schemaVersion: { type: "integer", enum: [1] }, classification: enumeration("none", "single", "multiple"),
  workouts: array(workoutSchema, 5),
  issues: array(object({ id: uuid, path: str, code: str, message: text, blocking: { type: "boolean" }, sourceQuote: nullable(text) }), 300),
  confidence: array(object({ path: str, level: enumeration("high", "medium", "low"), sourceQuote: nullable(text) }), 500),
});
export const portableSchema = { $schema: "https://json-schema.org/draft/2020-12/schema", $id: "urn:ascendfit:workout-plan:v1", title: "Ascend Fit WorkoutPlan v1 import envelope", ...interpretationSchema };

// Small schema walker for this deliberately limited schema vocabulary. The
// schema, not a parallel handwritten structural contract, governs validation.
export function validateSchema(value, schema = interpretationSchema, path = "") {
  if (schema.anyOf) return schema.anyOf.some(item => validateSchema(value, item, path).length === 0) ? [] : [`${path}: invalid nullable value`];
  const errors = [];
  const type = schema.type;
  const valid = type === "null" ? value === null : type === "array" ? Array.isArray(value)
    : type === "object" ? value !== null && typeof value === "object" && !Array.isArray(value)
    : type === "integer" ? Number.isSafeInteger(value)
    : type === "number" ? typeof value === "number" && Number.isFinite(value) : typeof value === type;
  if (!valid) return [`${path}: expected ${type}`];
  if (schema.enum && !schema.enum.includes(value)) errors.push(`${path}: unsupported value`);
  if (type === "object") {
    for (const key of schema.required ?? []) if (!Object.hasOwn(value, key)) errors.push(`${path}/${key}: missing key`);
    for (const key of Object.keys(value)) {
      if (!schema.properties[key]) errors.push(`${path}/${key}: unknown key`);
      else errors.push(...validateSchema(value[key], schema.properties[key], `${path}/${key}`));
    }
  }
  if (type === "array") {
    if (value.length < schema.minItems || value.length > schema.maxItems) errors.push(`${path}: array length out of range`);
    value.forEach((item, index) => errors.push(...validateSchema(item, schema.items, `${path}/${index}`)));
  }
  if (type === "string") {
    if (schema.minLength && value.trim().length < schema.minLength || value.length > (schema.maxLength ?? Infinity)) errors.push(`${path}: invalid text length`);
    if (schema.pattern && !new RegExp(schema.pattern).test(value)) errors.push(`${path}: invalid identifier`);
  }
  if ((type === "number" || type === "integer") && (value < schema.minimum || value > schema.maximum)) errors.push(`${path}: number out of range`);
  return errors;
}
