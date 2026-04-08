class PlayerRegistry {
  constructor() {
    this._players = new Map(); // id -> { ws, x, y, avatar, zone, status, statusMessage }
  }

  add(id, data) {
    this._players.set(id, {
      ws: data.ws,
      x: data.x,
      y: data.y,
      avatar: data.avatar || {},
      zone: data.zone || 'main',
      status: data.status || 'available',
      statusMessage: data.statusMessage || '',
    });
  }

  get(id) {
    return this._players.get(id);
  }

  remove(id) {
    this._players.delete(id);
  }

  updatePosition(id, x, y) {
    const p = this._players.get(id);
    if (!p) return;
    p.x = x;
    p.y = y;
  }

  updateStatus(id, status, statusMessage) {
    const p = this._players.get(id);
    if (!p) return;
    p.status = status;
    p.statusMessage = statusMessage;
  }

  // Returns serializable roster for all players except excludeId
  getRoster(excludeId) {
    const result = [];
    for (const [id, p] of this._players) {
      if (id === excludeId) continue;
      result.push({ id, x: p.x, y: p.y, avatar: p.avatar, zone: p.zone, status: p.status, statusMessage: p.statusMessage });
    }
    return result;
  }

  getAll() {
    return this._players;
  }
}

module.exports = PlayerRegistry;
