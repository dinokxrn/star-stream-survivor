import { DurableObject } from "cloudflare:workers";

const MAX_PLAYERS = 4;

export class CoopRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.headers.get("Upgrade") !== "websocket") {
      const peers = this._listPlayers();
      return Response.json(
        {
          room: url.pathname.split("/").pop() || "",
          players: peers.length,
          max_players: MAX_PLAYERS,
        },
        { headers: { "Access-Control-Allow-Origin": "*" } }
      );
    }

    const active = this.ctx.getWebSockets();
    if (active.length >= MAX_PLAYERS) {
      return new Response("Room is full (4/4)", {
        status: 403,
        headers: { "Access-Control-Allow-Origin": "*" },
      });
    }

    const roomCode = (url.searchParams.get("room") || url.pathname.split("/").pop() || "0000")
      .toUpperCase()
      .slice(0, 6);
    const name = (url.searchParams.get("name") || "ผู้รอดชีวิต").slice(0, 24);
    const charIdx = Math.max(0, Math.min(19, parseInt(url.searchParams.get("char") || "0", 10) || 0));
    const attrId = (url.searchParams.get("attr") || "office_worker").slice(0, 40);

    const usedIds = new Set(
      active.map((ws) => {
        const a = ws.deserializeAttachment();
        return a ? a.peer_id : "";
      })
    );
    let peerId = "p1";
    for (let i = 1; i <= 8; i++) {
      if (!usedIds.has(`p${i}`)) {
        peerId = `p${i}`;
        break;
      }
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    let roomState = (await this.ctx.storage.get("room_state")) || {
      host_id: "",
      stage: 1,
      started: false,
      room_code: roomCode,
    };
    if (!roomState.host_id || !usedIds.has(roomState.host_id)) {
      roomState.host_id = peerId;
      roomState.started = false;
      roomState.stage = 1;
    }
    roomState.room_code = roomCode;
    await this.ctx.storage.put("room_state", roomState);

    const attachment = {
      peer_id: peerId,
      name,
      char_idx: charIdx,
      attr_id: attrId,
      hp: 100,
      max_hp: 100,
    };

    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(attachment);

    const players = this._listPlayers();
    server.send(
      JSON.stringify({
        type: "welcome",
        peer_id: peerId,
        host_id: roomState.host_id,
        room_code: roomCode,
        stage: roomState.stage,
        started: roomState.started,
        players,
      })
    );

    this._broadcast(
      {
        type: "room_update",
        host_id: roomState.host_id,
        room_code: roomCode,
        stage: roomState.stage,
        started: roomState.started,
        players,
        event: "join",
        actor_id: peerId,
        actor_name: name,
      },
      server
    );

    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    if (typeof message !== "string") return;
    let data;
    try {
      data = JSON.parse(message);
    } catch {
      return;
    }
    const att = ws.deserializeAttachment();
    if (!att) return;

    const msgType = data.type;
    if (!msgType) return;

    if (msgType === "ping") {
      ws.send(JSON.stringify({ type: "pong", t: data.t || Date.now() }));
      return;
    }

    if (msgType === "profile_update") {
      att.name = String(data.name || att.name).slice(0, 24);
      att.char_idx = Math.max(0, Math.min(19, Number(data.char_idx ?? att.char_idx) || 0));
      att.attr_id = String(data.attr_id || att.attr_id).slice(0, 40);
      ws.serializeAttachment(att);
      const roomState = (await this.ctx.storage.get("room_state")) || {
        host_id: att.peer_id,
        stage: 1,
        started: false,
        room_code: "0000",
      };
      this._broadcast({
        type: "room_update",
        host_id: roomState.host_id,
        room_code: roomState.room_code,
        stage: roomState.stage,
        started: roomState.started,
        players: this._listPlayers(),
      });
      return;
    }

    if (msgType === "stage_start") {
      const roomState = (await this.ctx.storage.get("room_state")) || {
        host_id: att.peer_id,
        stage: 1,
        started: true,
        room_code: "0000",
      };
      if (roomState.host_id === att.peer_id) {
        roomState.stage = Math.max(1, Math.min(4, Number(data.stage) || 1));
        roomState.started = true;
        await this.ctx.storage.put("room_state", roomState);
        this._broadcast({
          type: "stage_start",
          stage: roomState.stage,
          host_id: roomState.host_id,
          players: this._listPlayers(),
        });
      }
      return;
    }

    if (msgType === "player_state") {
      if (typeof data.hp === "number") att.hp = data.hp;
      if (typeof data.max_hp === "number") att.max_hp = data.max_hp;
      ws.serializeAttachment(att);
      data.peer_id = att.peer_id;
      data.name = att.name;
      data.char_idx = att.char_idx;
      data.attr_id = att.attr_id;
      this._broadcast(data, ws);
      return;
    }

    // Relay gameplay events to other peers in the room
    if (
      msgType === "player_fx" ||
      msgType === "enemy_hit" ||
      msgType === "enemy_sync" ||
      msgType === "scenario_sync" ||
      msgType === "revive" ||
      msgType === "chat_toast"
    ) {
      data.peer_id = att.peer_id;
      this._broadcast(data, ws);
    }
  }

  async webSocketClose(ws) {
    await this._handleLeave(ws);
  }

  async webSocketError(ws) {
    await this._handleLeave(ws);
  }

  async _handleLeave(ws) {
    const att = ws.deserializeAttachment();
    try {
      ws.close();
    } catch {}
    const remaining = this.ctx.getWebSockets().filter((s) => s !== ws);
    if (remaining.length === 0) {
      await this.ctx.storage.delete("room_state");
      return;
    }
    let roomState = (await this.ctx.storage.get("room_state")) || {
      host_id: "",
      stage: 1,
      started: false,
      room_code: "0000",
    };
    const players = remaining
      .map((s) => s.deserializeAttachment())
      .filter(Boolean);
    if (att && roomState.host_id === att.peer_id && players.length > 0) {
      roomState.host_id = players[0].peer_id;
      await this.ctx.storage.put("room_state", roomState);
    }
    this._broadcast(
      {
        type: "room_update",
        host_id: roomState.host_id,
        room_code: roomState.room_code,
        stage: roomState.stage,
        started: roomState.started,
        players,
        event: "leave",
        actor_id: att ? att.peer_id : "",
        actor_name: att ? att.name : "",
      },
      ws
    );
  }

  _listPlayers() {
    return this.ctx
      .getWebSockets()
      .map((s) => s.deserializeAttachment())
      .filter(Boolean);
  }

  _broadcast(payload, excludeWs = null) {
    const raw = JSON.stringify(payload);
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === excludeWs) continue;
      try {
        ws.send(raw);
      } catch {}
    }
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "*",
        },
      });
    }

    if (url.pathname === "/" || url.pathname === "/health") {
      return Response.json(
        { ok: true, service: "star-stream-coop", max_players: MAX_PLAYERS },
        { headers: { "Access-Control-Allow-Origin": "*" } }
      );
    }

    const match = url.pathname.match(/^\/room\/([A-Za-z0-9_-]{2,12})$/);
    if (match) {
      const code = match[1].toUpperCase();
      const stub = env.COOP_ROOM.getByName(code);
      return stub.fetch(request);
    }

    return new Response("Not Found", { status: 404 });
  },
};
