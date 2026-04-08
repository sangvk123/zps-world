# Sprint 2 — Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real employees see each other moving in the same office in real-time, with seamless NPC fallback when any player disconnects.

**Architecture:** A Node.js WebSocket server relays position, chat, and presence events at 50ms tick rate. The Godot WASM client connects on startup via a `NetworkManager` autoload singleton. For each remote peer, a `RemotePlayer` node is spawned — visually identical to an NPC but driven by network position. On disconnect, the `RemotePlayer` switches to AI-driven NPC mode without removing the character from the world.

**Tech Stack:** Node.js 20, `ws` library, Jest (server tests), Godot 4.6 GDScript, no additional Godot plugins required.

---

## Scope Note

The full MDD spans 6 sprints. Each sprint gets its own plan:
- Sprint 1 — Asset Integration (art/sprites, no server code)
- **Sprint 2 — Multiplayer ← this plan**
- Sprint 3 — Backend + MVP (NestJS API, SSO, HR, task manager)
- Sprint 4 — Avatar Depth (ZPS Member sync)
- Sprint 5 — Events + Minigames
- Sprint 6 — 3D Exploration (future)

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `server/package.json` | Node.js deps (ws, jest) |
| `server/src/server.js` | WS server entry — accept connections, dispatch messages |
| `server/src/player-registry.js` | In-memory map of connected players (id → state) |
| `server/src/room-manager.js` | Zone-based channel namespacing, broadcast helpers |
| `server/tests/server.test.js` | Jest tests for registry + room logic |
| `scripts/autoloads/NetworkManager.gd` | Godot WS client — connect, send, receive, dispatch signals |
| `scripts/world/RemotePlayer.gd` | Network-driven character node (position lerp + NPC fallback) |
| `scripts/ui/ChatLog.gd` | Persistent scrollable chat panel (all messages, all radii) |

### Modified Files
| File | Change |
|------|--------|
| `project.godot` | Add `NetworkManager` to `[autoload]` section |
| `scripts/autoloads/GameManager.gd` | Add `remote_player_joined/left` signals + `remote_players` dict |
| `scripts/player/Player.gd` | Call `NetworkManager.send_position()` in `_physics_process` |
| `scripts/ui/HUD.gd` | Add online roster panel + chat log toggle button |

---

## Task 1: Node.js Server — Foundation

**Files:**
- Create: `server/package.json`
- Create: `server/src/server.js`

- [ ] **Step 1: Create server directory and package.json**

```bash
mkdir -p server/src server/tests
```

Create `server/package.json`:
```json
{
  "name": "zps-world-server",
  "version": "1.0.0",
  "description": "ZPS World WebSocket multiplayer server",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "node --watch src/server.js",
    "test": "jest"
  },
  "dependencies": {
    "ws": "^8.18.0"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  },
  "jest": {
    "testEnvironment": "node"
  }
}
```

- [ ] **Step 2: Install dependencies**

```bash
cd server && npm install
```

Expected: `node_modules/` created, no errors.

- [ ] **Step 3: Create server.js**

Create `server/src/server.js`:
```javascript
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
```

- [ ] **Step 4: Start server and verify it listens**

```bash
cd server && node src/server.js
```

Expected output: `[ZPS World Server] Listening on ws://localhost:3001`

Stop with Ctrl+C.

- [ ] **Step 5: Commit**

```bash
cd server
git add package.json package-lock.json src/server.js
git commit -m "feat(server): add Node.js WebSocket server foundation"
```

---

## Task 2: Player Registry

**Files:**
- Create: `server/src/player-registry.js`
- Create: `server/tests/server.test.js` (partial — registry tests)

- [ ] **Step 1: Write failing test for PlayerRegistry**

Create `server/tests/server.test.js`:
```javascript
const PlayerRegistry = require('../src/player-registry');

describe('PlayerRegistry', () => {
  let registry;
  const mockWs = { send: jest.fn(), readyState: 1 };

  beforeEach(() => { registry = new PlayerRegistry(); });

  test('add and get player', () => {
    registry.add('p1', { ws: mockWs, x: 100, y: 200, avatar: {}, zone: 'main' });
    const p = registry.get('p1');
    expect(p.x).toBe(100);
    expect(p.y).toBe(200);
    expect(p.zone).toBe('main');
  });

  test('updatePosition changes x and y', () => {
    registry.add('p1', { ws: mockWs, x: 0, y: 0, avatar: {}, zone: 'main' });
    registry.updatePosition('p1', 300, 400);
    const p = registry.get('p1');
    expect(p.x).toBe(300);
    expect(p.y).toBe(400);
  });

  test('remove deletes player', () => {
    registry.add('p1', { ws: mockWs, x: 0, y: 0, avatar: {}, zone: 'main' });
    registry.remove('p1');
    expect(registry.get('p1')).toBeUndefined();
  });

  test('getRoster excludes self', () => {
    registry.add('p1', { ws: mockWs, x: 10, y: 20, avatar: { hair: 'short' }, zone: 'main', status: 'available', statusMessage: '' });
    registry.add('p2', { ws: mockWs, x: 30, y: 40, avatar: { hair: 'long' }, zone: 'main', status: 'available', statusMessage: '' });
    const roster = registry.getRoster('p1');
    expect(roster).toHaveLength(1);
    expect(roster[0].id).toBe('p2');
  });

  test('updateStatus updates status and message', () => {
    registry.add('p1', { ws: mockWs, x: 0, y: 0, avatar: {}, zone: 'main', status: 'available', statusMessage: '' });
    registry.updateStatus('p1', 'busy', 'In meeting');
    const p = registry.get('p1');
    expect(p.status).toBe('busy');
    expect(p.statusMessage).toBe('In meeting');
  });
});
```

- [ ] **Step 2: Run test — verify it fails**

```bash
cd server && npm test -- --testPathPattern=server.test
```

Expected: FAIL — `Cannot find module '../src/player-registry.js'`

- [ ] **Step 3: Implement PlayerRegistry**

Create `server/src/player-registry.js`:
```javascript
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
```

- [ ] **Step 4: Run test — verify it passes**

```bash
cd server && npm test -- --testPathPattern=server.test
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
cd server
git add src/player-registry.js tests/server.test.js
git commit -m "feat(server): add PlayerRegistry with tests"
```

---

## Task 3: Room Manager

**Files:**
- Create: `server/src/room-manager.js`
- Modify: `server/tests/server.test.js` (add RoomManager tests)

- [ ] **Step 1: Add failing RoomManager tests**

Append to `server/tests/server.test.js`:
```javascript
const RoomManager = require('../src/room-manager');

describe('RoomManager', () => {
  let registry, rooms;
  const makeWs = () => ({ send: jest.fn(), readyState: 1 });

  beforeEach(() => {
    registry = new PlayerRegistry();
    rooms = new RoomManager(registry);
  });

  test('join adds player to zone', () => {
    registry.add('p1', { ws: makeWs(), x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    const zones = rooms.getAllZones();
    expect(zones.get('main').has('p1')).toBe(true);
  });

  test('leave removes player from zone', () => {
    registry.add('p1', { ws: makeWs(), x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    rooms.leave('p1', 'main');
    const zones = rooms.getAllZones();
    expect(zones.get('main')?.has('p1')).toBeFalsy();
  });

  test('broadcast sends to all in zone except sender', () => {
    const ws1 = makeWs();
    const ws2 = makeWs();
    registry.add('p1', { ws: ws1, x: 0, y: 0, avatar: {}, zone: 'main' });
    registry.add('p2', { ws: ws2, x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    rooms.join('p2', 'main');
    rooms.broadcast('main', { type: 'test' }, 'p1');
    expect(ws2.send).toHaveBeenCalledWith(JSON.stringify({ type: 'test' }));
    expect(ws1.send).not.toHaveBeenCalled();
  });

  test('broadcastToZone sends to everyone in zone', () => {
    const ws1 = makeWs();
    registry.add('p1', { ws: ws1, x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    rooms.broadcastToZone('main', { type: 'tick' });
    expect(ws1.send).toHaveBeenCalledWith(JSON.stringify({ type: 'tick' }));
  });
});
```

- [ ] **Step 2: Run test — verify new tests fail**

```bash
cd server && npm test
```

Expected: FAIL — `Cannot find module '../src/room-manager.js'`

- [ ] **Step 3: Implement RoomManager**

Create `server/src/room-manager.js`:
```javascript
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
```

- [ ] **Step 4: Run all tests — verify all pass**

```bash
cd server && npm test
```

Expected: PASS (all 9 tests).

- [ ] **Step 5: Commit**

```bash
cd server
git add src/room-manager.js tests/server.test.js
git commit -m "feat(server): add RoomManager with zone broadcast and tests"
```

---

## Task 4: NetworkManager Autoload (Godot)

**Files:**
- Create: `scripts/autoloads/NetworkManager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Create NetworkManager.gd**

Create `scripts/autoloads/NetworkManager.gd`:
```gdscript
## NetworkManager.gd
## WebSocket client — connects to ZPS World server, dispatches game events.
## Autoload singleton. Accessed as NetworkManager from anywhere.

extends Node

# ── Signals ──
signal connected()
signal disconnected()
signal player_joined(id: String, x: float, y: float, avatar: Dictionary)
signal player_left(id: String)
signal roster_received(players: Array)
signal positions_updated(data: Array)
signal chat_received(from_id: String, text: String, ts: int)
signal emote_received(from_id: String, emote: String)
signal status_changed(id: String, status: String, message: String)

# ── Config ──
var server_url: String = "ws://localhost:3001"
var _ws: WebSocketPeer = null
var _connected: bool = false
var _send_interval: float = 0.05   # 50ms
var _send_timer: float = 0.0
var _last_sent_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(true)

# ── Connect to server ──
func connect_to_server(player_id: String, x: float, y: float, avatar: Dictionary, zone: String = "main") -> void:
	_ws = WebSocketPeer.new()
	var err = _ws.connect_to_url(server_url)
	if err != OK:
		push_error("[NetworkManager] connect_to_url failed: %d" % err)
		return
	# Store join payload to send on open
	_pending_join = { "type": "player_join", "id": player_id, "x": x, "y": y, "avatar": avatar, "zone": zone }

var _pending_join: Dictionary = {}

func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state = _ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			if not _pending_join.is_empty():
				_send(_pending_join)
				_pending_join = {}
			connected.emit()

		# Receive loop
		while _ws.get_available_packet_count() > 0:
			var raw = _ws.get_packet().get_string_from_utf8()
			_handle_message(raw)

		# Position send throttle
		_send_timer += delta
		if _send_timer >= _send_interval:
			_send_timer = 0.0
			_flush_position()

	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			disconnected.emit()
		_ws = null

# Called by Player.gd every physics frame — buffered, sent at 20Hz
func queue_position(pos: Vector2) -> void:
	_last_sent_pos = pos

func _flush_position() -> void:
	if _last_sent_pos == Vector2.ZERO:
		return
	_send({ "type": "move", "x": _last_sent_pos.x, "y": _last_sent_pos.y })

func send_chat(text: String) -> void:
	_send({ "type": "chat", "text": text })

func send_emote(emote: String) -> void:
	_send({ "type": "emote", "emote": emote })

func send_status(status: String, message: String = "") -> void:
	_send({ "type": "status", "status": status, "message": message })

func _send(payload: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify(payload))

func _handle_message(raw: String) -> void:
	var msg = JSON.parse_string(raw)
	if msg == null:
		return
	match msg.get("type", ""):
		"roster":
			roster_received.emit(msg.get("players", []))
		"player_joined":
			player_joined.emit(msg["id"], float(msg["x"]), float(msg["y"]), msg.get("avatar", {}))
		"player_left":
			player_left.emit(msg["id"])
		"positions":
			positions_updated.emit(msg.get("data", []))
		"chat":
			chat_received.emit(msg["from"], msg["text"], msg.get("ts", 0))
		"emote":
			emote_received.emit(msg["from"], msg["emote"])
		"status_changed":
			status_changed.emit(msg["id"], msg["status"], msg.get("message", ""))

func is_connected_to_server() -> bool:
	return _connected
```

- [ ] **Step 2: Register NetworkManager in project.godot**

In `project.godot`, find the `[autoload]` section and add the new line:
```ini
[autoload]

AIConfig="*res://scripts/autoloads/AIConfig.gd"
GameManager="*res://scripts/autoloads/GameManager.gd"
PlayerData="*res://scripts/autoloads/PlayerData.gd"
ConversationMemory="*res://scripts/autoloads/ConversationMemory.gd"
AIAgent="*res://scripts/autoloads/AIAgent.gd"
NetworkManager="*res://scripts/autoloads/NetworkManager.gd"
```

- [ ] **Step 3: Verify Godot parses without errors**

Open Godot editor. Project should open cleanly — no parse errors in Output panel. NetworkManager should appear in the autoload list under Project → Project Settings → Autoload.

- [ ] **Step 4: Commit**

```bash
git add scripts/autoloads/NetworkManager.gd project.godot
git commit -m "feat(godot): add NetworkManager WebSocket client autoload"
```

---

## Task 5: Player.gd — Send Position to NetworkManager

**Files:**
- Modify: `scripts/player/Player.gd`

- [ ] **Step 1: Locate the physics process method in Player.gd**

Open `scripts/player/Player.gd`. Find the `_physics_process` function (or wherever `move_and_slide()` is called after setting velocity).

- [ ] **Step 2: Add position queuing after movement**

In `_physics_process`, after the `move_and_slide()` call, add:
```gdscript
# Send position to server (buffered — NetworkManager throttles to 20Hz)
if NetworkManager.is_connected_to_server():
    NetworkManager.queue_position(global_position)
```

- [ ] **Step 3: Connect to server on ready**

In Player.gd's `_ready()` function, add at the end:
```gdscript
# Connect to multiplayer server
var avatar_dict = PlayerData.get_avatar_dict()  # ensure this method exists — see note below
NetworkManager.connect_to_server(
    PlayerData.employee_id,
    global_position.x,
    global_position.y,
    avatar_dict,
    "main"
)
```

> **Note:** If `PlayerData.get_avatar_dict()` does not exist, add this method to `PlayerData.gd`:
> ```gdscript
> func get_avatar_dict() -> Dictionary:
>     return {
>         "hair": current_avatar.hair,
>         "skin": current_avatar.skin_tone,
>         "outfit": current_avatar.outfit,
>         "accessory": current_avatar.accessory,
>     }
> ```

- [ ] **Step 4: Manual test — start server + Godot**

```bash
# Terminal 1
cd server && npm start

# Terminal 2 — open Godot project and press Play
```

Expected in server console: `[ZPS World Server] Listening on ws://localhost:3001`, and when game starts: a connection arrives (add `console.log('player connected')` temporarily to server.js to verify).

- [ ] **Step 5: Commit**

```bash
git add scripts/player/Player.gd scripts/autoloads/PlayerData.gd
git commit -m "feat(godot): Player sends position to NetworkManager on movement"
```

---

## Task 6: RemotePlayer.gd — Network-Driven Character

**Files:**
- Create: `scripts/world/RemotePlayer.gd`
- Modify: `scripts/autoloads/GameManager.gd`

- [ ] **Step 1: Add signals to GameManager.gd**

Open `scripts/autoloads/GameManager.gd`. Add to the signals section at the top:
```gdscript
signal remote_player_joined(id: String)
signal remote_player_left(id: String)
```

Add a new dict for remote players below `var employees`:
```gdscript
var remote_players: Dictionary = {}  # id -> RemotePlayer node
```

- [ ] **Step 2: Create RemotePlayer.gd**

Create `scripts/world/RemotePlayer.gd`:
```gdscript
## RemotePlayer.gd
## Represents another player controlled by network input.
## Shares visual style with Employee but uses lerp instead of behavior tree.
## On disconnect: switches to simplified NPC mode (AI answers, idle wander).

class_name RemotePlayer
extends CharacterBody2D

const _AR = preload("res://scripts/world/AvatarRenderer.gd")

# ── Config — set before add_child ──
var player_id: String = ""
var display_name: String = "Unknown"
var avatar_config: Dictionary = {}
var is_npc_mode: bool = false

# ── Visual nodes ──
var _nameplate: Label = null
var _status_dot: ColorRect = null
var _body_rect: ColorRect = null  # fallback if no sprite
var _npc_badge: Label = null      # shown in NPC mode

# ── Network position lerp ──
var _target_pos: Vector2 = Vector2.ZERO
const LERP_SPEED: float = 12.0

func _ready() -> void:
	add_to_group("remote_players")
	collision_layer = 4
	collision_mask = 0  # remote players don't block movement
	_build_visuals()
	_target_pos = global_position

func _build_visuals() -> void:
	# Body (fallback ColorRect, same style as Employee)
	_body_rect = ColorRect.new()
	_body_rect.size = Vector2(12, 16)
	_body_rect.position = Vector2(-6, -16)
	_body_rect.color = Color(0.4, 0.8, 0.4)   # green tint — remote player
	add_child(_body_rect)

	# Nameplate
	_nameplate = Label.new()
	_nameplate.text = display_name
	_nameplate.position = Vector2(-30, -28)
	_nameplate.add_theme_font_size_override("font_size", 9)
	add_child(_nameplate)

	# Status dot
	_status_dot = ColorRect.new()
	_status_dot.size = Vector2(6, 6)
	_status_dot.position = Vector2(6, -20)
	_status_dot.color = Color(0.2, 0.9, 0.2)  # green = online
	add_child(_status_dot)

	# NPC badge (hidden initially)
	_npc_badge = Label.new()
	_npc_badge.text = "[AI]"
	_npc_badge.position = Vector2(-12, -38)
	_npc_badge.add_theme_font_size_override("font_size", 8)
	_npc_badge.modulate = Color(1.0, 0.8, 0.0)  # gold
	_npc_badge.visible = false
	add_child(_npc_badge)

func set_name_and_avatar(name: String, avatar: Dictionary) -> void:
	display_name = name
	avatar_config = avatar
	if _nameplate:
		_nameplate.text = name

# Called by NetworkManager.positions_updated signal
func set_target_position(x: float, y: float) -> void:
	_target_pos = Vector2(x, y)

func _physics_process(delta: float) -> void:
	if is_npc_mode:
		return
	global_position = global_position.lerp(_target_pos, LERP_SPEED * delta)

# Called when this player disconnects — switches to AI NPC mode
func enter_npc_mode() -> void:
	is_npc_mode = true
	_status_dot.color = Color(0.5, 0.5, 0.5)  # gray = offline
	_npc_badge.visible = true
	# Add a simple idle wander or just freeze in place for Sprint 2
	# Full Super NPC AI is wired in Sprint 3 (backend context loading)

func exit_npc_mode() -> void:
	is_npc_mode = false
	_status_dot.color = Color(0.2, 0.9, 0.2)
	_npc_badge.visible = false
```

- [ ] **Step 3: Wire roster and join/leave in a world-level script**

In the scene that spawns the world (check `scripts/world/Campus.gd` or `Office.gd` — whichever runs at game start), connect NetworkManager signals:

```gdscript
# In _ready(), after the world is loaded:
NetworkManager.roster_received.connect(_on_roster_received)
NetworkManager.player_joined.connect(_on_player_joined)
NetworkManager.player_left.connect(_on_player_left)
NetworkManager.positions_updated.connect(_on_positions_updated)

func _on_roster_received(players: Array) -> void:
    for p in players:
        _spawn_remote_player(p["id"], p["x"], p["y"], p.get("avatar", {}))

func _on_player_joined(id: String, x: float, y: float, avatar: Dictionary) -> void:
    _spawn_remote_player(id, x, y, avatar)

func _on_player_left(id: String) -> void:
    var rp = GameManager.remote_players.get(id)
    if rp:
        rp.enter_npc_mode()

func _on_positions_updated(data: Array) -> void:
    for entry in data:
        var rp = GameManager.remote_players.get(entry["id"])
        if rp:
            rp.set_target_position(entry["x"], entry["y"])

func _spawn_remote_player(id: String, x: float, y: float, avatar: Dictionary) -> void:
    if GameManager.remote_players.has(id):
        return
    var RemotePlayerScript = load("res://scripts/world/RemotePlayer.gd")
    var rp = CharacterBody2D.new()
    rp.set_script(RemotePlayerScript)
    rp.player_id = id
    rp.global_position = Vector2(x, y)
    add_child(rp)
    rp.set_name_and_avatar(id, avatar)
    GameManager.remote_players[id] = rp
    GameManager.remote_player_joined.emit(id)
```

- [ ] **Step 4: Manual test with two browser tabs (or two Godot instances)**

```bash
# Terminal 1
cd server && npm start

# Terminal 2 — Godot Play (instance 1)
# Terminal 3 — Godot Play (instance 2, or open exported HTML in browser)
```

Expected: each instance sees the other's avatar appear and move. Closing one tab → that character switches to NPC (gray dot, [AI] badge).

- [ ] **Step 5: Commit**

```bash
git add scripts/world/RemotePlayer.gd scripts/autoloads/GameManager.gd
git commit -m "feat(godot): add RemotePlayer with network lerp and NPC fallback mode"
```

---

## Task 7: HUD — Online Roster Panel

**Files:**
- Modify: `scripts/ui/HUD.gd`

- [ ] **Step 1: Add roster panel variable declarations**

In `HUD.gd`, add to the top variable block:
```gdscript
# ── Online roster ──
var _roster_panel: Control = null
var _roster_list: VBoxContainer = null
var _roster_toggle_btn: Button = null
var _roster_open: bool = false
```

- [ ] **Step 2: Build the roster panel in _ready()**

Find the `_ready()` function in `HUD.gd` (it builds all UI programmatically). Add at the end of `_ready()`:

```gdscript
_build_roster_panel()
```

Then add the method:
```gdscript
func _build_roster_panel() -> void:
    # Toggle button — top-right area
    _roster_toggle_btn = Button.new()
    _roster_toggle_btn.text = "👥 Online"
    _roster_toggle_btn.position = Vector2(1100, 8)
    _roster_toggle_btn.size = Vector2(90, 28)
    _roster_toggle_btn.pressed.connect(_toggle_roster)
    add_child(_roster_toggle_btn)

    # Panel
    _roster_panel = PanelContainer.new()
    _roster_panel.position = Vector2(1000, 40)
    _roster_panel.size = Vector2(270, 300)
    _roster_panel.visible = false
    add_child(_roster_panel)

    var scroll = ScrollContainer.new()
    scroll.size = Vector2(270, 300)
    _roster_panel.add_child(scroll)

    _roster_list = VBoxContainer.new()
    _roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_roster_list)

    # Connect to network events
    NetworkManager.roster_received.connect(_on_roster_update)
    NetworkManager.player_joined.connect(func(id, _x, _y, _av): _refresh_roster())
    NetworkManager.player_left.connect(func(_id): _refresh_roster())
    NetworkManager.status_changed.connect(func(_id, _s, _m): _refresh_roster())

func _toggle_roster() -> void:
    _roster_open = !_roster_open
    _roster_panel.visible = _roster_open

func _on_roster_update(_players: Array) -> void:
    _refresh_roster()

func _refresh_roster() -> void:
    for child in _roster_list.get_children():
        child.queue_free()
    var count = 0
    for id in GameManager.remote_players:
        var rp = GameManager.remote_players[id]
        var row = HBoxContainer.new()
        var dot = ColorRect.new()
        dot.size = Vector2(8, 8)
        dot.color = Color(0.5, 0.5, 0.5) if rp.is_npc_mode else Color(0.2, 0.9, 0.2)
        row.add_child(dot)
        var lbl = Label.new()
        lbl.text = " " + (rp.display_name if rp.display_name != "" else id)
        lbl.add_theme_font_size_override("font_size", 10)
        row.add_child(lbl)
        _roster_list.add_child(row)
        count += 1
    _roster_toggle_btn.text = "👥 Online (%d)" % count
```

- [ ] **Step 3: Manual test**

Start server + Godot. Press `Tab` in-game area (or click the 👥 button). Roster panel should appear showing connected players with green dots. Disconnect one instance → dot turns gray.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/HUD.gd
git commit -m "feat(godot): add online roster panel to HUD"
```

---

## Task 8: ChatLog Panel

**Files:**
- Create: `scripts/ui/ChatLog.gd`
- Modify: `scripts/ui/HUD.gd`

- [ ] **Step 1: Create ChatLog.gd**

Create `scripts/ui/ChatLog.gd`:
```gdscript
## ChatLog.gd
## Persistent scrollable chat log — stores all messages regardless of proximity radius.
## Toggled by pressing C. Visible as overlay in bottom-left area.

extends Control

const MAX_MESSAGES: int = 200

var _scroll: ScrollContainer = null
var _log_container: VBoxContainer = null
var _input_row: HBoxContainer = null
var _input_field: LineEdit = null
var _is_open: bool = false
var _messages: Array[Dictionary] = []   # {from, text, ts}

func _ready() -> void:
	set_process_input(true)
	_build_ui()
	NetworkManager.chat_received.connect(_on_chat_received)

func _build_ui() -> void:
	# Panel background
	var bg = PanelContainer.new()
	bg.position = Vector2(10, 380)
	bg.size = Vector2(340, 240)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.size = Vector2(340, 240)
	bg.add_child(vbox)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size = Vector2(340, 200)
	vbox.add_child(_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_log_container)

	_input_row = HBoxContainer.new()
	vbox.add_child(_input_row)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Press Enter to send..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.text_submitted.connect(_on_send)
	_input_row.add_child(_input_field)

	bg.visible = false
	_is_open = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C and not _input_field.has_focus():
			_toggle()

func _toggle() -> void:
	_is_open = !_is_open
	get_child(0).visible = _is_open
	if _is_open:
		_input_field.grab_focus()

func _on_chat_received(from_id: String, text: String, ts: int) -> void:
	_messages.append({ "from": from_id, "text": text, "ts": ts })
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	var lbl = Label.new()
	lbl.text = "[%s] %s" % [from_id, text]
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_container.add_child(lbl)
	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _on_send(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text)
	# Also show own message locally
	_on_chat_received(PlayerData.employee_id, text, Time.get_unix_time_from_system())
	_input_field.clear()
```

- [ ] **Step 2: Add ChatLog to HUD**

In `HUD.gd`, at the end of `_ready()`:
```gdscript
# Chat log panel
var chat_log_script = load("res://scripts/ui/ChatLog.gd")
var chat_log = Node.new()
chat_log.set_script(chat_log_script)
add_child(chat_log)
```

- [ ] **Step 3: Manual test**

Start server + two Godot instances. Press `C` to open chat log. Type a message in one instance → it should appear in the other. Close and reopen → prior messages still there.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/ChatLog.gd scripts/ui/HUD.gd
git commit -m "feat(godot): add persistent ChatLog panel with C toggle"
```

---

## Self-Review Checklist

### Spec coverage
| Spec requirement | Covered by |
|----------------|-----------|
| Real multiplayer — see each other move | Task 5 (Player sends pos), Task 6 (RemotePlayer lerp) |
| Position interpolation | Task 6 `_physics_process` lerp |
| Online roster panel with live green dots | Task 7 HUD |
| Chat bubbles above characters | Existing from Sprint 0 (InteractionDialog) |
| Persistent chat log panel | Task 8 ChatLog.gd |
| Disconnect → AI NPC mode transition | Task 6 `enter_npc_mode()` |
| WebSocket server (Node.js ws, 50ms tick) | Task 1 server.js setInterval |
| Server tests | Task 2 + 3 Jest tests (9 total) |

### Known deferred items (intentional, not gaps)
- **Super NPC AI context** (rich system prompt per Senior/Lead): Sprint 3 — needs backend NestJS API for context loading
- **Zone-based namespacing per department**: server has `RoomManager` ready, client uses `"main"` until Sprint 3 assigns zones from employee data
- **Status sync** (available/busy/away): `send_status()` exists in NetworkManager, UI hook deferred to Sprint 4 avatar panel

---

## Running Everything

```bash
# 1. Start server
cd server && npm start

# 2. Run server tests
cd server && npm test

# 3. Open Godot project and press Play (F5)
# → Two browser tabs (after WASM export) or two Godot editor instances
```

---

*Next plan: `2026-04-08-sprint3-backend-mvp.md` — NestJS API, SSO auth, HR integration, task view, room booking.*
