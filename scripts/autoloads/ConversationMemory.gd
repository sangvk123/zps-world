## ConversationMemory.gd
## Per-conversation multi-turn message history — Autoload singleton
## Stores up to AIConfig.MAX_HISTORY turns per conversation ID.
## conv_id examples: "emp_001", "workspace", "self"

extends Node

# conv_id -> Array[{role: String, content: String}]
var _history: Dictionary = {}

# ── Write ──
func add_user(conv_id: String, text: String) -> void:
	_push(conv_id, "user", text)

func add_assistant(conv_id: String, text: String) -> void:
	_push(conv_id, "assistant", text)

func _push(conv_id: String, role: String, text: String) -> void:
	if not _history.has(conv_id):
		_history[conv_id] = []
	_history[conv_id].append({"role": role, "content": text})
	# Trim to last MAX_HISTORY * 2 messages (user+assistant pairs)
	var max_msgs: int = AIConfig.MAX_HISTORY * 2
	var h: Array = _history[conv_id]
	if h.size() > max_msgs:
		_history[conv_id] = h.slice(h.size() - max_msgs)

# ── Read ──
func get_messages(conv_id: String) -> Array:
	return _history.get(conv_id, []).duplicate()

func has_history(conv_id: String) -> bool:
	return _history.has(conv_id) and not _history[conv_id].is_empty()

# ── Clear ──
func clear(conv_id: String) -> void:
	_history.erase(conv_id)

func clear_all() -> void:
	_history.clear()
