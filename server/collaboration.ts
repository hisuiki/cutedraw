import { Server as SocketIOServer } from "socket.io";

import type { Server as HttpServer } from "node:http";

type FollowPayload = {
  userToFollow: {
    socketId: string;
    username: string;
  };
  action: "FOLLOW" | "UNFOLLOW";
};

const isRoomId = (value: unknown): value is string =>
  typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);

export const attachCollaborationServer = (server: HttpServer) => {
  const io = new SocketIOServer(server, {
    transports: ["websocket", "polling"],
    maxHttpBufferSize: 10_000_000,
    cors: {
      origin: process.env.CORS_ORIGIN?.split(",").map((origin) =>
        origin.trim(),
      ) ?? [
        "https://cutedraw.app",
        "https://www.cutedraw.app",
        "http://localhost:3001",
      ],
      credentials: true,
    },
  });

  const emitRoomUsers = async (roomId: string) => {
    const sockets = await io.in(roomId).fetchSockets();
    io.in(roomId).emit(
      "room-user-change",
      sockets.map((socket) => socket.id),
    );
  };

  const emitFollowers = async (followedSocketId: string) => {
    const sockets = await io.in(`follow@${followedSocketId}`).fetchSockets();
    io.to(followedSocketId).emit(
      "user-follow-room-change",
      sockets.map((socket) => socket.id),
    );
  };

  io.on("connection", (socket) => {
    socket.emit("init-room");

    socket.on("join-room", async (roomId: unknown) => {
      if (!isRoomId(roomId)) {
        return;
      }

      const previousRoomId = socket.data.roomId as string | undefined;
      if (previousRoomId && previousRoomId !== roomId) {
        await socket.leave(previousRoomId);
        await emitRoomUsers(previousRoomId);
      }

      socket.data.roomId = roomId;
      await socket.join(roomId);

      const sockets = await io.in(roomId).fetchSockets();
      if (sockets.length === 1) {
        socket.emit("first-in-room");
      } else {
        socket.broadcast.to(roomId).emit("new-user", socket.id);
      }

      await emitRoomUsers(roomId);
    });

    const broadcast = (
      roomId: unknown,
      encryptedData: ArrayBuffer,
      iv: Uint8Array,
      volatile: boolean,
    ) => {
      if (typeof roomId !== "string") {
        return;
      }

      const isOwnFollowRoom = roomId === `follow@${socket.id}`;
      if (socket.data.roomId !== roomId && !isOwnFollowRoom) {
        return;
      }

      const target = volatile ? socket.volatile.broadcast : socket.broadcast;
      target.to(roomId).emit("client-broadcast", encryptedData, iv);
    };

    socket.on("server-broadcast", (roomId, encryptedData, iv) => {
      broadcast(roomId, encryptedData, iv, false);
    });

    socket.on("server-volatile-broadcast", (roomId, encryptedData, iv) => {
      broadcast(roomId, encryptedData, iv, true);
    });

    socket.on("user-follow", async (payload: FollowPayload) => {
      const followedSocketId = payload?.userToFollow?.socketId;
      const followedSocket =
        typeof followedSocketId === "string"
          ? io.sockets.sockets.get(followedSocketId)
          : undefined;
      if (
        !followedSocket ||
        !socket.data.roomId ||
        followedSocket.data.roomId !== socket.data.roomId
      ) {
        return;
      }

      const roomId = `follow@${followedSocketId}`;
      if (payload.action === "FOLLOW") {
        await socket.join(roomId);
      } else if (payload.action === "UNFOLLOW") {
        await socket.leave(roomId);
      } else {
        return;
      }

      await emitFollowers(followedSocketId);
    });

    socket.on("disconnecting", async () => {
      const ownFollowRoom = `follow@${socket.id}`;
      io.in(ownFollowRoom).emit("broadcast-unfollow");
      io.in(ownFollowRoom).socketsLeave(ownFollowRoom);

      const roomId = socket.data.roomId as string | undefined;
      if (roomId) {
        socket.data.roomId = undefined;
        await socket.leave(roomId);
        await emitRoomUsers(roomId);
      }

      const followedSocketIds = [...socket.rooms]
        .filter((room) => room.startsWith("follow@"))
        .map((room) => room.slice("follow@".length));
      await Promise.all(
        followedSocketIds.map(async (followedSocketId) => {
          await socket.leave(`follow@${followedSocketId}`);
          await emitFollowers(followedSocketId);
        }),
      );
    });
  });

  return io;
};
