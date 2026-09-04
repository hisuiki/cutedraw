import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { io as createClient } from "socket.io-client";

import { createCutedrawServer } from "./index";

import type { Socket } from "socket.io-client";

const waitForEvent = <T>(socket: Socket, event: string) =>
  new Promise<T>((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(new Error(`Timed out waiting for ${event}`)),
      2_000,
    );
    socket.once(event, (value: T) => {
      clearTimeout(timeout);
      resolve(value);
    });
  });

test("collaboration clients join, exchange updates, follow, and leave", async () => {
  const staticDirectory = mkdtempSync(join(tmpdir(), "cutedraw-server-"));
  writeFileSync(join(staticDirectory, "index.html"), "Cutedraw");

  const { io, server } = createCutedrawServer(staticDirectory);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));

  const address = server.address();
  assert(address && typeof address !== "string");
  const serverUrl = `http://127.0.0.1:${address.port}`;
  const clients: Socket[] = [];

  const connectToRoom = (roomId: string) => {
    const client = createClient(serverUrl, {
      autoConnect: false,
      forceNew: true,
      reconnection: false,
      transports: ["websocket"],
    });
    clients.push(client);
    client.on("init-room", () => client.emit("join-room", roomId));
    client.connect();
    return client;
  };

  try {
    const first = connectToRoom("room_1");
    const firstInRoom = waitForEvent(first, "first-in-room");
    const firstUsers = waitForEvent<string[]>(first, "room-user-change");
    await firstInRoom;
    assert.deepEqual(await firstUsers, [first.id]);

    const newUser = waitForEvent<string>(first, "new-user");
    const twoUsers = waitForEvent<string[]>(first, "room-user-change");
    const second = connectToRoom("room_1");
    assert.equal(await newUser, second.id);
    assert.deepEqual(new Set(await twoUsers), new Set([first.id, second.id]));

    const sceneUpdate = new Promise<[Uint8Array, Uint8Array]>((resolve) => {
      second.once("client-broadcast", (encryptedData, iv) => {
        resolve([encryptedData, iv]);
      });
    });
    first.emit(
      "server-broadcast",
      "room_1",
      Uint8Array.from([1, 2, 3]),
      Uint8Array.from([4, 5]),
    );
    const [encryptedData, iv] = await sceneUpdate;
    assert.deepEqual([...encryptedData], [1, 2, 3]);
    assert.deepEqual([...iv], [4, 5]);

    const followedBy = waitForEvent<string[]>(first, "user-follow-room-change");
    second.emit("user-follow", {
      action: "FOLLOW",
      userToFollow: { socketId: first.id, username: "first" },
    });
    assert.deepEqual(await followedBy, [second.id]);

    const remainingUsers = waitForEvent<string[]>(first, "room-user-change");
    second.disconnect();
    assert.deepEqual(await remainingUsers, [first.id]);

    const response = await fetch(`${serverUrl}/healthz`);
    assert.equal(response.status, 200);
    assert.equal(await response.text(), "ok");
  } finally {
    for (const client of clients) {
      client.disconnect();
    }
    await io.close();
    if (server.listening) {
      await new Promise<void>((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
    }
    rmSync(staticDirectory, { recursive: true, force: true });
  }
});
