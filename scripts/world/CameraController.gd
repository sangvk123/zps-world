## CameraController.gd
## Attached as a CHILD of the Player node — Godot handles follow automatically.
## This script only handles:
##   Pan   : hold Right Mouse Button and drag (shifts camera offset)
##   Zoom  : scroll wheel (zoom-to-cursor feel)
##   Reset : press F to snap offset back to center

extends Camera2D

@export var pan_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var zoom_min: float = 0.8
@export var zoom_max: float = 4.0
@export var zoom_speed: float = 0.25
@export var zoom_lerp_speed: float = 10.0

var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO
var _target_zoom: float = 2.5

func _ready() -> void:
	# Sync with zoom set from code (e.g. Office._setup_camera)
	_target_zoom = zoom.x

func _input(event: InputEvent) -> void:
	# ── Right-mouse pan ──
	if event is InputEventMouseButton:
		if event.button_index == pan_button:
			if event.pressed:
				_is_panning = true
				_pan_start_mouse = event.position
				_pan_start_offset = position   # local offset from player
			else:
				_is_panning = false

		# ── Scroll zoom ──
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clamp(_target_zoom + zoom_speed, zoom_min, zoom_max)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clamp(_target_zoom - zoom_speed, zoom_min, zoom_max)

	if event is InputEventMouseMotion and _is_panning:
		var delta: Vector2 = (event.position - _pan_start_mouse) / zoom.x
		position = _pan_start_offset - delta

	# ── F key: reset pan offset ──
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		position = Vector2.ZERO
		_is_panning = false

func _process(delta: float) -> void:
	# Smooth zoom lerp
	zoom = zoom.lerp(Vector2(_target_zoom, _target_zoom), zoom_lerp_speed * delta)
