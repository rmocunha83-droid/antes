import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const port = Number(process.env.PREVIEW_PORT || 8791);

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".png": "image/png"
};

createServer(async (request, response) => {
  try {
    const url = new URL(request.url || "/", `http://127.0.0.1:${port}`);
    const pathname = decodeURIComponent(url.pathname === "/" ? "/Preview/index.html" : url.pathname);
    const filePath = join(root, pathname);

    if (!filePath.startsWith(root)) {
      response.writeHead(403);
      response.end("Forbidden");
      return;
    }

    const data = await readFile(filePath);
    response.writeHead(200, {
      "Content-Type": contentTypes[extname(filePath)] || "application/octet-stream"
    });
    response.end(data);
  } catch {
    response.writeHead(404);
    response.end("Not found");
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`Antes preview running at http://127.0.0.1:${port}/Preview/index.html`);
});
