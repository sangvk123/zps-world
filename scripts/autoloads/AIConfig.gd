## AIConfig.gd
## Centralized AI configuration — Autoload singleton
## API key is NEVER hardcoded here. Load order:
##   1. OS env var ANTHROPIC_API_KEY
##   2. user://ai_config.cfg (created by setup wizard)
##   3. Mock mode (no API call)

extends Node

const CONFIG_PATH = "user://ai_config.cfg"

# ── Model settings ──
const MODEL         = "claude-haiku-4-5-20251001"
const MAX_TOKENS    = 512
const API_URL       = "https://api.anthropic.com/v1/messages"
const MAX_HISTORY   = 10  # max turns kept per conversation

# ── Runtime state ──
var api_key: String  = ""
var use_mock: bool   = true

func _ready() -> void:
	_load()

func _load() -> void:
	# Priority 1: environment variable
	var env_key := OS.get_environment("ANTHROPIC_API_KEY")
	if env_key != "":
		api_key  = env_key
		use_mock = false
		print("[AIConfig] API key from env ANTHROPIC_API_KEY")
		return

	# Priority 2: config file
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		var stored: String = cfg.get_value("ai", "api_key", "")
		if stored != "":
			api_key  = stored
			use_mock = false
			print("[AIConfig] API key from %s" % CONFIG_PATH)
			return

	# Priority 3: mock mode
	use_mock = true
	print("[AIConfig] No API key found — mock mode active")
	print("[AIConfig]   Set env ANTHROPIC_API_KEY  OR  call AIConfig.save_api_key(key)")

## Call this from an in-game settings panel or onboarding flow.
## Saves the key to user://ai_config.cfg (not source-tracked).
func save_api_key(key: String) -> void:
	api_key  = key.strip_edges()
	use_mock = api_key.is_empty()
	var cfg := ConfigFile.new()
	cfg.set_value("ai", "api_key", api_key)
	cfg.save(CONFIG_PATH)
	print("[AIConfig] API key saved to %s (mock=%s)" % [CONFIG_PATH, use_mock])

func is_configured() -> bool:
	return not use_mock
