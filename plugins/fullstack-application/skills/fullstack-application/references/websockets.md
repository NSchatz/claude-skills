---
title: WebSockets and Real-Time
weight: 8
---

# WebSockets and Real-Time

This reference covers Socket.IO with NestJS gateways, JWT authentication for WebSocket connections, rooms, broadcasting, and frontend integration.

## Table of Contents

- [Setup](#setup)
- [Gateway Pattern](#gateway-pattern)
- [JWT Authentication](#jwt-authentication)
- [Rooms and Broadcasting](#rooms-and-broadcasting)
- [Redis Adapter for Multi-Instance](#redis-adapter-for-multi-instance)
- [Frontend Client](#frontend-client)
- [RTK Query Integration](#rtk-query-integration)

---

## Setup

```bash
pnpm add @nestjs/websockets @nestjs/platform-socket.io socket.io
# Frontend:
pnpm add socket.io-client
```

---

## Gateway Pattern

A gateway is a NestJS WebSocket handler, analogous to a controller for HTTP.

```ts
// modules/chat/chat.gateway.ts
import {
  WebSocketGateway, WebSocketServer, SubscribeMessage,
  OnGatewayConnection, OnGatewayDisconnect,
  ConnectedSocket, MessageBody, WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UsePipes, ValidationPipe } from '@nestjs/common';

@WebSocketGateway({
  namespace: '/chat',
  cors: {
    origin: process.env.FRONTEND_URL,
    credentials: true,
  },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private authService: AuthService,
    private chatService: ChatService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token
        ?? client.handshake.headers?.authorization?.split(' ')[1];
      if (!token) throw new Error('No token');

      const user = await this.authService.verifyToken(token);
      client.data.user = user;

      // Join user's personal room for targeted messages
      await client.join(`user:${user.id}`);
      this.server.emit('user:online', { userId: user.id });
    } catch {
      client.emit('error', { message: 'Authentication failed' });
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: Socket) {
    if (client.data.user) {
      this.server.emit('user:offline', { userId: client.data.user.id });
    }
  }

  @SubscribeMessage('chat:join-room')
  async joinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    const hasAccess = await this.chatService.checkAccess(client.data.user.id, data.roomId);
    if (!hasAccess) throw new WsException('Forbidden');

    await client.join(`room:${data.roomId}`);
    return { event: 'chat:joined', data: { roomId: data.roomId } };
  }

  @SubscribeMessage('chat:message')
  @UsePipes(new ValidationPipe({ transform: true }))
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: SendMessageDto,
  ) {
    const message = await this.chatService.createMessage({
      roomId: data.roomId,
      userId: client.data.user.id,
      content: data.content,
    });

    // Broadcast to room, excluding sender
    client.to(`room:${data.roomId}`).emit('chat:message', message);

    // Acknowledge to sender
    return { event: 'chat:message:ack', data: message };
  }
}
```

---

## JWT Authentication

Authenticate on connection, not on every message. Store the verified user on `client.data`.

```ts
// Gateway handleConnection (shown above) verifies the token once.
// For per-message authorization, use a guard:

@Injectable()
export class WsJwtGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const client: Socket = context.switchToWs().getClient();
    if (!client.data.user) throw new WsException('Unauthorized');
    return true;
  }
}

// Usage:
@UseGuards(WsJwtGuard)
@SubscribeMessage('chat:message')
async handleMessage(/* ... */) {}
```

---

## Rooms and Broadcasting

| Method | Scope |
|--------|-------|
| `server.emit(event, data)` | All connected clients |
| `server.to('room:123').emit(event, data)` | All clients in room |
| `client.to('room:123').emit(event, data)` | All clients in room except sender |
| `server.to('user:abc').emit(event, data)` | Specific user (all their tabs/devices) |

### Broadcasting from Services

Inject the gateway to emit from anywhere in the application:

```ts
@Injectable()
export class NotificationsService {
  constructor(private chatGateway: ChatGateway) {}

  async notifyUser(userId: string, payload: unknown) {
    this.chatGateway.server.to(`user:${userId}`).emit('notification', payload);
  }
}
```

---

## Redis Adapter for Multi-Instance

Required when running multiple API instances behind a load balancer. Without this, events only reach clients connected to the same instance.

```bash
pnpm add @socket.io/redis-adapter redis
```

```ts
// infrastructure/websocket/redis-io-adapter.ts
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';
import type { ServerOptions } from 'socket.io';

export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor: ReturnType<typeof createAdapter>;

  async connectToRedis(redisUrl: string) {
    const pubClient = createClient({ url: redisUrl });
    const subClient = pubClient.duplicate();
    await Promise.all([pubClient.connect(), subClient.connect()]);
    this.adapterConstructor = createAdapter(pubClient, subClient);
  }

  createIOServer(port: number, options?: ServerOptions) {
    const server = super.createIOServer(port, options);
    server.adapter(this.adapterConstructor);
    return server;
  }
}

// main.ts
const redisAdapter = new RedisIoAdapter(app);
await redisAdapter.connectToRedis(process.env.REDIS_URL);
app.useWebSocketAdapter(redisAdapter);
```

---

## Frontend Client

```ts
// lib/socket.ts
import { io, Socket } from 'socket.io-client';

let socket: Socket | null = null;

export function getSocket(token: string): Socket {
  if (socket?.connected) return socket;

  socket = io(`${import.meta.env.VITE_API_URL}/chat`, {
    auth: { token },
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 30000,
    randomizationFactor: 0.5,
  });

  socket.on('connect', () => console.log('WS connected'));
  socket.on('disconnect', (reason) => {
    if (reason === 'io server disconnect') {
      // Server kicked us — likely auth issue, need to re-authenticate
      refreshTokenAndReconnect(socket!);
    }
    // Other reasons: the client will auto-reconnect
  });

  return socket;
}

export function disconnectSocket() {
  socket?.disconnect();
  socket = null;
}
```

---

## RTK Query Integration

Use `onCacheEntryAdded` for streaming WebSocket updates into the RTK Query cache:

```ts
// store/api/chatApi.ts
import { baseApi } from './baseApi';
import { getSocket } from '@/lib/socket';

export const chatApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getMessages: builder.query<Message[], string>({
      queryFn: () => ({ data: [] }),
      async onCacheEntryAdded(roomId, { updateCachedData, cacheEntryRemoved }) {
        const socket = getSocket(getStoredToken());
        socket.emit('chat:join-room', { roomId });

        const listener = (message: Message) => {
          updateCachedData((draft) => { draft.push(message); });
        };
        socket.on('chat:message', listener);

        await cacheEntryRemoved;
        socket.off('chat:message', listener);
        socket.emit('chat:leave-room', { roomId });
      },
    }),

    sendMessage: builder.mutation<Message, { roomId: string; content: string }>({
      queryFn: ({ roomId, content }) => new Promise((resolve) => {
        const socket = getSocket(getStoredToken());
        socket.emit('chat:message', { roomId, content }, (response: { data: Message }) => {
          resolve({ data: response.data });
        });
      }),
    }),
  }),
});
```

### Shared Types

Put WebSocket event types in `packages/shared` so both API and frontend use the same contract:

```ts
// packages/shared/src/ws-events.ts
export interface ChatMessageEvent {
  roomId: string;
  userId: string;
  content: string;
  createdAt: string;
}

export interface UserPresenceEvent {
  userId: string;
}
```
