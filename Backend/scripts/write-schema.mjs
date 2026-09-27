import { writeFileSync } from "node:fs";
import { portableSchema } from "../src/schema.mjs";
writeFileSync(new URL("../schema/workout-plan-v1.schema.json", import.meta.url), `${JSON.stringify(portableSchema, null, 2)}\n`);
