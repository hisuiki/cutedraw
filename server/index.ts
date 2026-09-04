import { createServer } from "node:http";

import { attachCollaborationServer } from "./collaboration";
import { createStaticHandler } from "./http";

export const createCutedrawServer = (staticDirectory: string) => {
  const server = createServer(createStaticHandler(staticDirectory));
  const io = attachCollaborationServer(server);

  return { io, server };
};
