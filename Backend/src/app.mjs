import { timingSafeEqual } from "node:crypto";
import { createOpenAIProvider, ImportError } from "./provider.mjs";
import { validateWorkoutImport } from "./validation.mjs";

const jsonHeaders = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff" };
const send = (response, status, body, headers = {}) => { response.writeHead(status, { ...jsonHeaders, ...headers }); response.end(JSON.stringify(body)); };

export function createRequestHandler({
  accessToken = process.env.IMPORT_ACCESS_TOKEN,
  provider = createOpenAIProvider({ apiKey: process.env.OPENAI_API_KEY, model: process.env.OPENAI_MODEL }),
  now = Date.now, maxBodyBytes = 65536, maxRequestsPerWindow = 10, windowMs = 600000,
  maxDailyRequests = 50, maxConcurrentRequests = 2,
} = {}) {
  const clients = new Map();
  let budgetDay = "", dailyCount = 0, active = 0;
  return function handleRequest(request, response) {
    if (request.method === "GET" && request.url === "/health") {
      send(response, 200, { status: "ok", service: "ascend-fit-api" }); return;
    }
    if (request.method !== "POST" || request.url !== "/v1/imports/interpret") {
      send(response, 404, { error: "not_found" }); return;
    }
    return interpret(request, response);
  };

  async function interpret(request, response) {
    const controller = new AbortController();
    let admitted = false;
    const abort = () => { if (!response.writableEnded) controller.abort(); };
    response.once?.("close", abort);
    try {
      if (!accessToken) throw new ImportError(503, "import_not_configured", "AI import is not configured. Import a WorkoutPlan v1 JSON file instead.");
      const authorization = request.headers?.authorization ?? "";
      const actual = Buffer.from(authorization), expected = Buffer.from(`Bearer ${accessToken}`);
      if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) throw new ImportError(401, "unauthorized", "Check your private import service access token.");
      if (!/^application\/json(?:\s*;|$)/i.test(request.headers?.["content-type"] ?? "")) throw new ImportError(415, "unsupported_content_type", "Send a JSON request.");
      const time = now();
      for (const [key, bucket] of clients) if (time >= bucket.until) clients.delete(key);
      const address = request.socket?.remoteAddress ?? "local"; // Do not trust forwarded headers.
      const bucket = clients.get(address) ?? { count: 0, until: time + windowMs };
      if (bucket.count >= maxRequestsPerWindow || clients.size >= 10000 && !clients.has(address)) throw new ImportError(429, "rate_limited", "Too many import attempts. Wait a few minutes and try again.");
      bucket.count++; clients.set(address, bucket);
      const day = new Date(time).toISOString().slice(0, 10);
      if (day !== budgetDay) { budgetDay = day; dailyCount = 0; }
      if (dailyCount >= maxDailyRequests || active >= maxConcurrentRequests) throw new ImportError(429, "import_budget_reached", "The private import service has reached its request budget. Try later or import JSON offline.");
      const raw = await readBody(request, maxBodyBytes);
      let input;
      try { input = JSON.parse(raw); } catch { throw new ImportError(400, "invalid_json", "The request is not valid JSON."); }
      if (!input || typeof input !== "object" || Array.isArray(input) || Object.keys(input).some(key => !["schemaVersion", "text", "sourceKind", "sourceURL"].includes(key))
          || input.schemaVersion !== 1 || typeof input.text !== "string" || !input.text.trim() || input.text.length > 12000
          || !["paste", "shareSheet"].includes(input.sourceKind) || !(input.sourceURL === null || typeof input.sourceURL === "string"))
        throw new ImportError(400, "invalid_request", "Use schemaVersion 1 with 1–12,000 text characters, sourceKind paste/shareSheet, and sourceURL null or an HTTPS URL.");
      if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(input.text)) throw new ImportError(400, "invalid_text", "Remove unsupported control characters from the text.");
      if (input.sourceURL !== null) {
        try { if (new URL(input.sourceURL).protocol !== "https:") throw new Error(); }
        catch { throw new ImportError(400, "invalid_source_url", "Source links must use HTTPS. Links are not fetched by this service."); }
      }
      // Check again after body-read await: concurrent slow clients cannot evade caps.
      if (active >= maxConcurrentRequests || dailyCount >= maxDailyRequests) throw new ImportError(429, "import_budget_reached", "The import service is busy or its budget has been reached.");
      active++; dailyCount++; admitted = true;
      const parsed = await provider(input.text, { signal: controller.signal });
      const validated = validateWorkoutImport(parsed, { sourceText: input.text });
      if (!validated.valid) throw new ImportError(502, "invalid_interpretation", "The interpretation did not match WorkoutPlan v1. No workout was accepted.");
      send(response, 200, { ...validated.value, source: { kind: input.sourceKind, originalText: input.text, sourceURL: input.sourceURL } });
    } catch (error) {
      request.resume?.();
      if (!response.destroyed && !response.writableEnded) {
        const safe = error instanceof ImportError ? error : new ImportError(500, "import_failed", "Import could not finish. Try again.");
        send(response, safe.status, { error: { code: safe.code, message: safe.message } }, safe.status === 429 ? { "retry-after": "600" } : {});
      }
    } finally {
      if (admitted) active--;
      response.removeListener?.("close", abort);
    }
  }
}

function readBody(request, limit) {
  if (Number(request.headers?.["content-length"]) > limit) return Promise.reject(new ImportError(413, "input_too_large", "Import text is too large."));
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0;
    const cleanup = () => { clearTimeout(timer); request.removeListener("data", onData); request.removeListener("end", onEnd); request.removeListener("error", onError); request.removeListener("aborted", onAborted); };
    const fail = error => { cleanup(); reject(error); };
    const onData = chunk => { size += chunk.length; if (size > limit) fail(new ImportError(413, "input_too_large", "Import text is too large.")); else chunks.push(chunk); };
    const onEnd = () => { cleanup(); resolve(Buffer.concat(chunks).toString("utf8")); };
    const onError = () => fail(new ImportError(400, "invalid_request", "The request body could not be read."));
    const onAborted = () => fail(new ImportError(400, "request_cancelled", "The import request was cancelled."));
    const timer = setTimeout(() => fail(new ImportError(408, "request_timeout", "The import request took too long to upload.")), 5000);
    request.on("data", onData); request.once("end", onEnd); request.once("error", onError); request.once("aborted", onAborted);
  });
}
