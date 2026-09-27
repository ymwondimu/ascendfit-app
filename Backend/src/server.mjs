import { createServer } from "node:http";
import { createRequestHandler } from "./app.mjs";

const port = Number.parseInt(process.env.PORT ?? "8787", 10);
const server = createServer(createRequestHandler());

server.listen(port, "127.0.0.1", () => {
  console.log(`Ascend Fit API listening on http://127.0.0.1:${port}`);
});
