class_name CameraSystemUI
extends CanvasLayer

enum State { IDLE, ZOOMING_IN, OPENING, ACTIVE, CLOSING, ZOOMING_OUT }

const CURSOR_ARROW = preload("res://png/cursor_arrow.png")
const CURSOR_HAND = preload("res://png/cursor_hand.png")
const BTN_NORMAL = preload("res://png/btn_normal.png")
const BTN_HOVER = preload("res://png/btn_hover.png")
const BTN_PRESSED = preload("res://png/btn_pressed.png")
const MUSIC_BOX_CAUTION_TEXTURE: Texture2D = preload("res://png/caution.png")
const CAMERA_MAP_TEX: Texture2D = preload("res://png/camera_map.png")
const EXIT_TEXTURE: Texture2D = preload("res://png/exit.png")
## Mobilde masadan çıkış düğmesinin genişliği (piksel). Buradan değiştirebilirsin.
const MOBILE_HIDE_EXIT_BUTTON_WIDTH: float = 260.0
const MUSIC_ICON_TEX: Texture2D = preload("res://png/music.png")
const AUDIO_ICON_TEX: Texture2D = preload("res://png/audio.png")
const MUSIC_CHANGE_ICON_TEX: Texture2D = preload("res://png/musicchange.png")
const CHANGE_REQUEST_SOUND: AudioStream = preload("res://audio/MusicChangeRequest.wav")
const WINDING_SOUND: AudioStream = preload("res://audio/winding.wav")
const AUDIO_WAVE_EFFECT_SCRIPT = preload("res://audio_wave_effect.gd")
const CAM_COUNT: int = 13
const STATIC_DIR_CANDIDATES: PackedStringArray = [
	"res://textures",
	"res://static",
	"res://png",
	"res://"
]
const MAP_LINE_1_ANCHOR: Vector2 = Vector2(0.53, 0.71)
const MAP_LINE_2_ANCHOR: Vector2 = Vector2(0.53, 0.34)
const MAP_LINE_3_ANCHOR: Vector2 = Vector2(0.35, 0.66)
const MAP_LINE_4_ANCHOR: Vector2 = Vector2(0.35, 0.39)
const MAP_LINE_5_ANCHOR: Vector2 = Vector2(0.52, 0.55)
const MAP_LINE_6_ANCHOR: Vector2 = Vector2(0.59, 0.60)
signal lure_requested(cam_index: int)
signal music_change_requested
signal opened
signal closed
signal lost_signal_finished
signal mobile_hide_exit_requested

@export_group("Görsel")
@export var win95_font: FontFile
@export var auto_layout: bool = true
@export var camera_map_texture: Texture2D = CAMERA_MAP_TEX
@export var map_size_px: Vector2 = Vector2(300.0, 300.0):
	set(value):
		map_size_px = Vector2(maxf(value.x, 10.0), maxf(value.y, 10.0))
		if is_node_ready() and auto_layout:
			_force_layout()
@export_range(0.1, 5.0, 0.01) var map_scale: float = 2.0:
	set(value):
		map_scale = maxf(value, 0.05)
		if is_node_ready() and auto_layout:
			_force_layout()
@export_range(0.1, 3.0, 0.05) var hud_element_scale: float = 1.1:
	set(value):
		hud_element_scale = maxf(value, 0.05)
		if is_node_ready() and auto_layout:
			_force_layout()
@export_range(0.1, 3.0, 0.05) var map_line_scale: float = 1.1:
	set(value):
		map_line_scale = maxf(value, 0.05)
		if is_node_ready() and auto_layout:
			_force_layout()
@export_range(0.0, 1.0, 0.001) var map_anchor_x: float = 0.80:
	set(value):
		map_anchor_x = clampf(value, 0.0, 1.0)
		if not _syncing_map_anchor:
			_syncing_map_anchor = true
			map_anchor = Vector2(map_anchor_x, map_anchor.y)
			_syncing_map_anchor = false
		if is_node_ready() and auto_layout:
			_force_layout()
@export_range(0.0, 1.0, 0.001) var map_anchor_y: float = 0.50:
	set(value):
		map_anchor_y = clampf(value, 0.0, 1.0)
		if not _syncing_map_anchor:
			_syncing_map_anchor = true
			map_anchor = Vector2(map_anchor.x, map_anchor_y)
			_syncing_map_anchor = false
		if is_node_ready() and auto_layout:
			_force_layout()
@export var map_anchor: Vector2 = Vector2(0.80, 0.50):
	set(value):
		map_anchor = Vector2(clampf(value.x, 0.0, 1.0), clampf(value.y, 0.0, 1.0))
		if not _syncing_map_anchor:
			_syncing_map_anchor = true
			map_anchor_x = map_anchor.x
			map_anchor_y = map_anchor.y
			_syncing_map_anchor = false
		if is_node_ready() and auto_layout:
			_force_layout()
@export var map_offset_px: Vector2 = Vector2.ZERO:
	set(value):
		map_offset_px = value
		if is_node_ready() and auto_layout:
			_force_layout()
@export var map_margin_px: float = 24.0
@export var map_bottom_offset_px: float = 96.0
@export var cam_button_size: Vector2 = Vector2(40.0, 24.0)
@export var you_map_anchor: Vector2 = Vector2(0.45, 0.62)
@export var you_square_map_anchor: Vector2 = Vector2(0.45, 0.58)
@export var you_translation_key: String = "YOU"
@export var pending_translation_key: String = "PENDING"
@export var static_frames: Array[Texture2D]
@export_range(0.0, 1.0) var static_alpha: float = 0.06
@export_range(0.005, 0.5) var scanline_step: float = 0.025
@export var scanline_height: float = 240.0
@export_range(0.005, 0.8) var thin_scanline_step: float = 0.05
@export var thin_scanline_height: float = 40.0
@export_range(0.005, 0.8) var third_scanline_step: float = 0.035
@export var third_scanline_height: float = 80.0
@export var hand_hotspot: Vector2 = Vector2.ZERO
@export var button_margin: int = 4
@export var line_2_num_offset_y: float = 8.0

@export_group("Harita Çizgileri")
@export var seal_lines_enabled: bool = false:
	set(value):
		seal_lines_enabled = value
		if is_node_ready():
			for line: ColorRect in _map_lines:
				if line and is_instance_valid(line):
					line.visible = value
			for num_lbl: Label in _map_line_labels:
				if num_lbl and is_instance_valid(num_lbl):
					num_lbl.visible = value
@export var map_line_color: Color = Color(0.10, 1.0, 0.25, 0.95)
@export var map_line_number_color: Color = Color(1.0, 0.35, 0.75, 1.0)
@export var map_line_thickness: float = 2.0
@export var map_line_length: float = 28.0
@export var line_1_name: String = "MapLine1"
@export var line_1_length: float = 38.0
@export var line_2_name: String = "MapLine2"
@export var line_2_length: float = 38.0
@export var line_3_name: String = "MapLine3"
@export var line_3_length: float = 38.0
@export var line_4_name: String = "MapLine4"
@export var line_4_length: float = 38.0
@export var line_5_name: String = "MapLine5"
@export var line_5_length: float = 20.0
@export var line_6_name: String = "MapLine6"
@export var line_6_length: float = 20.0

@export_group("Kamera Çeviri Anahtarları")
@export var cam1_translation_key: String = "CAM_1_NAME"
@export var cam2_translation_key: String = "CAM_2_NAME"
@export var cam3_translation_key: String = "CAM_3_NAME"
@export var cam4_translation_key: String = "CAM_4_NAME"
@export var cam5_translation_key: String = "CAM_5_NAME"
@export var cam6_translation_key: String = "CAM_6A_NAME"
@export var cam7_translation_key: String = "CAM_6B_NAME"
@export var cam8_translation_key: String = "CAM_6C_NAME"
@export var cam9_translation_key: String = "CAM_7_NAME"
@export var cam10_translation_key: String = "CAM_8_NAME"
@export var cam11_translation_key: String = "CAM_9_NAME"
@export var cam12_translation_key: String = "CAM_10_NAME"
@export var cam13_translation_key: String = "CAM_11_NAME"

@export_group("Kamera Konumları")
@export var cam1_map_anchor: Vector2 = Vector2(0.28, 0.30)
@export var cam2_map_anchor: Vector2 = Vector2(0.49, 0.22)
@export var cam3_map_anchor: Vector2 = Vector2(0.51, 0.32)
@export var cam4_map_anchor: Vector2 = Vector2(0.43, 0.41)
@export var cam5_map_anchor: Vector2 = Vector2(0.57, 0.44)
@export var cam6_map_anchor: Vector2 = Vector2(0.70, 0.42)
@export var cam7_map_anchor: Vector2 = Vector2(0.13, 0.51)
@export var cam8_map_anchor: Vector2 = Vector2(0.33, 0.57)
@export var cam9_map_anchor: Vector2 = Vector2(0.41, 0.68)
@export var cam10_map_anchor: Vector2 = Vector2(0.35, 0.78)
@export var cam11_map_anchor: Vector2 = Vector2(0.48, 0.78)
@export var cam12_map_anchor: Vector2 = Vector2(0.68, 0.74)
@export var cam13_map_anchor: Vector2 = Vector2(0.82, 0.74)

@export_group("Güvenlik Kamerası")
@export var sway_deg: float = 8.0
@export var sway_move_time: float = 6.0
@export var sway_pause_time: float = 4.0

@export_group("Geçişler")
@export var zoom_time: float = 0.35
@export var open_fade_time: float = 0.35
@export var close_fade_time: float = 0.28
@export var aim_turn_speed: float = 16.0
@export var overlay_color_override: Color = Color(0, 0, 0, 0)
@export_range(1.0, 300.0, 1.0) var bottom_exit_trigger_distance: float = 24.0

@export_group("Monitör Efekti")
@export_range(0.01, 1.0, 0.01) var monitor_glow_fade_in_time: float = 0.06
@export_range(0.01, 2.0, 0.01) var monitor_glow_fade_out_time: float = 0.55

@export_group("Canavar Sistemi")
@export var play_sound_translation_key: String = "PLAY_AUDIO"
@export var lost_signal_translation_key: String = "LOST_SIGNAL"
@export_range(0.0, 60.0, 0.1) var play_sound_cooldown: float = 9.0
@export var lost_signal_time: float = 0.5
@export var pending_after_lost_time: float = 0.45
@export_group("Music Box Button Layout")
@export_range(16.0, 512.0, 0.1) var wind_music_box_button_size: float = 128.0
@export_range(-2000.0, 2000.0, 0.1) var wind_music_box_button_left: float = 24.0
@export_range(-2000.0, 2000.0, 0.1) var wind_music_box_button_bottom: float = 250.0
@export_range(16.0, 512.0, 0.1) var change_music_button_size: float = 128.0
@export_range(-2000.0, 2000.0, 0.1) var change_music_button_left: float = 24.0
@export_range(-2000.0, 2000.0, 0.1) var change_music_button_bottom: float = 390.0
@export_range(16.0, 512.0, 0.1) var play_audio_button_size: float = 128.0
@export_range(-2000.0, 2000.0, 0.1) var play_audio_button_left: float = 24.0
@export_range(-2000.0, 2000.0, 0.1) var play_audio_button_bottom: float = 110.0
@export_group("Music Box")
@export_range(0.0, 0.2) var office_static_alpha: float = 0.05
@export var office_static_fade_time: float = 0.5
@export_range(40.0, 200.0, 0.01) var music_box_bpm: float = 81.27
@export_range(40.0, 200.0, 0.01) var music_box_alt_bpm: float = 82.4
@export_group("Small Caution Layout (Cam11)")
@export_range(1.0, 512.0, 0.1) var small_charge_caution_size: float = 56.0
@export_range(-2000.0, 2000.0, 0.1) var small_charge_caution_left: float = 170.0
@export_range(-2000.0, 2000.0, 0.1) var small_charge_caution_bottom: float = 285.0
@export_range(1.0, 512.0, 0.1) var small_request_caution_size: float = 56.0
@export_range(-2000.0, 2000.0, 0.1) var small_request_caution_left: float = 170.0
@export_range(-2000.0, 2000.0, 0.1) var small_request_caution_bottom: float = 430.0

@export_group("Large Caution Layout (Other Cameras)")
@export_range(1.0, 512.0, 0.1) var large_charge_caution_size: float = 120.0
@export_range(-2000.0, 2000.0, 0.1) var large_charge_caution_left: float = 30.0
@export_range(-2000.0, 2000.0, 0.1) var large_charge_caution_bottom: float = 250.0
@export_range(1.0, 512.0, 0.1) var large_request_caution_size: float = 120.0
@export_range(-2000.0, 2000.0, 0.1) var large_request_caution_left: float = 30.0
@export_range(-2000.0, 2000.0, 0.1) var large_request_caution_bottom: float = 400.0

@export_group("70 BPM Caution Layout")
@export_range(-2000.0, 2000.0, 0.1) var late_70_bpm_caution_left: float = 210.0
@export_range(-2000.0, 2000.0, 0.1) var late_70_bpm_caution_bottom: float = 110.0

@export var line_1_num_offset_x: float = 2.0
@export var line_2_num_offset_x: float = 1.0

@onready var root_ctrl: Control = $Root
@onready var cam_viewport: SubViewport = $Root/CamViewContainer/CamViewport
@onready var cam_camera: Camera3D = $Root/CamViewContainer/CamViewport/CamCamera
@onready var static_noise: TextureRect = $Root/StaticNoise
@onready var scanline: Control = $Root/Scanline
@onready var frame_rect: TextureRect = $Root/Frame
@onready var cam_label: Label = $Root/CamLabel
@onready var btn_cam1: Button = $Root/BtnCam1
@onready var btn_cam2: Button = $Root/BtnCam2
@onready var overlay: ColorRect = $Root/ScreenOverlay
@onready var snap_timer: Timer = $Root/SnapTimer
@onready var snap_timer_you: Timer = $Root/SnapTimerYou

var _cam_buttons: Array[Button] = []
var _hovered_cam_idx: int = -1
var _thin_scanline: Control
var _third_scanline: Control
var _pending_overlay: ColorRect
var _pending_label: Label
var _you_label: Label
var _you_square: ColorRect
var _map_lines: Array[ColorRect] = []
var _map_line_labels: Array[Label] = []
var _map_line_anchors: Array[Vector2] = [
	MAP_LINE_1_ANCHOR,
	MAP_LINE_2_ANCHOR,
	MAP_LINE_3_ANCHOR,
	MAP_LINE_4_ANCHOR,
	MAP_LINE_5_ANCHOR,
	MAP_LINE_6_ANCHOR
]
var _you_square_large: bool = true
var _switching_cam: bool = false
var _lost_signal_active: bool = false
var _state: State = State.IDLE
var _player_cam: PlayerCamera
var _mouse_mode_before_cams: int = Input.MOUSE_MODE_VISIBLE
var _hitbox: GlowHitbox
var _zoom_view: Camera3D
var _cam_points: Array[Camera3D] = []
var _current_cam: int = 0
var _scan_y: float = 0.0
var _thin_scan_y: float = 0.0
var _third_scan_y: float = 0.0
var _last_static: int = -1
var _buttons_initialized: bool = false
var _base_cam_quat: Quaternion = Quaternion.IDENTITY
var _btn_play_sound: Button
var _mobile_exit_button: Button
var _mobile_exit_layer: CanvasLayer
var _mobile_cursor: TextureRect
var _mobile_cursor_has_position: bool = false
var _mobile_hide_exit_mode: bool = false
var _audio_wave_effect: Control
var _lost_signal_audio: AudioStreamPlayer3D
var _after_lost_audio: AudioStreamPlayer3D
var _camera_select_audio: AudioStreamPlayer3D
var _monitor_glow_audio: AudioStreamPlayer3D
var _monitor_open_audio: AudioStreamPlayer3D
var _click_audio: AudioStreamPlayer3D
var _danger_audio: AudioStreamPlayer3D
var _change_request_audio: AudioStreamPlayer2D
var _universal_audio_players: Dictionary = {}
var _monitor_glow_tween: Tween
var _monitor_open_fade_tween: Tween
var _play_cooldown_left: float = 0.0
var _cam_locks: Dictionary = {}
var _close_requested: bool = false
var _office_static_layer: CanvasLayer
var _office_static_noise: TextureRect
var _office_static_left: float = 0.0
var _office_static_frame_left: float = 0.0
var _office_static_last: int = -1
var _office_static_active: bool = false
var _office_static_tween: Tween
var _music_box_wind_button: Button
var _music_box_change_button: Button
var _music_box_bar_bg: ColorRect
var _music_box_bar_fill: ColorRect
var _request_bar_bg: ColorRect
var _request_bar_fill: ColorRect
var _music_box_caution: TextureRect
var _music_box_caution_late: TextureRect
var _music_box_request_caution: TextureRect
var _music_box_request_caution_debug: TextureRect
var _music_box_caution_tween: Tween
var _music_box_caution_late_animation_tween: Tween
var _music_box_warning_late_tween: Tween
var _music_box_opacity_tween: Tween
var _music_box_warning_tween: Tween
var _music_box_request_caution_tween: Tween
var _music_box_request_caution_debug_tween: Tween
var _music_box_request_caution_visibility_tween: Tween
var _music_box_request_caution_target: bool = false
var _debug_mode: bool = false
var _music_box_charge: float = 1.0
var _music_box_enabled: bool = true
var _music_box_winding: bool = false
var _music_box_beat_left: float = 0.0
var _music_box_beat_sign: float = 1.0
var _winding_audio_player: AudioStreamPlayer
var _winding_audio_active: bool = false
var _winding_audio_beat_left: float = 0.0
var _music_box_warning_target: bool = false
var _music_box_warning_late_target: bool = false
var _music_box_late_active: bool = false
var _music_box_alt_active: bool = false
var _song_request_active: bool = false
var _song_request_progress: float = 0.0
var _change_btn_beat_left: float = 0.0
var _change_btn_yellow: bool = false
var _input_blocked: bool = false
var _jumpscare_interrupted: bool = false
var _mobile_exit_suppressed_for_jumpscare: bool = false
var _music_box_danger_beat_count: int = 0
var _music_box_request_beat_left: float = 0.0
var _music_box_request_beat_sign: float = 1.0
var _syncing_map_anchor: bool = false


func _ready() -> void:
	var stale_exit := find_child("BtnExit", true, false)
	if stale_exit and is_instance_valid(stale_exit):
		stale_exit.queue_free()

	map_anchor = Vector2(clampf(map_anchor_x, 0.0, 1.0), clampf(map_anchor_y, 0.0, 1.0))
	map_anchor_x = map_anchor.x
	map_anchor_y = map_anchor.y
	map_scale = maxf(map_scale, 0.05)
	hud_element_scale = maxf(hud_element_scale, 0.05)
	map_line_scale = maxf(map_line_scale, 0.05)

	for stale_layer in get_tree().root.find_children("OfficeStaticEffect", "CanvasLayer", true, false):
		stale_layer.queue_free()
	_music_box_enabled = Difficulties.ouz_enabled
	visible = false
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	_load_static_frames_if_empty()

	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_mobile_exit_button()
	_ensure_winding_audio_player()
	if not GameSettings.mobile_mode_changed.is_connected(_on_mobile_mode_changed):
		GameSettings.mobile_mode_changed.connect(_on_mobile_mode_changed)
	static_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 50

	static_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	static_noise.stretch_mode = TextureRect.STRETCH_TILE
	static_noise.visible = true
	static_noise.modulate = Color(1.0, 1.0, 1.0, static_alpha)

	_ensure_extra_scanlines()
	_ensure_you_label()
	_ensure_you_square()
	_ensure_map_lines()
	_ensure_pending_overlay()

	snap_timer.wait_time = 1.0 / 12.0
	snap_timer.one_shot = false
	if not snap_timer.timeout.is_connected(_tick):
		snap_timer.timeout.connect(_tick)
	snap_timer.start()

	if snap_timer_you and is_instance_valid(snap_timer_you):
		snap_timer_you.wait_time = 1.0
		snap_timer_you.one_shot = false
		if not snap_timer_you.timeout.is_connected(_tick_you):
			snap_timer_you.timeout.connect(_tick_you)
		snap_timer_you.start()

	_force_layout()
	_update_static()
	_apply_win95_font()
	_layout_pending_label()
	_refresh_label()
	if auto_layout:
		_layout_ui()
	_setup_map_frame()
	_order_pending_behind_hud()
	_order_overlay_on_top()
	_layout_play_sound_button()

	if _find_world_nodes():
		_start_monitor_glow()
		_clamp_current_cam()
		if not _hitbox.clicked.is_connected(_on_monitor_clicked):
			_hitbox.clicked.connect(_on_monitor_clicked)


func _get_cam_translation_keys() -> Array[String]:
	return [
		cam1_translation_key,
		cam2_translation_key,
		cam3_translation_key,
		cam4_translation_key,
		cam5_translation_key,
		cam6_translation_key,
		cam7_translation_key,
		cam8_translation_key,
		cam9_translation_key,
		cam10_translation_key,
		cam11_translation_key,
		cam12_translation_key,
		cam13_translation_key
	]


func _get_cam_translation_key(index: int) -> String:
	var keys := _get_cam_translation_keys()
	if index >= 0 and index < keys.size():
		var k: String = keys[index].strip_edges()
		if not k.is_empty():
			return k
	return "CAM_%s" % _get_cam_code(index).to_upper()


func _get_cam_anchors() -> Array[Vector2]:
	return [
		cam1_map_anchor,
		cam2_map_anchor,
		cam3_map_anchor,
		cam4_map_anchor,
		cam5_map_anchor,
		cam6_map_anchor,
		cam7_map_anchor,
		cam8_map_anchor,
		cam9_map_anchor,
		cam10_map_anchor,
		cam11_map_anchor,
		cam12_map_anchor,
		cam13_map_anchor
	]


func _get_cam_code(index: int) -> String:
	match index:
		5:
			return "6a"
		11:
			return "6b"
		12:
			return "6c"
		_:
			return str(index + 1)


func _get_cam_button_text(index: int) -> String:
	return "%s\n%s" % [tr("CAM"), _get_cam_code(index)]


func _get_effective_map_scale() -> float:
	var base_area := 300.0 * 300.0
	var rect := _get_map_rect_in_root()
	var current_area := maxf(rect.size.x * rect.size.y, 1.0)
	return sqrt(current_area / base_area)


func _get_hud_scale() -> float:
	var s := maxf(_get_effective_map_scale(), 0.05)
	return lerpf(1.0, s, 0.35) * maxf(hud_element_scale, 0.05)


func _get_line_scale() -> float:
	var s := maxf(_get_effective_map_scale(), 0.05)
	return lerpf(1.0, s, 0.35) * maxf(map_line_scale, 0.05)


func _get_scaled_cam_button_size() -> Vector2:
	return cam_button_size * GameSettings.camera_button_size_scale * _get_hud_scale()


func _clamp_current_cam() -> void:
	_current_cam = clampi(_current_cam, 0, CAM_COUNT - 1)


func _load_static_frames_if_empty() -> void:
	if not static_frames.is_empty():
		return

	var found_paths: Dictionary = {}
	for i in range(1, 10):
		var file_name: String = "static_%02d.png" % i
		for base_dir: String in STATIC_DIR_CANDIDATES:
			var candidate: String = base_dir.path_join(file_name)
			if ResourceLoader.exists(candidate):
				found_paths[i] = candidate
				break

	if found_paths.size() < 9:
		_scan_dir_for_statics("res://", found_paths)

	for i in range(1, 10):
		if found_paths.has(i):
			var path_str: String = str(found_paths[i])
			var tex := load(path_str) as Texture2D
			if tex:
				static_frames.append(tex)


func _scan_dir_for_statics(dir_path: String, found_paths: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				var sub_dir: String = dir_path.path_join(entry)
				_scan_dir_for_statics(sub_dir, found_paths)
		else:
			for i in range(1, 10):
				var target: String = "static_%02d.png" % i
				if entry == target and not found_paths.has(i):
					var full_path: String = dir_path.path_join(entry)
					found_paths[i] = full_path
		entry = dir.get_next()
	dir.list_dir_end()


func _process(delta: float) -> void:
	if not Difficulties.ouz_enabled and _music_box_enabled:
		set_music_box_enabled(false, true)
	_process_office_static(delta)
	_process_music_box_warning(delta)
	_process_change_button_beat(delta)
	_update_music_box_winding_from_mouse()
	_process_winding_audio(delta)
	_update_play_sound_button()
	_update_mobile_cursor_visibility()
	if not _input_blocked and not GameSettings.mobile_mode:
		_check_bottom_edge_exit()
	if _play_cooldown_left > 0.0:
		_play_cooldown_left = maxf(_play_cooldown_left - delta, 0.0)
		_update_play_sound_button()
	if not _player_cam or not is_instance_valid(_player_cam):
		return
	if _state == State.ZOOMING_IN and _zoom_view and is_instance_valid(_zoom_view):
		var zoom_quat := _zoom_view.global_transform.basis.get_rotation_quaternion().normalized()
		_blend_camera_rotation(zoom_quat, delta)
	elif _state == State.ZOOMING_OUT:
		_blend_camera_rotation(_base_cam_quat, delta)


func _ensure_mobile_exit_button() -> void:
	_mobile_exit_layer = CanvasLayer.new()
	_mobile_exit_layer.name = "MobileExitOverlay"
	_mobile_exit_layer.layer = 100
	add_child(_mobile_exit_layer)

	_mobile_exit_button = Button.new()
	_mobile_exit_button.name = "MobileExitButton"
	_mobile_exit_button.text = ""
	_mobile_exit_button.custom_minimum_size = Vector2(128.0, 60.0)
	_mobile_exit_button.focus_mode = Control.FOCUS_NONE
	_mobile_exit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_mobile_exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mobile_exit_button.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
	_mobile_exit_button.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
	_mobile_exit_button.add_theme_stylebox_override("pressed", _make_style(BTN_PRESSED))
	_mobile_exit_button.add_theme_stylebox_override("hover_pressed", _make_style(BTN_PRESSED))
	_mobile_exit_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_mobile_exit_button_position(false)
	_mobile_exit_button.z_index = 45
	_mobile_exit_button.visible = false
	_mobile_exit_button.pressed.connect(_on_mobile_exit_pressed)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = EXIT_TEXTURE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -22.0
	icon.offset_top = -22.0
	icon.offset_right = 22.0
	icon.offset_bottom = 22.0
	_mobile_exit_button.add_child(icon)
	_mobile_exit_layer.add_child(_mobile_exit_button)

	_mobile_cursor = TextureRect.new()
	_mobile_cursor.name = "MobileWin95Cursor"
	_mobile_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mobile_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mobile_cursor.custom_minimum_size = Vector2(48.0, 48.0)
	_mobile_cursor.size = Vector2(48.0, 48.0)
	_mobile_cursor.z_index = 60
	_mobile_cursor.visible = false
	_mobile_exit_layer.add_child(_mobile_cursor)


func _on_mobile_exit_pressed() -> void:
	if _mobile_hide_exit_mode:
		set_mobile_hide_exit_mode(false)
		mobile_hide_exit_requested.emit()
		return
	_trigger_bottom_exit()


func _on_mobile_mode_changed(_enabled: bool) -> void:
	_update_mobile_exit_button()
	_update_mobile_cursor_visibility()


func _update_mobile_cursor_visibility() -> void:
	if not _mobile_cursor or not is_instance_valid(_mobile_cursor):
		return
	_mobile_cursor.visible = (
		GameSettings.mobile_mode
		and visible
		and _state != State.IDLE
		and not _input_blocked
		and _mobile_cursor_has_position
	)


func _update_mobile_cursor_at(viewport_position: Vector2) -> void:
	if not _mobile_cursor or not is_instance_valid(_mobile_cursor):
		return
	var over_clickable := _is_mobile_clickable_at(viewport_position)
	var cursor_texture := CURSOR_HAND if over_clickable else CURSOR_ARROW
	_mobile_cursor.texture = cursor_texture
	var cursor_size := Vector2(48.0, 48.0)
	_mobile_cursor.position = viewport_position - (hand_hotspot if over_clickable else Vector2.ZERO)
	_mobile_cursor.size = cursor_size
	_mobile_cursor_has_position = true
	_update_mobile_cursor_visibility()


func _is_mobile_clickable_at(viewport_position: Vector2) -> bool:
	var controls: Array[Control] = []
	for button: Button in _cam_buttons:
		if button and is_instance_valid(button):
			controls.append(button)
	for control: Control in [_mobile_exit_button, _btn_play_sound, _music_box_wind_button, _music_box_change_button]:
		if control and is_instance_valid(control):
			controls.append(control)
	for control: Control in controls:
		if not control.visible or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		if control.get_global_rect().has_point(viewport_position):
			return true
	return false


func _update_mobile_exit_button() -> void:
	if _mobile_exit_button and is_instance_valid(_mobile_exit_button):
		_mobile_exit_button.visible = (
			GameSettings.mobile_mode
			and not _mobile_exit_suppressed_for_jumpscare
			and (_mobile_hide_exit_mode or (_state == State.ACTIVE and visible))
		)


func set_mobile_hide_exit_mode(enabled: bool) -> void:
	_mobile_hide_exit_mode = enabled
	_set_mobile_exit_button_position(enabled)
	_update_mobile_exit_button()


func _set_mobile_exit_button_position(centered: bool) -> void:
	if not _mobile_exit_button:
		return
	if centered:
		_mobile_exit_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_mobile_exit_button.offset_left = -MOBILE_HIDE_EXIT_BUTTON_WIDTH * 0.5
		_mobile_exit_button.offset_top = -84.0
		_mobile_exit_button.offset_right = MOBILE_HIDE_EXIT_BUTTON_WIDTH * 0.5
		_mobile_exit_button.offset_bottom = -24.0
	else:
		_mobile_exit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_mobile_exit_button.offset_left = -250.0
		_mobile_exit_button.offset_top = -84.0
		_mobile_exit_button.offset_right = -24.0
		_mobile_exit_button.offset_bottom = -24.0


func _check_bottom_edge_exit() -> void:
	if _input_blocked or _state != State.ACTIVE or (_switching_cam and not _lost_signal_active) or GameSettings.mobile_mode:
		return
	var vp_height := _get_root_viewport_size().y
	if vp_height <= 1.0:
		return
	var mouse_y := root_ctrl.get_global_mouse_position().y
	var dist_from_bottom := vp_height - mouse_y
	if dist_from_bottom <= maxf(bottom_exit_trigger_distance, 0.0):
		_trigger_bottom_exit()


func _trigger_bottom_exit() -> void:
	if _input_blocked or _state != State.ACTIVE or (_switching_cam and not _lost_signal_active):
		return
	_play_audio(_click_audio)
	_close_ui()


func _blend_camera_rotation(target_quat: Quaternion, delta: float) -> void:
	var current_quat := _player_cam.global_transform.basis.get_rotation_quaternion().normalized()
	var end_quat := target_quat.normalized()
	if current_quat.dot(end_quat) < 0.0:
		end_quat = -end_quat
	var t := clampf(aim_turn_speed * delta, 0.0, 1.0)
	var blended_basis := Basis(current_quat.slerp(end_quat, t).normalized())
	_player_cam.global_transform = Transform3D(blended_basis, _player_cam.global_transform.origin)


func _ensure_extra_scanlines() -> void:
	var base_idx: int = scanline.get_index()
	if not _thin_scanline or not is_instance_valid(_thin_scanline):
		_thin_scanline = scanline.duplicate() as Control
		_thin_scanline.name = "ThinScanline"
		_thin_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_thin_scanline)
		root_ctrl.move_child(_thin_scanline, base_idx + 1)

	if not _third_scanline or not is_instance_valid(_third_scanline):
		_third_scanline = scanline.duplicate() as Control
		_third_scanline.name = "ThirdScanline"
		_third_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_third_scanline)
		root_ctrl.move_child(_third_scanline, base_idx + 2)


func _ensure_you_label() -> void:
	if not _you_label or not is_instance_valid(_you_label):
		_you_label = Label.new()
		_you_label.name = "YouLabel"
		_you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_you_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_you_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_you_label)
	_you_label.text = you_translation_key
	_you_label.visible = true


func _ensure_you_square() -> void:
	if not _you_square or not is_instance_valid(_you_square):
		_you_square = ColorRect.new()
		_you_square.name = "YouSquare"
		_you_square.color = Color(1.0, 1.0, 1.0, 1.0)
		_you_square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_you_square)
	_you_square.visible = true


func _apply_map_line_number_style(lbl: Label, num: int) -> void:
	if not lbl or not is_instance_valid(lbl):
		return
	var hs := _get_hud_scale()
	lbl.text = str(num)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if win95_font and is_instance_valid(win95_font):
		lbl.add_theme_font_override("font", win95_font)
	else:
		lbl.remove_theme_font_override("font")
	lbl.add_theme_font_size_override("font_size", maxi(int(round(11.0 * hs)), 8))
	lbl.add_theme_color_override("font_color", map_line_number_color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", maxi(int(round(1.0 * hs)), 1))
	lbl.visible = seal_lines_enabled


func set_map_line_anchor(line_index: int, anchor: Vector2) -> void:
	if line_index < 0 or line_index >= 6:
		return
	while _map_line_anchors.size() < 6:
		_map_line_anchors.append(Vector2(0.5, 0.5))
	_map_line_anchors[line_index] = anchor
	_layout_map_lines()
	_order_map_layer_stack()


func _ensure_map_lines() -> void:
	while _map_line_anchors.size() < 6:
		_map_line_anchors.append(Vector2(0.5, 0.5))
	var desired_names: Array[String] = [
		line_1_name,
		line_2_name,
		line_3_name,
		line_4_name,
		line_5_name,
		line_6_name
	]
	for i in range(6):
		var line_num: int = i + 1
		var line: ColorRect
		if i < _map_lines.size() and _map_lines[i] and is_instance_valid(_map_lines[i]):
			line = _map_lines[i]
		else:
			line = ColorRect.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root_ctrl.add_child(line)
			if i < _map_lines.size():
				_map_lines[i] = line
			else:
				_map_lines.append(line)
		var clean_name := desired_names[i].strip_edges()
		if clean_name.is_empty():
			clean_name = "MapLine%d" % line_num
		if line.name != clean_name:
			line.name = clean_name
		line.color = map_line_color
		line.visible = seal_lines_enabled

		var num_lbl: Label
		if i < _map_line_labels.size() and _map_line_labels[i] and is_instance_valid(_map_line_labels[i]):
			num_lbl = _map_line_labels[i]
		else:
			num_lbl = Label.new()
			root_ctrl.add_child(num_lbl)
			if i < _map_line_labels.size():
				_map_line_labels[i] = num_lbl
			else:
				_map_line_labels.append(num_lbl)
		var expected_lbl_name := "MapLineNumber%d" % line_num
		if num_lbl.name != expected_lbl_name:
			num_lbl.name = expected_lbl_name
		_apply_map_line_number_style(num_lbl, line_num)


func _clamp_rect_to_bounds(top_left: Vector2, size_px: Vector2, bounds: Rect2) -> Rect2:
	var clamped_size := Vector2(
		minf(maxf(size_px.x, 1.0), maxf(bounds.size.x, 1.0)),
		minf(maxf(size_px.y, 1.0), maxf(bounds.size.y, 1.0))
	)
	var max_x := maxf(bounds.position.x, bounds.end.x - clamped_size.x)
	var max_y := maxf(bounds.position.y, bounds.end.y - clamped_size.y)
	var clamped_pos := Vector2(
		clampf(top_left.x, bounds.position.x, max_x),
		clampf(top_left.y, bounds.position.y, max_y)
	)
	return Rect2(clamped_pos, clamped_size)


func _layout_map_lines() -> void:
	_ensure_map_lines()
	var ls := _get_line_scale()
	var hs := _get_hud_scale()
	var map_rect: Rect2 = _get_map_rect_in_root()
	var vp_rect := Rect2(Vector2.ZERO, _get_root_viewport_size())
	var safe_bounds: Rect2 = map_rect.intersection(vp_rect)
	if safe_bounds.size.x <= 1.0 or safe_bounds.size.y <= 1.0:
		safe_bounds = vp_rect

	var thickness: float = maxf(map_line_thickness * ls, 1.5)
	var len_1: float = maxf(line_1_length * ls, 2.0)
	var len_2: float = maxf(line_2_length * ls, 2.0)
	var len_3: float = maxf(line_3_length * ls, 2.0)
	var len_4: float = maxf(line_4_length * ls, 2.0)
	var len_5: float = maxf(line_5_length * ls, 2.0)
	var len_6: float = maxf(line_6_length * ls, 2.0)

	var configs: Array[Dictionary] = [
		{"num": 1, "anchor": _map_line_anchors[0], "size": Vector2(thickness, len_1)},
		{"num": 2, "anchor": _map_line_anchors[1], "size": Vector2(thickness, len_2)},
		{"num": 3, "anchor": _map_line_anchors[2], "size": Vector2(len_3, thickness)},
		{"num": 4, "anchor": _map_line_anchors[3], "size": Vector2(len_4, thickness)},
		{"num": 5, "anchor": _map_line_anchors[4], "size": Vector2(len_5, thickness)},
		{"num": 6, "anchor": _map_line_anchors[5], "size": Vector2(len_6, thickness)}
	]

	for i in range(configs.size()):
		var line: ColorRect = _map_lines[i]
		if not line or not is_instance_valid(line):
			continue
		var cfg: Dictionary = configs[i]
		var line_num: int = int(cfg["num"])
		var uv: Vector2 = cfg["anchor"]
		var sz: Vector2 = cfg["size"]
		var center := Vector2(
			map_rect.position.x + map_rect.size.x * uv.x,
			map_rect.position.y + map_rect.size.y * uv.y
		)
		var clamped_rect := _clamp_rect_to_bounds(center - (sz * 0.5), sz, safe_bounds)
		line.color = map_line_color
		line.visible = seal_lines_enabled
		line.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
		line.offset_left = clamped_rect.position.x
		line.offset_top = clamped_rect.position.y
		line.offset_right = clamped_rect.end.x
		line.offset_bottom = clamped_rect.end.y

		if i < _map_line_labels.size() and _map_line_labels[i] and is_instance_valid(_map_line_labels[i]):
			var num_lbl: Label = _map_line_labels[i]
			_apply_map_line_number_style(num_lbl, line_num)
			var lbl_size := num_lbl.get_combined_minimum_size().max(Vector2(15.0 * hs, 15.0 * hs))
			var line_center := clamped_rect.get_center()
			var y_offset: float = (line_2_num_offset_y if line_num == 2 else (0.0 if line_num >= 3 else 0.0)) * hs
			var x_offset: float = (line_1_num_offset_x if line_num == 10 else (line_2_num_offset_x if line_num == 2 else 0.0)) * hs
			var target_center := line_center + Vector2(x_offset, y_offset)
			var lbl_rect := _clamp_rect_to_bounds(target_center - (lbl_size * 0.5), lbl_size, vp_rect)
			num_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
			num_lbl.offset_left = lbl_rect.position.x
			num_lbl.offset_top = lbl_rect.position.y
			num_lbl.offset_right = lbl_rect.end.x
			num_lbl.offset_bottom = lbl_rect.end.y


func _order_map_layer_stack() -> void:
	if frame_rect and is_instance_valid(frame_rect) and frame_rect.get_parent() == root_ctrl:
		frame_rect.z_index = 16
	for line: ColorRect in _map_lines:
		if line and is_instance_valid(line) and line.get_parent() == root_ctrl:
			line.z_index = 17
			if frame_rect and is_instance_valid(frame_rect) and line.get_index() <= frame_rect.get_index():
				root_ctrl.move_child(line, frame_rect.get_index() + 1)
	for num_lbl: Label in _map_line_labels:
		if num_lbl and is_instance_valid(num_lbl) and num_lbl.get_parent() == root_ctrl:
			num_lbl.z_index = 18
			for line: ColorRect in _map_lines:
				if line and is_instance_valid(line) and line.get_parent() == root_ctrl and num_lbl.get_index() <= line.get_index():
					root_ctrl.move_child(num_lbl, line.get_index() + 1)
	var front_of_lines: Array[Control] = [_you_label, _you_square, cam_label]
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			front_of_lines.append(b)
	for ctrl: Control in front_of_lines:
		if ctrl and is_instance_valid(ctrl) and ctrl.get_parent() == root_ctrl:
			ctrl.z_index = 19
			for num_lbl: Label in _map_line_labels:
				if num_lbl and is_instance_valid(num_lbl) and num_lbl.get_parent() == root_ctrl and ctrl.get_index() <= num_lbl.get_index():
					root_ctrl.move_child(ctrl, num_lbl.get_index() + 1)


func _layout_you_square() -> void:
	if not _you_square or not is_instance_valid(_you_square):
		return
	var hs := _get_hud_scale()
	var sq_size_px: float = (9.5 if _you_square_large else 6.0) * hs
	var sq_size := Vector2(sq_size_px, sq_size_px)
	_place_control_on_map(_you_square, you_square_map_anchor, sq_size)


func _order_overlay_on_top() -> void:
	_order_map_layer_stack()
	if not overlay or not is_instance_valid(overlay) or overlay.get_parent() != root_ctrl:
		return
	var below_overlay: Array[Control] = [frame_rect, _you_label, _you_square, cam_label]
	for line: ColorRect in _map_lines:
		if line and is_instance_valid(line):
			below_overlay.append(line)
	for num_lbl: Label in _map_line_labels:
		if num_lbl and is_instance_valid(num_lbl):
			below_overlay.append(num_lbl)
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			below_overlay.append(b)
	for ctrl: Control in below_overlay:
		if ctrl and is_instance_valid(ctrl) and ctrl.get_parent() == root_ctrl:
			if ctrl.get_index() >= overlay.get_index():
				root_ctrl.move_child(ctrl, maxi(overlay.get_index() - 1, 0))
	_raise_all_buttons_above_pending()


func _raise_all_buttons_above_pending() -> void:
	var all_btns: Array[Control] = []
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			all_btns.append(b)
	for c: Control in [_btn_play_sound, _music_box_wind_button, _music_box_change_button]:
		if c and is_instance_valid(c):
			all_btns.append(c)
	for btn: Control in all_btns:
		if btn.get_parent() == root_ctrl:
			btn.z_index = 40
			if _pending_overlay and is_instance_valid(_pending_overlay) and _pending_overlay.get_parent() == root_ctrl:
				if btn.get_index() <= _pending_overlay.get_index():
					root_ctrl.move_child(btn, _pending_overlay.get_index() + 1)
			if overlay and is_instance_valid(overlay) and overlay.get_parent() == root_ctrl:
				if btn.get_index() >= overlay.get_index():
					root_ctrl.move_child(btn, maxi(overlay.get_index() - 1, 0))


func _layout_pending_label() -> void:
	if not _pending_label or not is_instance_valid(_pending_label):
		return
	var margin: float = 24.0
	_pending_label.text = pending_translation_key
	_pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pending_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_pending_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	var p_size: Vector2 = _pending_label.get_combined_minimum_size().max(Vector2(120.0, 40.0))
	_pending_label.offset_left = margin
	_pending_label.offset_right = margin + p_size.x
	_pending_label.offset_bottom = -margin
	_pending_label.offset_top = -margin - p_size.y


func _ensure_pending_overlay() -> void:
	if not _pending_overlay or not is_instance_valid(_pending_overlay):
		_pending_overlay = ColorRect.new()
		_pending_overlay.name = "PendingOverlay"
		_pending_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
		_pending_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pending_overlay.visible = false
		root_ctrl.add_child(_pending_overlay)

		_pending_label = Label.new()
		_pending_label.name = "PendingLabel"
		_pending_label.text = pending_translation_key
		_pending_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pending_overlay.add_child(_pending_label)
	elif _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key

	_layout_pending_label()
	_order_pending_behind_hud()


func _order_pending_behind_hud() -> void:
	if not _pending_overlay or not is_instance_valid(_pending_overlay):
		return
	if _pending_overlay.get_parent() != root_ctrl:
		return
	_pending_overlay.z_index = 15
	var hud_nodes: Array[Control] = [frame_rect, _you_label, _you_square, cam_label]
	for line: ColorRect in _map_lines:
		if line and is_instance_valid(line):
			hud_nodes.append(line)
	for num_lbl: Label in _map_line_labels:
		if num_lbl and is_instance_valid(num_lbl):
			hud_nodes.append(num_lbl)
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			hud_nodes.append(b)
	for c: Control in [_btn_play_sound, _music_box_wind_button, _music_box_change_button]:
		if c and is_instance_valid(c):
			hud_nodes.append(c)
	var first_hud_idx: int = root_ctrl.get_child_count()
	for hud_node: Control in hud_nodes:
		if hud_node and hud_node.get_parent() == root_ctrl:
			first_hud_idx = mini(first_hud_idx, hud_node.get_index())
	var desired_idx: int = maxi(first_hud_idx - 1, 0)
	if _pending_overlay.get_index() >= first_hud_idx:
		desired_idx = first_hud_idx
	root_ctrl.move_child(_pending_overlay, desired_idx)
	for hud_node: Control in hud_nodes:
		if hud_node and hud_node.get_parent() == root_ctrl and hud_node.get_index() < _pending_overlay.get_index():
			root_ctrl.move_child(hud_node, _pending_overlay.get_index() + 1)
	_order_map_layer_stack()
	_raise_all_buttons_above_pending()


func _set_transition_controls_behind(_behind: bool) -> void:
	if _audio_wave_effect and is_instance_valid(_audio_wave_effect):
		_audio_wave_effect.z_index = 30
	if _music_box_bar_bg and is_instance_valid(_music_box_bar_bg):
		_music_box_bar_bg.z_index = 26
	if _request_bar_bg and is_instance_valid(_request_bar_bg):
		_request_bar_bg.z_index = 27
	_raise_all_buttons_above_pending()
	if _music_box_caution and is_instance_valid(_music_box_caution):
		_music_box_caution.z_index = 25


func _get_root_viewport_size() -> Vector2:
	var root_size: Vector2 = root_ctrl.size
	if root_size.x <= 1.0 or root_size.y <= 1.0:
		root_size = get_viewport().get_visible_rect().size
	return root_size


func _get_map_rect_in_root() -> Rect2:
	var root_size: Vector2 = _get_root_viewport_size()
	var effective_anchor := Vector2(
		clampf(map_anchor_x, 0.0, 1.0),
		clampf(map_anchor_y, 0.0, 1.0)
	)
	var box_size := Vector2(maxf(map_size_px.x, 10.0), maxf(map_size_px.y, 10.0)) * maxf(map_scale, 0.05)
	var drawn_size: Vector2 = box_size
	var tex: Texture2D = camera_map_texture if camera_map_texture else CAMERA_MAP_TEX
	if tex:
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var fit_ratio: float = minf(box_size.x / tex_size.x, box_size.y / tex_size.y)
			drawn_size = tex_size * fit_ratio
	var center_pos := Vector2(
		root_size.x * effective_anchor.x,
		root_size.y * effective_anchor.y
	) + map_offset_px
	var top_left: Vector2 = center_pos - (drawn_size * 0.5)
	return Rect2(top_left, drawn_size)


func _setup_map_frame() -> void:
	if not frame_rect or not is_instance_valid(frame_rect):
		return
	var tex: Texture2D = camera_map_texture if camera_map_texture else CAMERA_MAP_TEX
	if tex:
		frame_rect.texture = tex
	frame_rect.visible = true
	frame_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var map_rect: Rect2 = _get_map_rect_in_root()
	frame_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	frame_rect.offset_left = map_rect.position.x
	frame_rect.offset_top = map_rect.position.y
	frame_rect.offset_right = map_rect.position.x + map_rect.size.x
	frame_rect.offset_bottom = map_rect.position.y + map_rect.size.y


func _place_control_on_map(ctrl: Control, map_uv: Vector2, ctrl_size: Vector2) -> void:
	if not ctrl or not is_instance_valid(ctrl):
		return
	var map_rect: Rect2 = _get_map_rect_in_root()
	var center_pos: Vector2 = map_rect.position + Vector2(
		map_rect.size.x * map_uv.x,
		map_rect.size.y * map_uv.y
	)
	var top_left: Vector2 = center_pos - (ctrl_size * 0.5)
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	ctrl.offset_left = top_left.x
	ctrl.offset_top = top_left.y
	ctrl.offset_right = top_left.x + ctrl_size.x
	ctrl.offset_bottom = top_left.y + ctrl_size.y


func _force_layout() -> void:
	for c: Control in [root_ctrl, $Root/CamViewContainer, static_noise, overlay]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	static_noise.modulate.a = static_alpha

	_ensure_extra_scanlines()
	_ensure_you_label()
	_ensure_you_square()
	_ensure_map_lines()
	_ensure_pending_overlay()

	_pending_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_pending_label()

	scanline.custom_minimum_size = Vector2(0.0, scanline_height)
	scanline.size.y = scanline_height
	scanline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_thin_scanline.custom_minimum_size = Vector2(0.0, thin_scanline_height)
	_thin_scanline.size.y = thin_scanline_height
	_thin_scanline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_third_scanline.custom_minimum_size = Vector2(0.0, third_scanline_height)
	_third_scanline.size.y = third_scanline_height
	_third_scanline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_setup_buttons()
	_ensure_play_sound_button()
	_ensure_music_box_controls()
	_apply_win95_font()
	_layout_pending_label()
	_refresh_label()
	if auto_layout:
		_layout_ui()
	_setup_map_frame()
	_layout_map_lines()
	_order_pending_behind_hud()
	_order_overlay_on_top()
	_layout_play_sound_button()
	_layout_music_box_controls()


func _exit_tree() -> void:
	_set_cursor(false)
	_office_static_active = false
	_office_static_left = 0.0
	if _office_static_layer and is_instance_valid(_office_static_layer):
		_office_static_layer.queue_free()
	for key: Variant in _universal_audio_players.keys():
		var p := _universal_audio_players[key] as AudioStreamPlayer
		if p and is_instance_valid(p):
			p.queue_free()
	_universal_audio_players.clear()


func _input(event: InputEvent) -> void:
	if _input_blocked and (event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
		return
	if not GameSettings.mobile_mode or _state == State.IDLE or not visible or _input_blocked:
		return
	if event is InputEventScreenTouch:
		_update_mobile_cursor_at((event as InputEventScreenTouch).position)
	elif event is InputEventScreenDrag:
		_update_mobile_cursor_at((event as InputEventScreenDrag).position)
	elif event is InputEventMouseMotion:
		_update_mobile_cursor_at((event as InputEventMouseMotion).position)


func _unhandled_input(event: InputEvent) -> void:
	if _input_blocked:
		return
	if event.is_action_pressed("ui_cancel") and _state == State.ACTIVE:
		_trigger_bottom_exit()


func _register_universal_player(source_3d: AudioStreamPlayer3D, volume_db: float) -> void:
	if not source_3d or not is_instance_valid(source_3d):
		return
	source_3d.stop()
	source_3d.volume_db = AudioSettings.MUTED_DB
	source_3d.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
	var player: AudioStreamPlayer
	if _universal_audio_players.has(source_3d) and is_instance_valid(_universal_audio_players[source_3d]):
		player = _universal_audio_players[source_3d] as AudioStreamPlayer
	else:
		player = AudioStreamPlayer.new()
		player.name = "%s_Universal" % source_3d.name
		add_child(player)
		_universal_audio_players[source_3d] = player
	player.stream = source_3d.stream
	player.pitch_scale = source_3d.pitch_scale
	player.bus = source_3d.bus
	player.volume_db = volume_db


func _get_universal_player(source_3d: AudioStreamPlayer3D) -> AudioStreamPlayer:
	if not source_3d or not is_instance_valid(source_3d):
		return null
	if not _universal_audio_players.has(source_3d) or not is_instance_valid(_universal_audio_players[source_3d]):
		_register_universal_player(source_3d, AudioSettings.UNIVERSAL_SFX_DB)
	var player := _universal_audio_players[source_3d] as AudioStreamPlayer
	if player and is_instance_valid(player):
		player.stream = source_3d.stream
		player.pitch_scale = source_3d.pitch_scale
		player.bus = source_3d.bus
	return player


func _find_world_nodes() -> bool:
	var tree_root := get_tree().root
	_player_cam = tree_root.find_child("Camera3D", true, false) as PlayerCamera
	_hitbox = tree_root.find_child("MonitorHitbox", true, false) as GlowHitbox
	_zoom_view = tree_root.find_child("MonitorZoomView", true, false) as Camera3D
	_lost_signal_audio = tree_root.find_child("LostSignal", true, false) as AudioStreamPlayer3D
	_after_lost_audio = tree_root.find_child("AfterLost", true, false) as AudioStreamPlayer3D
	_camera_select_audio = tree_root.find_child("CameraSelect", true, false) as AudioStreamPlayer3D
	_monitor_glow_audio = tree_root.find_child("MonitorGlow", true, false) as AudioStreamPlayer3D
	_monitor_open_audio = tree_root.find_child("MonitorOpens", true, false) as AudioStreamPlayer3D
	_click_audio = tree_root.find_child("Click", true, false) as AudioStreamPlayer3D
	_danger_audio = tree_root.find_child("Danger", true, false) as AudioStreamPlayer3D

	_register_universal_player(_lost_signal_audio, AudioSettings.CAMERA_LOST_SIGNAL_DB)
	_register_universal_player(_after_lost_audio, AudioSettings.CAMERA_AFTER_LOST_DB)
	_register_universal_player(_camera_select_audio, AudioSettings.CAMERA_SELECT_DB)
	_register_universal_player(_monitor_glow_audio, AudioSettings.MUTED_DB)
	_register_universal_player(_monitor_open_audio, AudioSettings.MONITOR_OPEN_DB)
	_register_universal_player(_click_audio, AudioSettings.CAMERA_CLICK_DB)
	_register_universal_player(_danger_audio, AudioSettings.CAMERA_DANGER_DB)

	if _hitbox and not _hitbox.hover_changed.is_connected(_on_monitor_hover_changed):
		_hitbox.hover_changed.connect(_on_monitor_hover_changed)
	_cam_points.clear()
	_cam_points.resize(CAM_COUNT)
	var any_cam_found: bool = false
	for i in range(1, CAM_COUNT + 1):
		var cam_name: String = "SecCam%d" % i
		var c := tree_root.find_child(cam_name, true, false) as Camera3D
		if c:
			_cam_points[i - 1] = c
			any_cam_found = true
		else:
			push_warning("Kamera sistemi: %s düğümü sahnede bulunamadı." % cam_name)

	if not _player_cam or not _hitbox or not _zoom_view or not any_cam_found:
		push_error("Kamera sistemi: gerekli düğümler bulunamadı (Camera3D, MonitorHitbox, MonitorZoomView, SecCam1..SecCam%d)." % CAM_COUNT)
		return false
	return true


func _ensure_font_ready(font: Font) -> Font:
	if not font or not is_instance_valid(font):
		return null
	if font is SystemFont:
		var sys_font := font as SystemFont
		var names: PackedStringArray = sys_font.font_names
		var has_valid_name: bool = false
		for n: String in names:
			if not n.strip_edges().is_empty():
				has_valid_name = true
				break
		if not has_valid_name:
			sys_font.font_names = PackedStringArray(["Consolas", "Courier New", "Arial", "DejaVu Sans"])
	return font


func _build_cam_btn_font() -> Font:
	if win95_font:
		return _ensure_font_ready(win95_font)
	var cam_font := SystemFont.new()
	cam_font.font_names = PackedStringArray(["Consolas", "Courier New", "Lucida Console", "Arial", "DejaVu Sans"])
	cam_font.font_weight = 700
	cam_font.font_stretch = 110
	return _ensure_font_ready(cam_font)


func _build_pending_font() -> Font:
	if win95_font:
		return _ensure_font_ready(win95_font)
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["Courier New", "Consolas", "Arial", "DejaVu Sans"])
	return _ensure_font_ready(sys_font)


func _build_wide_font() -> Font:
	if win95_font:
		return _ensure_font_ready(win95_font)
	var wide_font := SystemFont.new()
	wide_font.font_names = PackedStringArray(["Consolas", "Courier New", "Lucida Console", "Arial", "DejaVu Sans"])
	wide_font.font_weight = 700
	wide_font.font_stretch = 150
	return _ensure_font_ready(wide_font)


func _apply_win95_font() -> void:
	var hs := _get_hud_scale()
	var cam_btn_f := _build_cam_btn_font()
	var initial_f := _build_pending_font()

	if initial_f and is_instance_valid(initial_f):
		cam_label.add_theme_font_override("font", initial_f)
	cam_label.add_theme_font_size_override("font_size", 22)
	cam_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	if _you_label and is_instance_valid(_you_label):
		_you_label.text = you_translation_key
		if initial_f and is_instance_valid(initial_f):
			_you_label.add_theme_font_override("font", initial_f)
		_you_label.add_theme_font_size_override("font_size", maxi(int(round(14.5 * hs)), 9))
		_you_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	for i in range(_map_line_labels.size()):
		if _map_line_labels[i] and is_instance_valid(_map_line_labels[i]):
			_apply_map_line_number_style(_map_line_labels[i], i + 1)

	var cam_text_white := Color(1.0, 1.0, 1.0, 1.0)
	var cam_shadow_black := Color(0.0, 0.0, 0.0, 1.0)
	for b: Button in _cam_buttons:
		if cam_btn_f and is_instance_valid(cam_btn_f):
			b.add_theme_font_override("font", cam_btn_f)
		b.add_theme_font_size_override("font_size", maxi(int(round(10.5 * hs)), 8))
		b.add_theme_constant_override("line_spacing", -1)
		b.add_theme_constant_override("spacing_glyph", 0)
		b.add_theme_constant_override("outline_size", 0)
		b.add_theme_color_override("font_color", cam_text_white)
		b.add_theme_color_override("font_hover_color", cam_text_white)
		b.add_theme_color_override("font_pressed_color", cam_text_white)
		b.add_theme_color_override("font_hover_pressed_color", cam_text_white)
		b.add_theme_color_override("font_shadow_color", cam_shadow_black)
		b.add_theme_constant_override("shadow_offset_x", 1)
		b.add_theme_constant_override("shadow_offset_y", 1)

	if _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key
		if initial_f and is_instance_valid(initial_f):
			_pending_label.add_theme_font_override("font", initial_f)
		_pending_label.add_theme_font_size_override("font_size", 36)
		_pending_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))


func _setup_buttons() -> void:
	var scaled_btn_size := _get_scaled_cam_button_size()
	if _cam_buttons.is_empty():
		_cam_buttons.append(btn_cam1)
		_cam_buttons.append(btn_cam2)
		for i in range(3, CAM_COUNT + 1):
			var extra_btn := Button.new()
			extra_btn.name = "BtnCam%d" % i
			root_ctrl.add_child(extra_btn)
			_cam_buttons.append(extra_btn)

	for i in range(_cam_buttons.size()):
		var b: Button = _cam_buttons[i]
		b.text = _get_cam_button_text(i)
		b.clip_contents = false
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = scaled_btn_size

	if _buttons_initialized:
		return
	_buttons_initialized = true

	var group := ButtonGroup.new()
	for i in range(_cam_buttons.size()):
		var b: Button = _cam_buttons[i]
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_select_cam.bind(i))
		b.mouse_entered.connect(_on_cam_btn_hover_changed.bind(i, true))
		b.mouse_exited.connect(_on_cam_btn_hover_changed.bind(i, false))
		var normal_style := _make_cam_style(BTN_NORMAL)
		b.add_theme_stylebox_override("normal", normal_style)
		b.add_theme_stylebox_override("hover", _make_cam_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", normal_style)
		b.add_theme_stylebox_override("hover_pressed", normal_style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_update_cam_button_opacities()


func _configure_square_icon_button(btn: Button, icon_tex: Texture2D, sq_size: float) -> void:
	btn.text = ""
	btn.custom_minimum_size = Vector2(sq_size, sq_size)
	btn.size = Vector2(sq_size, sq_size)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
	btn.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", _make_style(BTN_PRESSED))
	btn.add_theme_stylebox_override("hover_pressed", _make_style(BTN_PRESSED))
	btn.add_theme_stylebox_override("disabled", _make_style(BTN_PRESSED))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon_rect := btn.get_node_or_null("IconRect") as TextureRect
	if not icon_rect:
		icon_rect = TextureRect.new()
		icon_rect.name = "IconRect"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn.add_child(icon_rect)
	icon_rect.texture = icon_tex
	var pad := maxf(sq_size * 0.14, 4.0)
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = pad
	icon_rect.offset_top = pad
	icon_rect.offset_right = -pad
	icon_rect.offset_bottom = -pad


func _on_cam_btn_hover_changed(index: int, entered: bool) -> void:
	if entered:
		_hovered_cam_idx = index
	elif _hovered_cam_idx == index:
		_hovered_cam_idx = -1
	_update_cam_button_opacities()


func _update_cam_button_opacities() -> void:
	for i in range(_cam_buttons.size()):
		var b: Button = _cam_buttons[i]
		if not b or not is_instance_valid(b):
			continue
		var alpha: float = 0.5
		if i == _current_cam:
			alpha = 1.0
		elif i == _hovered_cam_idx:
			alpha = 0.75
		b.modulate.a = alpha


func _make_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = button_margin
	sb.texture_margin_right = button_margin
	sb.texture_margin_top = button_margin
	sb.texture_margin_bottom = button_margin
	return sb


func _make_cam_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := _make_style(tex)
	sb.content_margin_left = 2.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 2.0
	sb.content_margin_bottom = 0.0
	return sb


func _layout_ui() -> void:
	var margin: float = 24.0
	var hs := _get_hud_scale()

	cam_label.visible = true
	cam_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	cam_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	cam_label.add_theme_font_size_override("font_size", 22)
	cam_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	var lbl_size: Vector2 = cam_label.get_combined_minimum_size().max(Vector2(120.0, 28.0))
	cam_label.offset_left = margin
	cam_label.offset_top = margin
	cam_label.offset_right = margin + lbl_size.x
	cam_label.offset_bottom = margin + lbl_size.y

	_setup_map_frame()
	_layout_map_lines()
	var anchors := _get_cam_anchors()
	var scaled_btn_size := _get_scaled_cam_button_size()
	for i in range(mini(_cam_buttons.size(), anchors.size())):
		_cam_buttons[i].custom_minimum_size = scaled_btn_size
		_place_control_on_map(_cam_buttons[i], anchors[i], scaled_btn_size)

	if _you_label and is_instance_valid(_you_label):
		_you_label.text = you_translation_key
		var you_size: Vector2 = _you_label.get_combined_minimum_size().max(Vector2(48.0 * hs, 20.0 * hs))
		_place_control_on_map(_you_label, you_map_anchor, you_size)

	_layout_you_square()
	_order_map_layer_stack()
	_layout_pending_label()


func _on_monitor_clicked() -> void:
	if _input_blocked or are_cams_locked():
		return
	if _state != State.IDLE:
		return
	_jumpscare_interrupted = false
	_mobile_exit_suppressed_for_jumpscare = false
	_mouse_mode_before_cams = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	opened.emit()
	_base_cam_quat = _player_cam.global_transform.basis.get_rotation_quaternion().normalized()
	_state = State.ZOOMING_IN
	_hitbox.set_in_use(true)
	_play_monitor_open_audio()
	_player_cam.zoom_to(_zoom_view.global_transform, _zoom_view.fov, zoom_time)
	await _player_cam.zoom_finished
	if _jumpscare_interrupted:
		return
	await _open_ui()


func _open_ui() -> void:
	_state = State.OPENING
	_ensure_pending_overlay()
	_pending_overlay.visible = true
	overlay.color = _get_overlay_color()
	overlay.modulate.a = 1.0
	visible = true
	await get_tree().process_frame
	if _jumpscare_interrupted:
		return

	_clamp_current_cam()
	_sync_buttons()
	_refresh_label()
	_update_static()
	_randomize_scanlines()
	_render_cam()
	await RenderingServer.frame_post_draw
	if _jumpscare_interrupted:
		return

	_set_cursor(true)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 0.0, open_fade_time)
	await tw.finished
	if _jumpscare_interrupted:
		return

	await get_tree().create_timer(0.1).timeout
	if _jumpscare_interrupted:
		return
	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false

	_state = State.ACTIVE
	_update_mobile_exit_button()
	_update_music_box_controls()
	if _close_requested:
		_close_requested = false
		_close_ui()


func _close_ui() -> void:
	_state = State.CLOSING
	_update_play_sound_button()
	_update_mobile_exit_button()
	closed.emit()
	_close_requested = false
	overlay.color = _get_overlay_color()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 1.0, close_fade_time)
	await tw.finished

	visible = false
	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false
	_music_box_winding = false
	_update_music_box_controls()
	_set_cursor(false)
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_force_layout()

	_state = State.ZOOMING_OUT
	_player_cam.return_to_base(zoom_time)
	await _player_cam.return_finished
	Input.set_mouse_mode(_mouse_mode_before_cams)

	_hitbox.set_in_use(false)
	_state = State.IDLE


func _tick() -> void:
	_update_static()
	if not visible and _state != State.ACTIVE:
		return
	_step_scanline()
	_render_cam()


func _tick_you() -> void:
	_you_square_large = not _you_square_large
	_layout_you_square()


func _get_sway_angle_rad() -> float:
	var move_t: float = maxf(sway_move_time, 0.05)
	var pause_t: float = maxf(sway_pause_time, 0.0)
	var cycle_len: float = (move_t + pause_t) * 2.0
	var elapsed: float = fmod(Time.get_ticks_msec() / 1000.0, cycle_len)

	var factor: float = -1.0
	if elapsed < move_t:
		var p: float = smoothstep(0.0, 1.0, elapsed / move_t)
		factor = lerpf(-1.0, 1.0, p)
	elif elapsed < move_t + pause_t:
		factor = 1.0
	elif elapsed < (move_t * 2.0) + pause_t:
		var p: float = smoothstep(0.0, 1.0, (elapsed - move_t - pause_t) / move_t)
		factor = lerpf(1.0, -1.0, p)
	else:
		factor = -1.0

	return factor * deg_to_rad(sway_deg)


func _render_cam() -> void:
	if _cam_points.is_empty():
		return
	_clamp_current_cam()
	if _current_cam < 0 or _current_cam >= _cam_points.size():
		return
	var point := _cam_points[_current_cam]
	if not point or not is_instance_valid(point):
		return
	var angle: float = _get_sway_angle_rad()
	var xf := point.global_transform
	cam_camera.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, angle), xf.origin)
	cam_camera.fov = point.fov
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func play_office_static(duration: float = -1.0) -> void:
	_load_static_frames_if_empty()
	if static_frames.is_empty():
		return
	if not _office_static_layer or not is_instance_valid(_office_static_layer):
		_office_static_layer = CanvasLayer.new()
		_office_static_layer.name = "OfficeStaticEffect"
		_office_static_layer.layer = 90
		var scene_root := get_tree().current_scene
		if scene_root == null:
			scene_root = get_tree().root
		scene_root.add_child(_office_static_layer)
		_office_static_noise = TextureRect.new()
		_office_static_noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_office_static_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_office_static_noise.stretch_mode = TextureRect.STRETCH_TILE
		_office_static_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_office_static_layer.add_child(_office_static_noise)

	_office_static_left = duration
	_office_static_frame_left = 0.0
	_office_static_active = true
	_office_static_layer.visible = true
	_office_static_noise.modulate.a = 0.0
	if _office_static_tween:
		_office_static_tween.kill()
	_office_static_tween = create_tween()
	_office_static_tween.tween_property(_office_static_noise, "modulate:a", office_static_alpha, maxf(office_static_fade_time, 0.01))
	_process_office_static(0.0)


func stop_office_static() -> void:
	if not _office_static_active:
		return
	_office_static_active = false
	if _office_static_tween:
		_office_static_tween.kill()
	if not _office_static_noise or not is_instance_valid(_office_static_noise):
		return
	_office_static_tween = create_tween()
	_office_static_tween.tween_property(_office_static_noise, "modulate:a", 0.0, maxf(office_static_fade_time, 0.01))
	_office_static_tween.finished.connect(func() -> void:
		if not _office_static_active and _office_static_layer and is_instance_valid(_office_static_layer):
			_office_static_layer.visible = false
	)


func _process_office_static(delta: float) -> void:
	if not _office_static_noise or not is_instance_valid(_office_static_noise):
		return
	if not _office_static_active:
		return
	if _office_static_left > 0.0:
		_office_static_left = maxf(_office_static_left - delta, 0.0)
		if _office_static_left <= 0.0:
			stop_office_static()
			return
	_office_static_frame_left -= delta
	if _office_static_frame_left <= 0.0 and not static_frames.is_empty():
		var idx := randi() % static_frames.size()
		while static_frames.size() > 1 and idx == _office_static_last:
			idx = randi() % static_frames.size()
		_office_static_last = idx
		_office_static_noise.texture = static_frames[idx]
		_office_static_frame_left = 0.045


func _update_static() -> void:
	_load_static_frames_if_empty()
	var n: int = static_frames.size()
	if n == 0:
		return
	var idx: int = randi() % n
	while n > 1 and idx == _last_static:
		idx = randi() % n
	_last_static = idx
	static_noise.texture = static_frames[idx]
	static_noise.modulate.a = static_alpha


func _step_scanline() -> void:
	_scan_y += root_ctrl.size.y * scanline_step
	if _scan_y > root_ctrl.size.y:
		_scan_y = -scanline.size.y

	_thin_scan_y += root_ctrl.size.y * thin_scanline_step
	if _thin_scan_y > root_ctrl.size.y:
		_thin_scan_y = -_thin_scanline.size.y

	_third_scan_y += root_ctrl.size.y * third_scanline_step
	if _third_scan_y > root_ctrl.size.y:
		_third_scan_y = -_third_scanline.size.y

	_apply_scanline()


func _randomize_scanlines() -> void:
	var h: float = maxf(root_ctrl.size.y, 1.0)
	_scan_y = randf_range(-scanline.size.y, h)
	_thin_scan_y = randf_range(-_thin_scanline.size.y, h)
	_third_scan_y = randf_range(-_third_scanline.size.y, h)
	_apply_scanline()


func _apply_scanline() -> void:
	scanline.position.y = _scan_y
	if _thin_scanline and is_instance_valid(_thin_scanline):
		_thin_scanline.position.y = _thin_scan_y
	if _third_scanline and is_instance_valid(_third_scanline):
		_third_scanline.position.y = _third_scanline.size.y * 0.0 + _third_scan_y


func _select_cam(index: int) -> void:
	if _input_blocked or _state != State.ACTIVE or index == _current_cam:
		return
	if _switching_cam:
		if not _lost_signal_active:
			return
		_play_audio(_camera_select_audio)
		_current_cam = index
		_music_box_winding = false
		_clamp_current_cam()
		_sync_buttons()
		_refresh_label()
		_update_music_box_controls()
		_update_static()
		_randomize_scanlines()
		_render_cam()
		return
	_play_audio(_camera_select_audio)
	_switching_cam = true
	_current_cam = index
	_music_box_winding = false
	_update_music_box_controls()
	_clamp_current_cam()
	_sync_buttons()
	_refresh_label()

	_ensure_pending_overlay()
	_pending_overlay.visible = true

	await get_tree().create_timer(0.25).timeout

	_update_static()
	_randomize_scanlines()
	_render_cam()

	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false
	_switching_cam = false
	_update_music_box_controls()


func _sync_buttons() -> void:
	for i in range(_cam_buttons.size()):
		_cam_buttons[i].set_pressed_no_signal(i == _current_cam)
	_update_cam_button_opacities()


func _refresh_label() -> void:
	cam_label.text = _get_cam_translation_key(_current_cam)
	cam_label.visible = true
	if auto_layout:
		var margin: float = 24.0
		var lbl_size: Vector2 = cam_label.get_combined_minimum_size().max(Vector2(120.0, 28.0))
		cam_label.offset_right = margin + lbl_size.x
		cam_label.offset_bottom = margin + lbl_size.y


func _get_overlay_color() -> Color:
	var c := overlay_color_override
	if c.a <= 0.0:
		c = _hitbox.get_on_color()
	c.a = 1.0
	return c


func _set_cursor(on: bool) -> void:
	if _input_blocked:
		return
	if on:
		Input.set_custom_mouse_cursor(CURSOR_ARROW, Input.CURSOR_ARROW, Vector2.ZERO)
		Input.set_custom_mouse_cursor(CURSOR_HAND, Input.CURSOR_POINTING_HAND, hand_hotspot)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	if blocked:
		_music_box_winding = false
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for b: Button in _cam_buttons:
			if b and is_instance_valid(b):
				b.disabled = true
				b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c: Control in [_btn_play_sound, _music_box_wind_button, _music_box_change_button]:
			if c and is_instance_valid(c):
				if c is BaseButton:
					(c as BaseButton).disabled = true
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _hitbox and is_instance_valid(_hitbox):
			_hitbox.set_deferred("monitoring", false)
			_hitbox.set_deferred("monitorable", false)
			_hitbox.input_ray_pickable = false


func lock_cams(reason: String) -> void:
	_cam_locks[reason] = true


func unlock_cams(reason: String) -> void:
	_cam_locks.erase(reason)


func are_cams_locked() -> bool:
	return not _cam_locks.is_empty()


func is_camera_feed_active() -> bool:
	return _state == State.ACTIVE


func get_current_camera_index() -> int:
	return _current_cam


func get_current_camera_transform() -> Transform3D:
	_clamp_current_cam()
	if _current_cam >= 0 and _current_cam < _cam_points.size():
		var point := _cam_points[_current_cam]
		if point and is_instance_valid(point):
			return point.global_transform
	return Transform3D.IDENTITY


func is_music_box_winding() -> bool:
	return not _input_blocked and _music_box_winding and _music_box_enabled and not _music_box_late_active and _state == State.ACTIVE and _current_cam == 10


func set_music_box_alt_active(value: bool) -> void:
	_music_box_alt_active = value
	_music_box_beat_left = _get_music_box_beat_interval()
	_change_btn_beat_left = _get_music_box_beat_interval()
	_update_music_box_warning()


func set_song_request_state(active: bool, progress: float = 0.0) -> void:
	var was_active := _song_request_active
	_song_request_active = active
	_song_request_progress = clampf(progress, 0.0, 1.0)
	if active and not was_active:
		_change_btn_beat_left = _get_music_box_beat_interval()
		_music_box_beat_left = _get_music_box_beat_interval()
		_music_box_request_beat_left = _get_music_box_beat_interval()
		_music_box_request_beat_sign = 1.0
		_change_btn_yellow = true
	elif not active:
		_change_btn_yellow = false
		_change_btn_beat_left = 0.0
		_music_box_request_beat_left = 0.0
	_update_request_bar()
	_update_change_button_tint()
	_update_music_box_warning()


func _update_request_bar() -> void:
	if not _request_bar_bg or not is_instance_valid(_request_bar_bg) or not _request_bar_fill or not is_instance_valid(_request_bar_fill):
		return
	var show_bar := _song_request_active and _music_box_enabled and not _music_box_late_active and _state == State.ACTIVE and not _switching_cam and _current_cam == 10
	_request_bar_bg.visible = show_bar
	if not show_bar:
		return
	var total_w := _request_bar_bg.size.x
	var fill_w := total_w * _song_request_progress
	_request_bar_fill.size.x = fill_w
	_request_bar_fill.position.x = total_w - fill_w
	_request_bar_fill.color = _get_music_box_request_bar_color()

func _get_music_box_request_bar_color() -> Color:
	var green := Color(0.0, 1.0, 0.0, 1.0)
	var yellow := Color(1.0, 0.88, 0.12, 1.0)
	var red := Color(1.0, 0.04, 0.02, 1.0)
	if _song_request_progress >= 0.77:
		return green
	if _song_request_progress >= 0.33:
		var yellow_t := clampf((0.77 - _song_request_progress) / (0.77 - 0.33), 0.0, 1.0)
		return green.lerp(yellow, yellow_t)
	if _song_request_progress >= 0.16:
		var red_t := clampf((0.33 - _song_request_progress) / (0.33 - 0.16), 0.0, 1.0)
		return yellow.lerp(red, red_t)
	return red



func _process_change_button_beat(delta: float) -> void:
	if not _music_box_change_button or not is_instance_valid(_music_box_change_button):
		return
	if not _song_request_active or _music_box_late_active or not _music_box_enabled:
		if _change_btn_yellow:
			_change_btn_yellow = false
			_update_change_button_tint()
		return
	if _change_btn_beat_left <= 0.0:
		_change_btn_beat_left = _get_music_box_beat_interval()
	_change_btn_beat_left -= delta
	if _change_btn_beat_left <= 0.0:
		_change_btn_beat_left = _get_music_box_beat_interval()
		_change_btn_yellow = not _change_btn_yellow
		_update_change_button_tint()


func _update_change_button_tint() -> void:
	if not _music_box_change_button or not is_instance_valid(_music_box_change_button):
		return
	if _song_request_active and _change_btn_yellow:
		_music_box_change_button.modulate = Color(1.0, 0.88, 0.12, 1.0)
	else:
		_music_box_change_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func set_music_box_enabled(value: bool, hide_immediately: bool = false) -> void:
	if _music_box_enabled == value:
		_update_music_box_controls()
		return
	_music_box_enabled = value
	_music_box_winding = false
	if not value:
		_song_request_active = false
		_change_btn_yellow = false
		_music_box_request_beat_left = 0.0
	if value:
		_update_music_box_controls()
		return
	if _music_box_opacity_tween and _music_box_opacity_tween.is_valid():
		_music_box_opacity_tween.kill()
	if hide_immediately:
		for control: Control in [_music_box_wind_button, _music_box_change_button, _music_box_bar_bg, _request_bar_bg]:
			if control and is_instance_valid(control):
				control.visible = false
				control.modulate.a = 1.0
		_update_music_box_warning()
		return
	_music_box_opacity_tween = create_tween()
	_music_box_opacity_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for control: Control in [_music_box_wind_button, _music_box_change_button, _music_box_bar_bg, _request_bar_bg]:
		if control and is_instance_valid(control):
			control.visible = true
			_music_box_opacity_tween.parallel().tween_property(control, "modulate:a", 0.0, 0.18)
	_update_music_box_warning()
	_music_box_opacity_tween.finished.connect(func() -> void:
		for control: Control in [_music_box_wind_button, _music_box_change_button, _music_box_bar_bg, _request_bar_bg]:
			if control and is_instance_valid(control):
				control.visible = false
	)

func set_music_box_late_active(value: bool) -> void:
	if _music_box_late_active == value:
		return
	_music_box_late_active = value
	if value:
		_song_request_active = false
		_change_btn_yellow = false
	_music_box_beat_left = _get_music_box_beat_interval()
	_layout_music_box_controls()
	_update_music_box_controls()
	_update_music_box_warning()


func set_music_box_charge(value: float) -> void:
	_music_box_charge = clampf(value, 0.0, 1.0)
	if not _music_box_late_active and _music_box_charge >= 0.33:
		_music_box_danger_beat_count = 0
		if not _song_request_active:
			_music_box_beat_left = 0.0
		var danger_player := _get_universal_player(_danger_audio)
		if danger_player and danger_player.playing:
			danger_player.stop()
	if not _music_box_bar_bg or not is_instance_valid(_music_box_bar_bg):
		return
	var width := _music_box_bar_bg.size.x * _music_box_charge
	_music_box_bar_fill.position.x = 0.0
	_music_box_bar_fill.size.x = width
	var red_t := 0.0
	if _music_box_charge <= 0.16:
		red_t = 1.0
	elif _music_box_charge < 0.33:
		red_t = clampf((0.33 - _music_box_charge) / (0.33 - 0.16), 0.0, 1.0)
	_music_box_bar_fill.color = Color.WHITE.lerp(Color(1.0, 0.04, 0.02, 1.0), red_t)
	_update_music_box_warning()


func _ensure_music_box_controls() -> void:
	var wind_size := maxf(wind_music_box_button_size, 1.0)
	var change_size := maxf(change_music_button_size, 1.0)
	if _music_box_wind_button and is_instance_valid(_music_box_wind_button):
		_configure_square_icon_button(_music_box_wind_button, MUSIC_ICON_TEX, wind_size)
		if _music_box_change_button and is_instance_valid(_music_box_change_button):
			_configure_square_icon_button(_music_box_change_button, MUSIC_CHANGE_ICON_TEX, change_size)
		_ensure_change_request_audio()
		return
	_music_box_bar_bg = ColorRect.new()
	_music_box_bar_bg.name = "MusicBoxChargeBar"
	_music_box_bar_bg.color = Color(1.0, 1.0, 1.0, 0.12)
	_music_box_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_bar_bg.z_index = 24
	root_ctrl.add_child(_music_box_bar_bg)

	_music_box_bar_fill = ColorRect.new()
	_music_box_bar_fill.name = "MusicBoxChargeFill"
	_music_box_bar_fill.color = Color.WHITE
	_music_box_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_bar_bg.add_child(_music_box_bar_fill)

	_request_bar_bg = ColorRect.new()
	_request_bar_bg.name = "MusicBoxRequestBar"
	_request_bar_bg.color = Color(1.0, 1.0, 1.0, 0.18)
	_request_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_request_bar_bg.z_index = 25
	_request_bar_bg.visible = false
	root_ctrl.add_child(_request_bar_bg)

	_request_bar_fill = ColorRect.new()
	_request_bar_fill.name = "MusicBoxRequestFill"
	_request_bar_fill.color = Color.WHITE
	_request_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_request_bar_bg.add_child(_request_bar_fill)

	_music_box_wind_button = Button.new()
	_music_box_wind_button.name = "BtnWindMusicBox"
	_music_box_wind_button.z_index = 40
	_configure_square_icon_button(_music_box_wind_button, MUSIC_ICON_TEX, wind_size)
	root_ctrl.add_child(_music_box_wind_button)

	_music_box_change_button = Button.new()
	_music_box_change_button.name = "BtnChangeMusicBox"
	_music_box_change_button.z_index = 40
	_configure_square_icon_button(_music_box_change_button, MUSIC_CHANGE_ICON_TEX, change_size)
	_music_box_change_button.pressed.connect(_on_change_music_pressed)
	root_ctrl.add_child(_music_box_change_button)

	_music_box_caution = TextureRect.new()
	_music_box_caution.name = "MusicBoxCaution"
	_music_box_caution.texture = MUSIC_BOX_CAUTION_TEXTURE
	_music_box_caution.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_music_box_caution.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_box_caution.custom_minimum_size = Vector2(small_charge_caution_size, small_charge_caution_size)
	_music_box_caution.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_caution.pivot_offset = Vector2(small_charge_caution_size * 0.5, small_charge_caution_size * 0.5)
	_music_box_caution.z_index = 25
	_music_box_caution.visible = true
	_music_box_caution.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root_ctrl.add_child(_music_box_caution)

	_music_box_caution_late = TextureRect.new()
	_music_box_caution_late.name = "MusicBoxCautionLate"
	_music_box_caution_late.texture = MUSIC_BOX_CAUTION_TEXTURE
	_music_box_caution_late.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_music_box_caution_late.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_box_caution_late.custom_minimum_size = Vector2(large_charge_caution_size, large_charge_caution_size)
	_music_box_caution_late.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_caution_late.pivot_offset = Vector2(large_charge_caution_size * 0.5, large_charge_caution_size * 0.5)
	_music_box_caution_late.z_index = 25
	_music_box_caution_late.visible = true
	_music_box_caution_late.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root_ctrl.add_child(_music_box_caution_late)

	_music_box_request_caution = TextureRect.new()
	_music_box_request_caution.name = "MusicBoxRequestCaution"
	_music_box_request_caution.texture = MUSIC_BOX_CAUTION_TEXTURE
	_music_box_request_caution.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_music_box_request_caution.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_box_request_caution.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_request_caution.z_index = 30
	_music_box_request_caution.visible = true
	_music_box_request_caution.modulate = Color.WHITE
	_music_box_request_caution.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	root_ctrl.add_child(_music_box_request_caution)

	_music_box_request_caution_debug = TextureRect.new()
	_music_box_request_caution_debug.name = "MusicBoxRequestCautionDebug"
	_music_box_request_caution_debug.texture = MUSIC_BOX_CAUTION_TEXTURE
	_music_box_request_caution_debug.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_music_box_request_caution_debug.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_box_request_caution_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_request_caution_debug.z_index = 30
	_music_box_request_caution_debug.visible = true
	_music_box_request_caution_debug.modulate = Color.WHITE
	_music_box_request_caution_debug.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	root_ctrl.add_child(_music_box_request_caution_debug)

	_ensure_change_request_audio()
	_layout_music_box_controls()
	_update_music_box_controls()
	set_music_box_charge(_music_box_charge)
	_update_request_bar()
	_raise_all_buttons_above_pending()

func _ensure_change_request_audio() -> void:
	if _change_request_audio and is_instance_valid(_change_request_audio):
		return
	_change_request_audio = get_node_or_null("ChangeRequest") as AudioStreamPlayer2D
	if not _change_request_audio:
		_change_request_audio = AudioStreamPlayer2D.new()
		_change_request_audio.name = "ChangeRequest"
		add_child(_change_request_audio)
	_change_request_audio.stream = CHANGE_REQUEST_SOUND
	_change_request_audio.bus = "Master"
	_change_request_audio.volume_db = AudioSettings.CAMERA_CHANGE_REQUEST_DB
	_change_request_audio.position = Vector2.ZERO


func _play_change_request_audio() -> void:
	_ensure_change_request_audio()
	if not _change_request_audio or not is_instance_valid(_change_request_audio):
		return
	if _change_request_audio.playing:
		_change_request_audio.stop()
	_change_request_audio.play()

func _on_change_music_pressed() -> void:
	if _input_blocked or not _music_box_enabled or _music_box_late_active or _state != State.ACTIVE or _current_cam != 10:
		return
	_play_audio(_click_audio)
	music_change_requested.emit()


func _layout_music_box_controls() -> void:
	if _music_box_wind_button and is_instance_valid(_music_box_wind_button):
		var wind_size := maxf(wind_music_box_button_size, 1.0)
		_configure_square_icon_button(_music_box_wind_button, MUSIC_ICON_TEX, wind_size)
		_music_box_wind_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
		_music_box_wind_button.offset_left = wind_music_box_button_left
		_music_box_wind_button.offset_right = wind_music_box_button_left + wind_size
		_music_box_wind_button.offset_bottom = -wind_music_box_button_bottom
		_music_box_wind_button.offset_top = -wind_music_box_button_bottom - wind_size
	if _music_box_change_button and is_instance_valid(_music_box_change_button):
		var change_size := maxf(change_music_button_size, 1.0)
		_configure_square_icon_button(_music_box_change_button, MUSIC_CHANGE_ICON_TEX, change_size)
		_music_box_change_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
		_music_box_change_button.offset_left = change_music_button_left
		_music_box_change_button.offset_right = change_music_button_left + change_size
		_music_box_change_button.offset_bottom = -change_music_button_bottom
		_music_box_change_button.offset_top = -change_music_button_bottom - change_size
	if _music_box_bar_bg and is_instance_valid(_music_box_bar_bg):
		_music_box_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_music_box_bar_bg.offset_left = 0.0
		_music_box_bar_bg.offset_right = 0.0
		_music_box_bar_bg.offset_top = -6.0
		_music_box_bar_bg.offset_bottom = 0.0
		_music_box_bar_fill.position.y = 0.0
		_music_box_bar_fill.size.y = _music_box_bar_bg.size.y
	if _request_bar_bg and is_instance_valid(_request_bar_bg):
		_request_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_request_bar_bg.offset_left = 0.0
		_request_bar_bg.offset_right = 0.0
		_request_bar_bg.offset_top = -12.0
		_request_bar_bg.offset_bottom = -6.0
		_request_bar_fill.position.y = 0.0
		_request_bar_fill.size.y = _request_bar_bg.size.y
	_layout_music_box_request_caution()
	_update_request_bar()


func _layout_music_box_request_caution() -> void:
	_layout_music_box_caution(_music_box_caution, small_charge_caution_size, small_charge_caution_left, small_charge_caution_bottom)
	var late_caution_left := late_70_bpm_caution_left if _music_box_late_active else large_charge_caution_left
	var late_caution_bottom := late_70_bpm_caution_bottom if _music_box_late_active else large_charge_caution_bottom
	_layout_music_box_caution(_music_box_caution_late, large_charge_caution_size, late_caution_left, late_caution_bottom)
	var is_cam11 := _current_cam == 10
	if is_cam11:
		_layout_music_box_caution(_music_box_request_caution, small_request_caution_size, small_request_caution_left, small_request_caution_bottom)
		_layout_music_box_caution(_music_box_request_caution_debug, large_request_caution_size, large_request_caution_left, large_request_caution_bottom)
	else:
		_layout_music_box_caution(_music_box_request_caution, large_request_caution_size, large_request_caution_left, large_request_caution_bottom)
		_layout_music_box_caution(_music_box_request_caution_debug, small_request_caution_size, small_request_caution_left, small_request_caution_bottom)

func _layout_music_box_caution(icon: TextureRect, icon_size: float, left: float, bottom: float) -> void:
	if not icon or not is_instance_valid(icon):
		return
	var safe_size := maxf(icon_size, 1.0)
	_layout_caution_icon(icon, safe_size, Vector2(0.0, 1.0), Vector2(left, -bottom - safe_size))

func _layout_caution_icon(icon: TextureRect, icon_size: float, anchor: Vector2, offset: Vector2) -> void:
	if not icon or not is_instance_valid(icon):
		return
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.pivot_offset = Vector2(icon_size * 0.5, icon_size * 0.5)
	icon.anchor_left = anchor.x
	icon.anchor_right = anchor.x
	icon.anchor_top = anchor.y
	icon.anchor_bottom = anchor.y
	icon.offset_left = offset.x
	icon.offset_right = offset.x + icon_size
	icon.offset_top = offset.y
	icon.offset_bottom = offset.y + icon_size


func _update_music_box_controls() -> void:
	if not _music_box_wind_button or not is_instance_valid(_music_box_wind_button):
		return
	var is_cam11 := _music_box_enabled and _state == State.ACTIVE and _current_cam == 10 and not _music_box_late_active
	_music_box_wind_button.visible = is_cam11
	_music_box_bar_bg.visible = is_cam11
	if _music_box_change_button and is_instance_valid(_music_box_change_button):
		_music_box_change_button.visible = is_cam11
	if not is_cam11:
		_music_box_winding = false
	_update_request_bar()
	_update_change_button_tint()
	_update_music_box_warning()
	set_music_box_charge(_music_box_charge)
	_raise_all_buttons_above_pending()


func _get_active_music_bpm() -> float:
	if _music_box_late_active:
		return 70.0
	return maxf(music_box_alt_bpm if _music_box_alt_active else music_box_bpm, 1.0)


func _get_music_box_beat_interval() -> float:
	return 60.0 / _get_active_music_bpm()


func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled
	_update_music_box_warning()


func _update_music_box_warning() -> void:
	if not _music_box_caution or not is_instance_valid(_music_box_caution) or not _music_box_caution_late or not is_instance_valid(_music_box_caution_late) or not _music_box_request_caution or not is_instance_valid(_music_box_request_caution) or not _music_box_request_caution_debug or not is_instance_valid(_music_box_request_caution_debug):
		return
	var camera_visible := _state == State.ACTIVE
	var warning_active := _music_box_enabled and _music_box_charge > 0.0 and _music_box_charge <= 0.33
	var should_show := _debug_mode or (camera_visible and _current_cam == 10 and not _music_box_late_active and warning_active)
	_layout_music_box_request_caution()
	_music_box_caution.visible = true
	if should_show != _music_box_warning_target:
		_music_box_warning_target = should_show
		if _music_box_warning_tween and _music_box_warning_tween.is_valid():
			_music_box_warning_tween.kill()
		_music_box_warning_tween = create_tween()
		_music_box_warning_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_box_warning_tween.tween_property(_music_box_caution, "modulate:a", 1.0 if should_show else 0.0, 0.22)
	var should_show_late := _debug_mode or (camera_visible and (_music_box_late_active or (warning_active and _current_cam != 10)))
	_music_box_caution_late.visible = true
	if should_show_late != _music_box_warning_late_target:
		_music_box_warning_late_target = should_show_late
		if _music_box_warning_late_tween and _music_box_warning_late_tween.is_valid():
			_music_box_warning_late_tween.kill()
		_music_box_warning_late_tween = create_tween()
		_music_box_warning_late_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_box_warning_late_tween.tween_property(_music_box_caution_late, "modulate:a", 1.0 if should_show_late else 0.0, 0.22)
	var request_active := _debug_mode or (camera_visible and _song_request_active and _music_box_enabled and not _music_box_late_active)
	_music_box_request_caution.visible = true
	if request_active != _music_box_request_caution_target:
		_music_box_request_caution_target = request_active
		if _music_box_request_caution_visibility_tween and _music_box_request_caution_visibility_tween.is_valid():
			_music_box_request_caution_visibility_tween.kill()
		_music_box_request_caution_visibility_tween = create_tween()
		_music_box_request_caution_visibility_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_box_request_caution_visibility_tween.tween_property(_music_box_request_caution, "self_modulate:a", 1.0 if request_active else 0.0, 0.22)
	_music_box_request_caution_debug.visible = true
	_music_box_request_caution_debug.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if _debug_mode else 0.0)

func _process_music_box_warning(delta: float) -> void:
	_process_music_box_request_caution(delta)
	_process_standard_music_box_warning(delta)


func _process_music_box_request_caution(delta: float) -> void:
	var camera_system_open := _state == State.OPENING or _state == State.ACTIVE or _state == State.CLOSING
	var request_active := _debug_mode or (_song_request_active and _music_box_enabled and not _music_box_late_active and camera_system_open)
	if not request_active:
		_music_box_request_beat_left = 0.0
		return
	if _music_box_request_beat_sign < 0.0:
		var alternate_color := _get_music_box_request_bar_color()
		if _music_box_request_caution and is_instance_valid(_music_box_request_caution):
			_music_box_request_caution.modulate = alternate_color
		if _debug_mode and _music_box_request_caution_debug and is_instance_valid(_music_box_request_caution_debug):
			_music_box_request_caution_debug.modulate = alternate_color
	if _music_box_request_beat_left <= 0.0:
		_music_box_request_beat_left = _get_music_box_beat_interval()
	_music_box_request_beat_left -= delta
	if _music_box_request_beat_left > 0.0:
		return
	_music_box_request_beat_left = _get_music_box_beat_interval()
	_music_box_request_beat_sign *= -1.0
	_play_change_request_audio()
	_animate_request_caution_icon(_music_box_request_caution, false)
	if _debug_mode:
		_animate_request_caution_icon(_music_box_request_caution_debug, true)


func _animate_request_caution_icon(icon: TextureRect, debug_copy: bool) -> void:
	if not icon or not is_instance_valid(icon):
		return
	var active_tween: Tween = _music_box_request_caution_debug_tween if debug_copy else _music_box_request_caution_tween
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	var alternate_color := _get_music_box_request_bar_color()
	icon.modulate = Color.WHITE if _music_box_request_beat_sign > 0.0 else alternate_color
	icon.rotation = 0.0
	icon.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "rotation", _music_box_request_beat_sign * 0.18, 0.08)
	tween.parallel().tween_property(icon, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(icon, "rotation", 0.0, 0.16)
	tween.parallel().tween_property(icon, "scale", Vector2.ONE, 0.16)
	if debug_copy:
		_music_box_request_caution_debug_tween = tween
	else:
		_music_box_request_caution_tween = tween


func _process_standard_music_box_warning(delta: float) -> void:
	var late_icon_visible := _music_box_caution_late and _music_box_caution_late.modulate.a > 0.01
	var normal_icon_visible := _music_box_caution and _music_box_caution.modulate.a > 0.01
	var animated_icon := _music_box_caution_late if late_icon_visible else _music_box_caution
	var any_caution_active := _debug_mode or (_state == State.ACTIVE and (late_icon_visible or normal_icon_visible))
	if not any_caution_active:
		_music_box_danger_beat_count = 0
		_music_box_beat_left = 0.0
		return
	if _music_box_beat_left <= 0.0:
		_music_box_beat_left = _get_music_box_beat_interval()
	if not _debug_mode and (not animated_icon or animated_icon.modulate.a <= 0.0 or (not _music_box_late_active and (_music_box_charge > 0.33 or _music_box_charge <= 0.0))):
		return
	_music_box_beat_left -= delta
	if _music_box_beat_left > 0.0:
		return
	_music_box_beat_left = _get_music_box_beat_interval()
	_music_box_beat_sign *= -1.0
	_music_box_danger_beat_count += 1
	if _music_box_danger_beat_count % 2 == 1:
		_play_audio(_danger_audio)
	var danger_t := clampf(1.0 - (_music_box_charge / 0.33), 0.0, 1.0) if not _music_box_late_active else 1.0
	var yellow_color := Color(1.0, 0.88, 0.12, 1.0)
	var red_color := Color(1.0, 0.04, 0.02, 1.0)
	var alt_color := yellow_color.lerp(red_color, danger_t)
	var caution_icons: Array[TextureRect] = []
	if _debug_mode:
		caution_icons.append(_music_box_caution)
		caution_icons.append(_music_box_caution_late)
	else:
		caution_icons.append(animated_icon)
	for icon: TextureRect in caution_icons:
		if not icon or not is_instance_valid(icon) or icon.modulate.a <= 0.0:
			continue
		var animation_tween: Tween = _music_box_caution_late_animation_tween if icon == _music_box_caution_late else _music_box_caution_tween
		if animation_tween and animation_tween.is_valid():
			animation_tween.kill()
		var caution_alpha := icon.modulate.a
		icon.modulate = Color(1.0, 1.0, 1.0, caution_alpha) if _music_box_beat_sign > 0.0 else Color(alt_color.r, alt_color.g, alt_color.b, caution_alpha)
		icon.rotation = 0.0
		icon.scale = Vector2.ONE
		var beat_scale := 1.6 if (_debug_mode and icon == _music_box_caution_late) or _music_box_late_active else 1.2
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "rotation", _music_box_beat_sign * 0.18, 0.08)
		tween.parallel().tween_property(icon, "scale", Vector2(beat_scale, beat_scale), 0.08)
		tween.tween_property(icon, "rotation", 0.0, 0.16)
		tween.parallel().tween_property(icon, "scale", Vector2.ONE, 0.16)
		if icon == _music_box_caution_late:
			_music_box_caution_late_animation_tween = tween
		else:
			_music_box_caution_tween = tween

func _update_music_box_winding_from_mouse() -> void:
	var can_wind := (
		not _input_blocked
		and _music_box_enabled
		and not _music_box_late_active
		and _state == State.ACTIVE
		and _current_cam == 10
		and _music_box_wind_button != null
		and is_instance_valid(_music_box_wind_button)
		and _music_box_wind_button.visible
		and not _music_box_wind_button.disabled
	)
	_music_box_winding = (
		can_wind
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and _music_box_wind_button.get_global_rect().has_point(_music_box_wind_button.get_global_mouse_position())
	)


func _ensure_winding_audio_player() -> void:
	_winding_audio_player = AudioStreamPlayer.new()
	_winding_audio_player.name = "Winding"
	_winding_audio_player.stream = WINDING_SOUND
	_winding_audio_player.volume_db = AudioSettings.WINDING_DB
	_winding_audio_player.pitch_scale = AudioSettings.WINDING_PITCH_SCALE
	add_child(_winding_audio_player)


func _process_winding_audio(delta: float) -> void:
	if not is_music_box_winding():
		if _winding_audio_player and _winding_audio_player.playing:
			_winding_audio_player.stop()
		_winding_audio_active = false
		_winding_audio_beat_left = 0.0
		return

	if not _winding_audio_player or not is_instance_valid(_winding_audio_player):
		return
	if not _winding_audio_active:
		_winding_audio_active = true
		_winding_audio_beat_left = _get_music_box_beat_interval()
		_winding_audio_player.play()
		return

	_winding_audio_beat_left -= delta
	if _winding_audio_beat_left <= 0.0:
		_winding_audio_beat_left += _get_music_box_beat_interval()
		_winding_audio_player.play()


func is_open() -> bool:
	return _state != State.IDLE


func interrupt_for_jumpscare() -> void:
	_jumpscare_interrupted = true
	_mobile_exit_suppressed_for_jumpscare = true
	_state = State.IDLE
	_switching_cam = false
	_mobile_hide_exit_mode = false
	_music_box_winding = false
	_song_request_active = false
	_change_btn_yellow = false
	visible = false
	_update_mobile_exit_button()
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_set_cursor(false)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.set_in_use(false)


func hide_mobile_exit_button() -> void:
	_mobile_exit_suppressed_for_jumpscare = true
	_mobile_hide_exit_mode = false
	if _mobile_exit_button and is_instance_valid(_mobile_exit_button):
		_mobile_exit_button.hide()
	_update_mobile_exit_button()


func force_close() -> void:
	if _state == State.ACTIVE:
		_switching_cam = false
		_close_ui()
	elif _state == State.ZOOMING_IN or _state == State.OPENING:
		_close_requested = true


func _ensure_play_sound_button() -> void:
	var button_size := maxf(play_audio_button_size, 1.0)
	if _btn_play_sound and is_instance_valid(_btn_play_sound):
		_configure_square_icon_button(_btn_play_sound, AUDIO_ICON_TEX, button_size)
		_ensure_audio_wave_effect()
		return
	_btn_play_sound = Button.new()
	_btn_play_sound.name = "BtnPlaySound"
	_btn_play_sound.z_index = 40
	_configure_square_icon_button(_btn_play_sound, AUDIO_ICON_TEX, button_size)
	_btn_play_sound.pressed.connect(_on_play_sound_pressed)
	root_ctrl.add_child(_btn_play_sound)
	_ensure_audio_wave_effect()
	_update_play_sound_button()
	_raise_all_buttons_above_pending()

func _ensure_audio_wave_effect() -> void:
	if _audio_wave_effect and is_instance_valid(_audio_wave_effect):
		return
	_audio_wave_effect = Control.new()
	_audio_wave_effect.name = "AudioWaveEffect"
	_audio_wave_effect.set_script(AUDIO_WAVE_EFFECT_SCRIPT)
	_audio_wave_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio_wave_effect.z_index = 30
	root_ctrl.add_child(_audio_wave_effect)
	_audio_wave_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _layout_play_sound_button() -> void:
	if not _btn_play_sound or not is_instance_valid(_btn_play_sound):
		return
	var button_size := maxf(play_audio_button_size, 1.0)
	_configure_square_icon_button(_btn_play_sound, AUDIO_ICON_TEX, button_size)
	_btn_play_sound.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_btn_play_sound.offset_left = play_audio_button_left
	_btn_play_sound.offset_right = play_audio_button_left + button_size
	_btn_play_sound.offset_bottom = -play_audio_button_bottom
	_btn_play_sound.offset_top = -play_audio_button_bottom - button_size

func _update_play_sound_button() -> void:
	if not _btn_play_sound or not is_instance_valid(_btn_play_sound):
		return
	var cooling: bool = _play_cooldown_left > 0.0
	_btn_play_sound.visible = (_state == State.ACTIVE or _state == State.CLOSING) and not _input_blocked
	_btn_play_sound.z_index = 40
	_btn_play_sound.disabled = cooling or _input_blocked
	_btn_play_sound.modulate.a = 0.6 if cooling else 1.0
	_btn_play_sound.mouse_default_cursor_shape = Control.CURSOR_ARROW if cooling or _input_blocked else Control.CURSOR_POINTING_HAND


func _on_play_sound_pressed() -> void:
	if _input_blocked or _state != State.ACTIVE or (_switching_cam and not _lost_signal_active) or _play_cooldown_left > 0.0:
		return
	_play_audio(_click_audio)
	_ensure_audio_wave_effect()
	var wave_origin := _btn_play_sound.position + Vector2(_btn_play_sound.size.x + 8.0, _btn_play_sound.size.y * 0.5)
	_audio_wave_effect.call("play_wave", wave_origin)
	_play_cooldown_left = play_sound_cooldown
	_update_play_sound_button()
	lure_requested.emit(_current_cam)


func play_lost_signal(move_callable: Callable, duration_multiplier: float = 1.0) -> void:
	while _switching_cam and _state == State.ACTIVE:
		await get_tree().process_frame

	if _state != State.ACTIVE:
		await move_callable.call()
		await get_tree().process_frame
		lost_signal_finished.emit()
		return

	_switching_cam = true
	_lost_signal_active = true
	_set_transition_controls_behind(true)
	_ensure_pending_overlay()
	_pending_label.text = lost_signal_translation_key
	_pending_overlay.visible = true
	_raise_all_buttons_above_pending()
	_show_play_sound_during_lost_signal()
	_play_audio(_lost_signal_audio)
	await get_tree().process_frame
	move_callable.call()

	var transition_multiplier := maxf(duration_multiplier, 1.0)
	await get_tree().create_timer(lost_signal_time * transition_multiplier).timeout
	if _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key
	_show_play_sound_during_lost_signal()
	_play_audio(_after_lost_audio)
	await get_tree().create_timer(pending_after_lost_time * transition_multiplier).timeout

	if _state == State.ACTIVE:
		_update_static()
		_randomize_scanlines()
		_render_cam()
	if _pending_overlay and is_instance_valid(_pending_overlay) and _state != State.CLOSING:
		_pending_overlay.visible = false
	_lost_signal_active = false
	_switching_cam = false
	_set_transition_controls_behind(false)
	if _state == State.ACTIVE:
		_update_music_box_controls()
	lost_signal_finished.emit()


func _show_play_sound_during_lost_signal() -> void:
	if not _btn_play_sound or not is_instance_valid(_btn_play_sound):
		return
	if _state != State.ACTIVE or _input_blocked:
		return
	_btn_play_sound.visible = true
	_btn_play_sound.z_index = 60
	if _btn_play_sound.get_parent() == root_ctrl:
		root_ctrl.move_child(_btn_play_sound, root_ctrl.get_child_count() - 1)


func _start_monitor_glow() -> void:
	var glow_player := _get_universal_player(_monitor_glow_audio)
	if not glow_player or not is_instance_valid(glow_player):
		return
	glow_player.volume_db = AudioSettings.MUTED_DB
	if glow_player.stream != null and not glow_player.playing:
		glow_player.play()


func _on_monitor_hover_changed(is_hovering: bool) -> void:
	if _input_blocked:
		return
	var glow_player := _get_universal_player(_monitor_glow_audio)
	if not glow_player or not is_instance_valid(glow_player):
		return
	if _monitor_glow_tween and _monitor_glow_tween.is_valid():
		_monitor_glow_tween.kill()
	if glow_player.stream != null and not glow_player.playing:
		glow_player.play()
	_monitor_glow_tween = create_tween()
	_monitor_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target_db := AudioSettings.MONITOR_GLOW_MAX_DB if is_hovering else AudioSettings.MUTED_DB
	var fade_time := monitor_glow_fade_in_time if is_hovering else monitor_glow_fade_out_time
	_monitor_glow_tween.tween_property(glow_player, "volume_db", target_db, fade_time)


func _play_audio(source_3d: AudioStreamPlayer3D) -> void:
	var player := _get_universal_player(source_3d)
	if not player or not is_instance_valid(player) or player.stream == null:
		return
	player.stop()
	if source_3d == _lost_signal_audio:
		player.pitch_scale = randf_range(0.80, 1.20)
	player.play()


func _play_monitor_open_audio() -> void:
	var open_player := _get_universal_player(_monitor_open_audio)
	if not open_player or not is_instance_valid(open_player) or open_player.stream == null:
		return
	if _monitor_open_fade_tween and _monitor_open_fade_tween.is_valid():
		_monitor_open_fade_tween.kill()
	open_player.stop()
	open_player.volume_db = AudioSettings.MONITOR_OPEN_DB
	open_player.play()
	_monitor_open_fade_tween = create_tween()
	_monitor_open_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_monitor_open_fade_tween.tween_interval(0.6)
	_monitor_open_fade_tween.tween_property(open_player, "volume_db", AudioSettings.MUTED_DB, 2.0)
