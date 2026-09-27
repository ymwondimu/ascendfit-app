import assert from "node:assert/strict";
import { test } from "node:test";
import { createRequestHandler } from "../src/app.mjs";

function invoke(method, url) {
  let status;
  let headers;
  let body;
  const response = {
    writeHead(value, valueHeaders) {
      status = value;
      headers = valueHeaders;
    },
    end(value) {
      body = JSON.parse(value);
    },
  };

  createRequestHandler()({ method, url }, response);
  return { status, headers, body };
}

test("GET /health reports service readiness", () => {
  const result = invoke("GET", "/health");

  assert.equal(result.status, 200);
  assert.equal(result.headers["cache-control"], "no-store");
  assert.deepEqual(result.body, {
    status: "ok",
    service: "ascend-fit-api",
  });
});

test("unknown routes return a small JSON 404", () => {
  const result = invoke("GET", "/missing");

  assert.equal(result.status, 404);
  assert.deepEqual(result.body, { error: "not_found" });
});
