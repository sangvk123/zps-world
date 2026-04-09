## HttpManager.gd
## HTTP REST client autoload — wraps Godot HTTPRequest nodes, manages JWT auth.
## Signals carry (endpoint: String, data: Variant) on success,
## or (endpoint: String, message: String) on error.
##
## Usage:
##   HttpManager.post("auth/login", {"employee_id": "hieupt", "secret": "zps-dev-secret"})
##   await HttpManager.response_received   # → [endpoint, data_dict]

extends Node

signal response_received(endpoint: String, data: Variant)
signal error(endpoint: String, message: String)

var base_url: String = "http://localhost:3000"
var jwt_token: String = ""

# Tracks which HTTPRequest node maps to which endpoint so we can route responses
var _pending: Dictionary = {}   # HTTPRequest node → endpoint String

func _ready() -> void:
	# Resolve ?api= URL param at runtime (after DOM is ready on web)
	if OS.has_feature("web"):
		var js_snippet := "(function(){ var p=new URLSearchParams(window.location.search).get('api'); return p||''; })()"
		var js_result = JavaScriptBridge.eval(js_snippet)
		if js_result is String and (js_result as String) != "":
			base_url = js_result as String
	print("[HttpManager] Ready — base_url: %s" % base_url)


# ── Public API ──────────────────────────────────────────────────────────────

func get_request(endpoint: String) -> void:
	var node := _make_request_node()
	_pending[node] = endpoint
	var headers := _build_headers()
	var err := node.request("%s/%s" % [base_url, endpoint], headers, HTTPClient.METHOD_GET)
	if err != OK:
		_pending.erase(node)
		node.queue_free()
		error.emit(endpoint, "HTTPRequest.request() failed: %d" % err)


func post(endpoint: String, body: Dictionary) -> void:
	var node := _make_request_node()
	_pending[node] = endpoint
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	var json_body := JSON.stringify(body)
	var err := node.request("%s/%s" % [base_url, endpoint], headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_pending.erase(node)
		node.queue_free()
		error.emit(endpoint, "HTTPRequest.request() failed: %d" % err)


func patch(endpoint: String, body: Dictionary) -> void:
	var node := _make_request_node()
	_pending[node] = endpoint
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	var json_body := JSON.stringify(body)
	var err := node.request("%s/%s" % [base_url, endpoint], headers, HTTPClient.METHOD_PATCH, json_body)
	if err != OK:
		_pending.erase(node)
		node.queue_free()
		error.emit(endpoint, "HTTPRequest.request() failed: %d" % err)


# ── Internal helpers ─────────────────────────────────────────────────────────

func _make_request_node() -> HTTPRequest:
	var node := HTTPRequest.new()
	node.use_threads = not OS.has_feature("web")  # threads OK on desktop, disabled on web (SharedArrayBuffer)
	add_child(node)
	node.request_completed.connect(_on_request_completed.bind(node))
	return node


func _build_headers() -> Array:
	var headers: Array = []
	headers.append("bypass-tunnel-reminder: 1")  # bypass localtunnel interstitial
	if jwt_token != "":
		headers.append("Authorization: Bearer %s" % jwt_token)
	return headers


func _on_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
		node: HTTPRequest
) -> void:
	var endpoint: String = _pending.get(node, "unknown")
	_pending.erase(node)
	node.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		error.emit(endpoint, "Network error — result code %d" % result)
		return

	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)

	if response_code >= 400:
		var msg := "HTTP %d" % response_code
		if data is Dictionary and data.has("message"):
			msg = str(data["message"])
		error.emit(endpoint, msg)
		return

	response_received.emit(endpoint, data)
