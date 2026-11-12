// Tiny static server for the example site, so the kit can be tested with no product.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT ?? 4173);
const pages = { "/": "index.html", "/welcome": "welcome.html" };

createServer(async (req, res) => {
  const { pathname } = new URL(req.url ?? "/", "http://localhost");
  const file = pages[pathname];
  if (!file) {
    res.writeHead(404).end("Not found");
    return;
  }
  res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  res.end(await readFile(path.join(root, file)));
}).listen(port, "127.0.0.1", () => {
  console.log(`example site on http://127.0.0.1:${port}`);
});
