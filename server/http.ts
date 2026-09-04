import { createReadStream, statSync } from "node:fs";
import { extname, resolve, sep } from "node:path";

import type { IncomingMessage, ServerResponse } from "node:http";

const MIME_TYPES: Readonly<Record<string, string>> = {
  ".css": "text/css; charset=utf-8",
  ".gif": "image/gif",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".jpeg": "image/jpeg",
  ".jpg": "image/jpeg",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".map": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8",
  ".wasm": "application/wasm",
  ".webmanifest": "application/manifest+json",
  ".woff2": "font/woff2",
};

const sendFile = (
  request: IncomingMessage,
  response: ServerResponse,
  filePath: string,
  cacheControl: string,
) => {
  response.statusCode = 200;
  response.setHeader(
    "Content-Type",
    MIME_TYPES[extname(filePath).toLowerCase()] ?? "application/octet-stream",
  );
  response.setHeader("Content-Length", statSync(filePath).size);
  response.setHeader("Cache-Control", cacheControl);

  if (request.method === "HEAD") {
    response.end();
    return;
  }

  const stream = createReadStream(filePath);
  stream.on("error", () => {
    if (!response.headersSent) {
      response.statusCode = 500;
    }
    response.end();
  });
  stream.pipe(response);
};

export const createStaticHandler = (staticDirectory: string) => {
  const root = resolve(staticDirectory);
  const indexPath = resolve(root, "index.html");

  return (request: IncomingMessage, response: ServerResponse) => {
    if (request.url === "/healthz") {
      response.writeHead(200, {
        "Cache-Control": "no-store",
        "Content-Type": "text/plain; charset=utf-8",
      });
      response.end("ok");
      return;
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      response.writeHead(405, { Allow: "GET, HEAD" });
      response.end();
      return;
    }

    let pathname: string;
    try {
      pathname = decodeURIComponent(
        new URL(request.url ?? "/", "http://localhost").pathname,
      );
    } catch {
      response.writeHead(400);
      response.end();
      return;
    }

    const filePath = resolve(root, `.${pathname}`);
    const isInsideRoot =
      filePath === root || filePath.startsWith(`${root}${sep}`);
    const isFile =
      isInsideRoot &&
      (() => {
        try {
          return statSync(filePath).isFile();
        } catch {
          return false;
        }
      })();

    if (isFile) {
      const cacheControl = pathname.startsWith("/assets/")
        ? "public, max-age=31536000, immutable"
        : pathname.startsWith("/fonts/")
        ? "public, max-age=2592000"
        : "no-cache, no-store, must-revalidate";
      sendFile(request, response, filePath, cacheControl);
      return;
    }

    if (pathname.startsWith("/assets/") || pathname.startsWith("/fonts/")) {
      response.writeHead(404);
      response.end();
      return;
    }

    sendFile(
      request,
      response,
      indexPath,
      "no-cache, no-store, must-revalidate",
    );
  };
};
