class_name GameManager
extends Node

signal hour_changed(hour_index: int)
signal night_won
signal night_lost

@export_group("Gece")
@export var night: int = 1
@export var seconds_per_hour: float = 60.0
@export var six_am_clock_display_time: float = 1.0
@export var six_am_fade_duration: float = 1.2

@export_group("HUD")
@export var hud_font: Font
@export var hud_font_size: int = 32
@export var hud_margin: float = 24.0
@export var end_font_size: int = 96
@export var end_screen_time: float = 4.0

var hud_root: Control
var night_label: Label
var clock_label: Label
var end_screen: ColorRect
var end_label: Label

var _elapsed: float = 0.0
var _hour_index: int = 0
var _finished: bool = false
var _six_am_triggered: bool = false
var _hud_layer: CanvasLayer
var _top_right_panel: Control
var _cam_ui: CameraSystemUI
var _aux_screen_open: bool = false
var _saved_bus_volumes_db: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_guaranteed_hud()
	_connect_camera_system_ui()
	_refresh_hud()
	_layout_top_right()
	_sync_clock_visibility()


func _input(event: InputEvent) -> void:
	if _finished or _six_am_triggered:
		return
	var back_pressed := event.is_action_pressed("ui_cancel")
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		back_pressed = back_pressed or key_event.keycode in [KEY_ESCAPE, KEY_BACK]
	if not back_pressed:
		return
	_return_to_main_menu()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if ResourceLoader.exists("res://main_menu.tscn"):
		get_tree().change_scene_to_file("res://main_menu.tscn")
	else:
		push_error("Main menu scene is missing: res://main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_hud()
		_layout_top_right()


func get_hour_index() -> int:
	return _hour_index


func get_display_hour() -> int:
	return 12 if _hour_index == 0 else _hour_index


func is_night_active() -> bool:
	return not _finished and not _six_am_triggered


func set_night(new_night: int) -> void:
	night = maxi(new_night, 1)
	_refresh_hud()
	_layout_top_right()


func set_aux_screen_open(value: bool) -> void:
	_aux_screen_open = value
	_sync_clock_visibility()


func trigger_game_over() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _finished or _six_am_triggered:
		return
	_finished = true
	_freeze_game_and_mute_audio()
	night_lost.emit()
	await _show_end_screen("GAME_OVER", "GAME OVER")
	_restore_audio_and_unpause()
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	_layout_top_right()
	_sync_clock_visibility()

	if _finished or _six_am_triggered:
		return

	var hour_len: float = maxf(seconds_per_hour, 0.01)
	_elapsed += delta

	var idx: int = mini(int(_elapsed / hour_len), 6)
	if idx != _hour_index:
		_hour_index = idx
		_refresh_hud()
		hour_changed.emit(_hour_index)

	if _hour_index >= 6:
		_start_six_am_sequence()


func _start_six_am_sequence() -> void:
	if _six_am_triggered or _finished:
		return
	_six_am_triggered = true
	_refresh_hud()
	_sync_clock_visibility()
	if _finished:
		return
	await _win()


func _win() -> void:
	if _finished:
		return
	if not Difficulties.custom_night_active:
		GameSettings.unlock_custom_night()
	_finished = true
	if not _cam_ui or not is_instance_valid(_cam_ui):
		_connect_camera_system_ui()
	if _cam_ui and is_instance_valid(_cam_ui):
		_cam_ui.hide_mobile_exit_button()
	_freeze_game_and_mute_audio(true)
	night_won.emit()
	await _show_end_screen("WIN_TEXT", "6 AM", six_am_fade_duration)
	_restore_audio_and_unpause()
	if ResourceLoader.exists("res://main_menu.tscn"):
		get_tree().change_scene_to_file("res://main_menu.tscn")


func _freeze_game_and_mute_audio(stop_jumpscare_audio: bool = false) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_saved_bus_volumes_db.clear()
	for bus_idx in range(AudioServer.bus_count):
		var bus_name := AudioServer.get_bus_name(bus_idx)
		_saved_bus_volumes_db[bus_name] = AudioServer.get_bus_volume_db(bus_idx)
		if stop_jumpscare_audio or (bus_name != AudioSettings.JUMPSCARE_BUS_NAME and bus_name != "Master"):
			AudioServer.set_bus_volume_db(bus_idx, AudioSettings.MUTED_DB)
	_stop_all_audio_players(get_tree().root, stop_jumpscare_audio)


func _stop_all_audio_players(node: Node, stop_jumpscare_audio: bool = false) -> void:
	if node is AudioStreamPlayer:
		var player := node as AudioStreamPlayer
		if stop_jumpscare_audio or player.bus != AudioSettings.JUMPSCARE_BUS_NAME:
			player.stop()
	elif node is AudioStreamPlayer2D:
		var player := node as AudioStreamPlayer2D
		if stop_jumpscare_audio or player.bus != AudioSettings.JUMPSCARE_BUS_NAME:
			player.stop()
	elif node is AudioStreamPlayer3D:
		var player := node as AudioStreamPlayer3D
		if stop_jumpscare_audio or player.bus != AudioSettings.JUMPSCARE_BUS_NAME:
			player.stop()
	for child in node.get_children():
		_stop_all_audio_players(child, stop_jumpscare_audio)


func _restore_audio_and_unpause() -> void:
	for bus_name in _saved_bus_volumes_db:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			AudioServer.set_bus_volume_db(bus_idx, _saved_bus_volumes_db[bus_name])
	_saved_bus_volumes_db.clear()
	get_tree().paused = false


func _connect_camera_system_ui() -> void:
	if not _cam_ui or not is_instance_valid(_cam_ui):
		_cam_ui = get_tree().root.find_child("CameraSystemUI", true, false) as CameraSystemUI
	if _cam_ui and is_instance_valid(_cam_ui):
		if not _cam_ui.opened.is_connected(_on_camera_opened):
			_cam_ui.opened.connect(_on_camera_opened)
		if not _cam_ui.closed.is_connected(_on_camera_closed):
			_cam_ui.closed.connect(_on_camera_closed)


func _on_camera_opened() -> void:
	_sync_clock_visibility()


func _on_camera_closed() -> void:
	_sync_clock_visibility()
	_layout_top_right()


func _is_camera_open() -> bool:
	if not _cam_ui or not is_instance_valid(_cam_ui):
		_connect_camera_system_ui()
	if _cam_ui and is_instance_valid(_cam_ui):
		return _cam_ui.is_open()
	return false


func _sync_clock_visibility() -> void:
	_set_clock_visible(not _is_camera_open() and not _aux_screen_open)


func _set_clock_visible(show_clock: bool) -> void:
	if _top_right_panel and is_instance_valid(_top_right_panel):
		_top_right_panel.visible = show_clock
	if night_label and is_instance_valid(night_label):
		night_label.visible = show_clock
	if clock_label and is_instance_valid(clock_label):
		clock_label.visible = show_clock


func _setup_guaranteed_hud() -> void:
	var r := get_tree().root
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else r
	var scene_hud := scene_root.find_child("Hud", true, false) as CanvasLayer
	if scene_hud and scene_hud.get_node_or_null("Control") is Control:
		_hud_layer = scene_hud
		hud_root = scene_hud.get_node("Control") as Control
	else:
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "GuaranteedGameHudLayer"
		_hud_layer.layer = 100
		scene_root.add_child(_hud_layer)
		hud_root = Control.new()
		hud_root.name = "GuaranteedHudRoot"
		hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(hud_root)

	_top_right_panel = hud_root.get_node_or_null("TopRightClockPanel") as Control
	if not _top_right_panel:
		_top_right_panel = Control.new()
		_top_right_panel.name = "TopRightClockPanel"
		_top_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_root.add_child(_top_right_panel)

	night_label = hud_root.get_node_or_null("NightLabel") as Label
	if not night_label:
		night_label = Label.new()
		night_label.name = "NightLabel"
		hud_root.add_child(night_label)

	clock_label = hud_root.get_node_or_null("ClockLabel") as Label
	if not clock_label:
		clock_label = Label.new()
		clock_label.name = "ClockLabel"
		hud_root.add_child(clock_label)
	if night_label.get_parent() != _top_right_panel:
		night_label.reparent(_top_right_panel)
	if clock_label.get_parent() != _top_right_panel:
		clock_label.reparent(_top_right_panel)

	for lbl: Label in [night_label, clock_label]:
		lbl.visible = true
		lbl.modulate = Color.WHITE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", hud_font_size)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		if hud_font:
			lbl.add_theme_font_override("font", hud_font)

	end_screen = hud_root.get_node_or_null("EndScreen") as ColorRect
	if not end_screen:
		end_screen = ColorRect.new()
		end_screen.name = "EndScreen"
		hud_root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_screen.color = Color.BLACK
	end_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	end_screen.visible = false
	end_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	end_label = end_screen.get_node_or_null("EndLabel") as Label
	if not end_label:
		end_label = Label.new()
		end_label.name = "EndLabel"
		end_screen.add_child(end_label)
	end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_label.add_theme_font_size_override("font_size", end_font_size)
	end_label.add_theme_color_override("font_color", Color.WHITE)
	if hud_font:
		end_label.add_theme_font_override("font", hud_font)
	hud_root.move_child(end_screen, hud_root.get_child_count() - 1)


func _layout_top_right() -> void:
	if not _top_right_panel or not is_instance_valid(_top_right_panel):
		return
	var line_h: float = maxf(float(hud_font_size) * 1.25, 36.0)
	var gap: float = 4.0
	var panel_w: float = 320.0
	var panel_h: float = (line_h * 2.0) + gap

	_top_right_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_top_right_panel.offset_left = -panel_w - hud_margin
	_top_right_panel.offset_right = -hud_margin
	_top_right_panel.offset_top = hud_margin
	_top_right_panel.offset_bottom = hud_margin + panel_h
	_top_right_panel.size = Vector2(panel_w, panel_h)

	if night_label and is_instance_valid(night_label):
		night_label.position = Vector2(0.0, 0.0)
		night_label.size = Vector2(panel_w, line_h)

	if clock_label and is_instance_valid(clock_label):
		clock_label.position = Vector2(0.0, line_h + gap)
		clock_label.size = Vector2(panel_w, line_h)


func _refresh_hud() -> void:
	if night_label:
		var max_custom_night := (
			Difficulties.custom_night_active
			and Difficulties.ouz_enabled
			and Difficulties.mayinmelih_enabled
			and Difficulties.get_level(Difficulties.OUZ) == 20
			and Difficulties.get_level(Difficulties.MAYINMELIH) == 20
		)
		var night_label_key := "NIGHT_LABEL_MAX" if max_custom_night else ("MENU_CUSTOM_NIGHT" if Difficulties.custom_night_active else "NIGHT_LABEL")
		night_label.text = tr(night_label_key)
	if clock_label:
		clock_label.text = _fmt("CLOCK_LABEL", get_display_hour(), "%d AM")


func _fmt(key: String, value: int, fallback: String) -> String:
	var f := tr(key)
	var template := fallback if (f == key or not f.contains("%d")) else f
	return template.replace("%d", str(value))


func _show_end_screen(key: String, fallback: String, fade_duration: float = 1.0) -> void:
	var t := tr(key)
	end_label.text = fallback if t == key else t
	end_screen.modulate.a = 0.0
	end_screen.visible = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(end_screen, "modulate:a", 1.0, maxf(fade_duration, 0.01))
	await tw.finished
	await get_tree().create_timer(end_screen_time, true, false, true).timeout


func get_current_hour() -> int:
	return get_hour_index()


func trigger_game_over_frozen() -> void:
	await trigger_game_over()
