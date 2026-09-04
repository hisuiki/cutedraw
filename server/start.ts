import { resolve } from "node:path";

import { createCutedrawServer } from "./index";

const port = Number.parseInt(process.env.PORT ?? "8080", 10);
const staticDirectory = resolve(
  process.env.STATIC_DIR ?? "excalidraw-app/build",
);
const { server } = createCutedrawServer(staticDirectory);

server.listen(port, "0.0.0.0", () => {
  console.info(`Cutedraw is listening on port ${port}`);
});
