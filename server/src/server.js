const { WebSocketServer } = require('ws');
const PlayerRegistry = require('./player-registry');
const RoomManager = require('./room-manager');

const PORT = process.env.PORT || 3001;
const TICK_MS = 50; // 20Hz position broadcast

const registry = new PlayerRegistry();
const rooms = new RoomManager(registry);

const wss = new WebSocketServer({ port: PORT });

wss.on('connection', (ws) => {
  let playerId = null;

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    if (msg.type === 'player_join') {
      playerId = msg.id;
      registry.add(playerId, { ws, x: msg.x, y: msg.y, avatar: msg.avatar, zone: msg.zone || 'main' });
      rooms.join(playerId, msg.zone || 'main');
      rooms.broadcast(msg.zone || 'main', { type: 'player_joined', id: playerId, x: msg.x, y: msg.y, avatar: msg.avatar }, playerId);
      // Send current roster to new player
      ws.send(JSON.stringify({ type: 'roster', players: registry.getRoster(playerId) }));
    }

    if (msg.type === 'move' && playerId) {
      registry.updatePosition(playerId, msg.x, msg.y);
    }

    if (msg.type === 'chat' && playerId) {
      const player = registry.get(playerId);
      rooms.broadcast(player.zone, { type: 'chat', from: playerId, text: msg.text, ts: Date.now() });
    }

    if (msg.type === 'emote' && playerId) {
      const player = registry.get(playerId);
      rooms.broadcast(player.zone, { type: 'emote', from: playerId, emote: msg.emote });
    }

    if (msg.type === 'status' && playerId) {
      registry.updateStatus(playerId, msg.status, msg.message || '');
      const player = registry.get(playerId);
      rooms.broadcast(player.zone, { type: 'status_changed', id: playerId, status: msg.status, message: msg.message || '' });
    }
  });

  ws.on('close', () => {
    if (!playerId) return;
    const player = registry.get(playerId);
    if (player) {
      rooms.broadcast(player.zone, { type: 'player_left', id: playerId });
      rooms.leave(playerId, player.zone);
    }
    registry.remove(playerId);
  });

  ws.on('error', () => {
    if (playerId) registry.remove(playerId);
  });
});

// Position broadcast tick
setInterval(() => {
  for (const [zone, playerIds] of rooms.getAllZones()) {
    if (playerIds.size === 0) continue;
    const positions = [];
    for (const pid of playerIds) {
      const p = registry.get(pid);
      if (p) positions.push({ id: pid, x: p.x, y: p.y });
    }
    if (positions.length === 0) continue;
    rooms.broadcastToZone(zone, { type: 'positions', data: positions });
  }
}, TICK_MS);

console.log(`[ZPS World Server] Listening on ws://localhost:${PORT}`);
module.exports = { wss, registry, rooms };
