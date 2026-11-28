extends Node

const SCREEN_GREEN := Color8(99, 141, 62)
const TERMINAL_GREEN := Color8(102, 225, 90)
const EXIT_EDGE_RATIO := 0.94

@export_range(0.2, 2.0, 0.05) var zoom_duration: float = 0.65
@export var laptop_enabled: bool = false

var _hitbox: GlowHitbox
var _player_camera: PlayerCamera
var _zoom_camera: Camera3D
var _screen: CSGPrimitive3D
var _screen_material: StandardMaterial3D
var _camera_ui: CameraSystemUI
var _game_manager: GameManager
var _canvas: CanvasLayer
var _panel: PanelContainer
var _output: Label
var _input_line: LineEdit
var _cursor_label: Label
var _is_open := false
var _transitioning := false
var _mouse_mode_before_open := Input.MOUSE_MODE_VISIBLE
var _output_lines: PackedStringArray = []
var _saved_hitbox_fade_in: float = 0.45


func _ready() -> void:
	var world := get_tree().root
	_hitbox = world.find_child("LaptopHitbox", true, false) as GlowHitbox
	if not laptop_enabled:
		if _hitbox:
			_hitbox.set_process(false)
			_hitbox.set_process_input(false)
			_hitbox.monitoring = false
			_hitbox.monitorable = false
			_hitbox.collision_layer = 0
			_hitbox.collision_mask = 0
			_hitbox.input_ray_pickable = false
		set_process(false)
		set_process_input(false)
		return
	_player_camera = world.find_child("Camera3D", true, false) as PlayerCamera
	_zoom_camera = world.find_child("LaptopZoomView", true, false) as Camera3D
	_screen = world.find_child("Lekran", true, false) as CSGPrimitive3D
	_camera_ui = world.find_child("CameraSystemUI", true, false) as CameraSystemUI
	_game_manager = world.find_child("GameManager", true, false) as GameManager
	if not _hitbox or not _player_camera or not _zoom_camera or not _screen:
		push_error("LaptopTerminal: LaptopHitbox, Camera3D, LaptopZoomView veya Lekran bulunamadı.")
		set_process(false)
		set_process_input(false)
		return
	if _screen.material is StandardMaterial3D:
		# LaptopHitbox aynı materyali hover sırasında aydınlatır; kopyası kullanılırsa efekt ekrana yansımaz.
		_screen_material = _screen.material as StandardMaterial3D
	else:
		_screen_material = StandardMaterial3D.new()
		_screen.material = _screen_material
	if not _hitbox.clicked.is_connected(_on_laptop_clicked):
		_hitbox.clicked.connect(_on_laptop_clicked)
	_saved_hitbox_fade_in = _hitbox.fade_in_time
	_create_terminal_ui()


func _process(_delta: float) -> void:
	if not _is_open or _transitioning:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE and get_viewport().get_mouse_position().y >= viewport_size.y * EXIT_EDGE_RATIO:
		_close_terminal()


func _input(event: InputEvent) -> void:
	if not _is_open or _transitioning:
		return
	var touch := event as InputEventScreenTouch
	if touch and touch.pressed:
		var viewport_size := get_viewport().get_visible_rect().size
		if touch.position.y >= viewport_size.y * EXIT_EDGE_RATIO:
			_close_terminal()
			get_viewport().set_input_as_handled()


func _create_terminal_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "LaptopTerminalOverlay"
	_canvas.layer = 30
	add_child(_canvas)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "TerminalScreen"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.13
	_panel.anchor_top = 0.18
	_panel.anchor_right = 0.87
	_panel.anchor_bottom = 0.82
	_panel.offset_left = 0.0
	_panel.offset_top = 0.0
	_panel.offset_right = 0.0
	_panel.offset_bottom = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.BLACK
	panel_style.border_color = Color(0.18, 0.36, 0.15, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(24.0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	_panel.add_child(layout)
	var title := Label.new()
	title.text = tr("TERMINAL_TITLE")
	title.add_theme_color_override("font_color", TERMINAL_GREEN)
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)

	_output = Label.new()
	_output.custom_minimum_size = Vector2(0.0, 190.0)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_output.add_theme_color_override("font_color", TERMINAL_GREEN)
	_output.add_theme_font_size_override("font_size", 18)
	layout.add_child(_output)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	layout.add_child(input_row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_color_override("font_color", TERMINAL_GREEN)
	prompt.add_theme_font_size_override("font_size", 20)
	input_row.add_child(prompt)
	_cursor_label = Label.new()
	_cursor_label.text = "_"
	_cursor_label.add_theme_color_override("font_color", TERMINAL_GREEN)
	_cursor_label.add_theme_font_size_override("font_size", 20)
	input_row.add_child(_cursor_label)
	_input_line = LineEdit.new()
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.caret_blink = false
	_input_line.add_theme_color_override("font_color", TERMINAL_GREEN)
	_input_line.add_theme_font_size_override("font_size", 20)
	_input_line.add_theme_stylebox_override("normal", _make_terminal_input_style())
	_input_line.add_theme_stylebox_override("focus", _make_terminal_input_style())
	_input_line.text_submitted.connect(_on_command_submitted)
	_input_line.text_changed.connect(_on_terminal_input_changed)
	input_row.add_child(_input_line)
	var cursor_blink := create_tween().set_loops()
	cursor_blink.tween_property(_cursor_label, "modulate:a", 0.12, 0.45)
	cursor_blink.tween_property(_cursor_label, "modulate:a", 1.0, 0.45)

	var footer := Label.new()
	footer.text = tr("TERMINAL_RETURN_HINT")
	footer.add_theme_color_override("font_color", Color(TERMINAL_GREEN, 0.75))
	footer.add_theme_font_size_override("font_size", 12)
	layout.add_child(footer)
	_reset_terminal_text()
	_panel.visible = false


func _make_terminal_input_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color(0.18, 0.36, 0.15, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(8.0)
	return style


func _on_laptop_clicked() -> void:
	if _is_open or _transitioning or (_camera_ui and _camera_ui.is_open()):
		return
	_is_open = true
	_transitioning = true
	_mouse_mode_before_open = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_hitbox.fade_in_time = 0.01
	_hitbox.set_in_use(true)
	if _camera_ui:
		_camera_ui.lock_cams("laptop")
	if _game_manager:
		_game_manager.set_aux_screen_open(true)
	_screen_material.albedo_color = SCREEN_GREEN
	_screen_material.emission_enabled = true
	_screen_material.emission = SCREEN_GREEN
	_screen_material.emission_energy_multiplier = 0.7
	var screen_tween := create_tween()
	screen_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	screen_tween.tween_property(_screen_material, "albedo_color", Color.BLACK, zoom_duration)
	screen_tween.parallel().tween_property(_screen_material, "emission", Color.BLACK, zoom_duration)
	_player_camera.zoom_to(_zoom_camera.global_transform, _zoom_camera.fov, zoom_duration)
	await _player_camera.zoom_finished
	if not _is_open:
		return
	_panel.visible = true
	_input_line.grab_focus()
	_transitioning = false


func _close_terminal() -> void:
	if not _is_open or _transitioning:
		return
	_transitioning = true
	_is_open = false
	_panel.visible = false
	_input_line.release_focus()
	var screen_tween := create_tween()
	screen_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	screen_tween.tween_property(_screen_material, "albedo_color", SCREEN_GREEN, zoom_duration)
	screen_tween.parallel().tween_property(_screen_material, "emission", SCREEN_GREEN, zoom_duration)
	_player_camera.return_to_base(zoom_duration)
	await _player_camera.return_finished
	_hitbox.set_in_use(false)
	_hitbox.fade_in_time = _saved_hitbox_fade_in
	if _camera_ui:
		_camera_ui.unlock_cams("laptop")
	if _game_manager:
		_game_manager.set_aux_screen_open(false)
	Input.set_mouse_mode(_mouse_mode_before_open)
	_transitioning = false


func _reset_terminal_text() -> void:
	_output_lines = PackedStringArray([
		tr("TERMINAL_REMOTE_ACCESS"),
		"",
		"> CAMERAS",
		"  " + tr("TERMINAL_CAMERAS_HINT"),
		"> MUSICBOX",
		"  " + tr("TERMINAL_MUSICBOX_HINT"),
		"> STATUS",
		"  " + tr("TERMINAL_STATUS_HINT"),
		"",
		tr("TERMINAL_HELP_HINT")
	])
	_update_output()


func _on_command_submitted(command: String) -> void:
	var normalized := command.strip_edges().to_upper()
	_input_line.clear()
	if normalized.is_empty():
		return
	_output_lines.append("> " + normalized)
	match normalized:
		"HELP":
			_output_lines.append(tr("TERMINAL_COMMANDS"))
		"CAMERAS":
			_output_lines.append(tr("TERMINAL_CAMERAS_RESPONSE"))
		"MUSICBOX":
			_output_lines.append(tr("TERMINAL_MUSICBOX_RESPONSE"))
		"STATUS":
			_output_lines.append(tr("TERMINAL_STATUS_RESPONSE"))
		"CLEAR":
			_output_lines.clear()
		"EXIT":
			_update_output()
			_close_terminal()
			return
		_:
			_output_lines.append(tr("TERMINAL_UNKNOWN_COMMAND"))
	_update_output()
	_cursor_label.visible = _input_line.text.is_empty()


func _on_terminal_input_changed(text: String) -> void:
	_cursor_label.visible = text.is_empty()


func _update_output() -> void:
	_output.text = "\n".join(_output_lines)
