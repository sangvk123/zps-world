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
