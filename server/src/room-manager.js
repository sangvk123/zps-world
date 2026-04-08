const OPEN = 1; // WebSocket.OPEN

class RoomManager {
  constructor(registry) {
    this._registry = registry;
    this._zones = new Map(); // zone -> Set<playerId>
  }

  join(playerId, zone) {
    if (!this._zones.has(zone)) this._zones.set(zone, new Set());
    this._zones.get(zone).add(playerId);
  }

  leave(playerId, zone) {
    this._zones.get(zone)?.delete(playerId);
  }

  // Broadcast to all in zone except excludeId
  broadcast(zone, msg, excludeId = null) {
    const payload = JSON.stringify(msg);
    const members = this._zones.get(zone);
    if (!members) return;
    for (const pid of members) {
      if (pid === excludeId) continue;
      const p = this._registry.get(pid);
      if (p?.ws?.readyState === OPEN) p.ws.send(payload);
    }
  }

  // Broadcast to all in zone including sender
  broadcastToZone(zone, msg) {
    const payload = JSON.stringify(msg);
    const members = this._zones.get(zone);
    if (!members) return;
    for (const pid of members) {
      const p = this._registry.get(pid);
      if (p?.ws?.readyState === OPEN) p.ws.send(payload);
    }
  }

  getAllZones() {
    return this._zones;
  }
}

module.exports = RoomManager;
