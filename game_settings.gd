extends Node

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_OPTIONS := ["default", "medium", "low", "potato", "dipshit", "i respect that"]
const FPS_OPTIONS := ["vsync (default)", "30", "60", "120", "240", "uncapped"]
const FPS_LIMITS := [-1, 30, 60, 120, 240, 0]
const CAMERA_DEFAULT_SHRINK := 5.0
const CAMERA_SHRINK_PER_QUALITY_STEP := 0.5
const QUALITY_SHRINK := {
	"default": 3,
	"medium": 4,
	"low": 5,
	"potato": 6,
	"dipshit": 7,
	"i respect that": 8,
}
const QUALITY_SCALE := {
	"default": 1.0,
	"medium": 0.88,
	"low": 0.81,
	"potato": 0.74,
	"dipshit": 0.67,
	"i respect that": 0.60,
}
const QUALITY_SHADOW_ATLAS := {
	"medium": 2048,
	"low": 1024,
	"potato": 512,
	"dipshit": 256,
	"i respect that": 256,
}

var quality: String = "default"
var max_fps: int = -1
var motion_blur_enabled: bool = true
var shadows_enabled: bool = true
var mobile_mode: bool = false
var is_android: bool = false
var language: String = "en"
var camera_button_size_scale: float:
	get:
		return 1.3 if is_android else 1.0
var custom_night_ouz_level: int = 0
var custom_night_mayinmelih_level: int = 0
var custom_night_unlocked: bool = false
var _window_mode_before_fullscreen: int = DisplayServer.WINDOW_MODE_WINDOWED
var _window_size_before_fullscreen: Vector2i = Vector2i.ZERO
var _window_position_before_fullscreen: Vector2i = Vector2i.ZERO

signal mobile_mode_changed(enabled: bool)

var _default_shadow_atlas_size: int
var _light_shadow_defaults: Dictionary = {}


func _ready() -> void:
	is_android = OS.get_name() == "Android"
	var settings_file_exists := FileAccess.file_exists(SETTINGS_PATH)
	_default_shadow_atlas_size = int(ProjectSettings.get_setting(
		"rendering/lights_and_shadows/positional_shadow/atlas_size", 4096
	))
	_load_settings()
	if is_android:
		mobile_mode = true
	if is_android or not settings_file_exists:
		_save_settings()
	get_tree().node_added.connect(_on_node_added)
	_apply_all_light_shadows()
	_apply_settings()
	if not OS.has_feature("mobile"):
		_window_mode_before_fullscreen = DisplayServer.window_get_mode()
		_window_size_before_fullscreen = DisplayServer.window_get_size()
		_window_position_before_fullscreen = DisplayServer.window_get_position()


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F11 and key_event.physical_keycode != KEY_F11:
		return
	if OS.has_feature("mobile") or OS.get_name() == "Android":
		return
	_toggle_desktop_fullscreen()
	get_viewport().set_input_as_handled()


func _toggle_desktop_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	var is_fullscreen := current_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if is_fullscreen:
		DisplayServer.window_set_mode(_window_mode_before_fullscreen)
		if _window_mode_before_fullscreen == DisplayServer.WINDOW_MODE_WINDOWED:
			if _window_size_before_fullscreen.x > 0 and _window_size_before_fullscreen.y > 0:
				DisplayServer.window_set_size(_window_size_before_fullscreen)
			DisplayServer.window_set_position(_window_position_before_fullscreen)
		return

	_window_mode_before_fullscreen = current_mode
	_window_size_before_fullscreen = DisplayServer.window_get_size()
	_window_position_before_fullscreen = DisplayServer.window_get_position()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func set_quality(value: String) -> void:
	if not QUALITY_OPTIONS.has(value):
		push_warning("Unknown graphics quality: " + value)
		return
	quality = value
	if quality == "i respect that":
		motion_blur_enabled = false
		shadows_enabled = false
		_apply_all_light_shadows()
	_save_settings()
	_apply_quality()
	_apply_motion_blur()


func set_max_fps(value: int) -> void:
	if not FPS_LIMITS.has(value):
		push_warning("Unsupported FPS limit: %d" % value)
		return
	max_fps = value
	_apply_fps_limit()
	_save_settings()


func set_motion_blur_enabled(value: bool) -> void:
	motion_blur_enabled = value
	_apply_motion_blur()
	_save_settings()


func set_shadows_enabled(value: bool) -> void:
	shadows_enabled = value
	_apply_all_light_shadows()
	_save_settings()


func set_mobile_mode(value: bool) -> void:
	if is_android:
		value = true
	if mobile_mode == value:
		return
	mobile_mode = value
	mobile_mode_changed.emit(mobile_mode)
	_save_settings()


func set_custom_night_levels(ouz_level: int, mayinmelih_level: int) -> void:
	var normalized_ouz := clampi(ouz_level, 0, 20)
	var normalized_mayinmelih := clampi(mayinmelih_level, 0, 20)
	if custom_night_ouz_level == normalized_ouz and custom_night_mayinmelih_level == normalized_mayinmelih:
		return
	custom_night_ouz_level = normalized_ouz
	custom_night_mayinmelih_level = normalized_mayinmelih
	_save_settings()


func unlock_custom_night() -> void:
	if custom_night_unlocked:
		return
	custom_night_unlocked = true
	_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_error("Could not load settings file: %s (error %d)" % [SETTINGS_PATH, err])
		return

	var stored_quality := str(config.get_value("graphics", "quality", quality))
	if QUALITY_OPTIONS.has(stored_quality):
		quality = stored_quality
	var stored_fps := int(config.get_value("graphics", "max_fps", max_fps))
	if FPS_LIMITS.has(stored_fps):
		max_fps = stored_fps
	motion_blur_enabled = bool(config.get_value("graphics", "motion_blur", motion_blur_enabled))
	shadows_enabled = bool(config.get_value("graphics", "shadows", shadows_enabled))
	mobile_mode = bool(config.get_value("graphics", "mobile", mobile_mode))
	var stored_language := str(config.get_value("language", "locale", language)).to_lower()
	if stored_language in ["en", "tr"]:
		language = stored_language
	custom_night_ouz_level = clampi(int(config.get_value("custom_night", "ouz_level", custom_night_ouz_level)), 0, 20)
	custom_night_mayinmelih_level = clampi(int(config.get_value("custom_night", "mayinmelih_level", custom_night_mayinmelih_level)), 0, 20)
	custom_night_unlocked = bool(config.get_value("progress", "custom_night_unlocked", custom_night_unlocked))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	config.set_value("graphics", "max_fps", max_fps)
	config.set_value("graphics", "motion_blur", motion_blur_enabled)
	config.set_value("graphics", "shadows", shadows_enabled)
	config.set_value("graphics", "mobile", mobile_mode)
	config.set_value("language", "locale", language)
	config.set_value("custom_night", "ouz_level", custom_night_ouz_level)
	config.set_value("custom_night", "mayinmelih_level", custom_night_mayinmelih_level)
	config.set_value("progress", "custom_night_unlocked", custom_night_unlocked)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Could not save settings file: %s (error %d)" % [SETTINGS_PATH, err])


func set_language(value: String) -> void:
	var normalized := value.to_lower()
	if normalized not in ["en", "tr"] or language == normalized:
		return
	language = normalized
	_save_settings()


func _apply_settings() -> void:
	_apply_fps_limit()
	_apply_quality()
	_apply_motion_blur()


func _apply_fps_limit() -> void:
	if max_fps == -1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = 0
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = max_fps


func _apply_quality() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		var container := scene.get_node_or_null("SubViewportContainer") as SubViewportContainer
		if container != null:
			container.stretch_shrink = int(QUALITY_SHRINK[quality])
			if container.has_method("set_motion_blur_enabled"):
				container.call("set_motion_blur_enabled", motion_blur_enabled)
			var viewport := container.get_node_or_null("SubViewport") as SubViewport
			if viewport != null:
				viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				viewport.scaling_3d_scale = float(QUALITY_SCALE[quality])
				var shadow_atlas_size := int(QUALITY_SHADOW_ATLAS.get(quality, _default_shadow_atlas_size))
				RenderingServer.viewport_set_positional_shadow_atlas_size(
					viewport.get_viewport_rid(), shadow_atlas_size
				)

		var camera_container := scene.find_child("CamViewContainer", true, false) as SubViewportContainer
		if camera_container != null:
			var quality_step := QUALITY_OPTIONS.find(quality)
			var target_camera_shrink := CAMERA_DEFAULT_SHRINK + quality_step * CAMERA_SHRINK_PER_QUALITY_STEP
			var integer_shrink := maxi(floori(target_camera_shrink), 1)
			camera_container.stretch_shrink = integer_shrink
			var camera_viewport := camera_container.get_node_or_null("CamViewport") as SubViewport
			if camera_viewport != null:
				camera_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				# SubViewportContainer only accepts integer shrink; this preserves half-step quality levels.
				camera_viewport.scaling_3d_scale = float(QUALITY_SCALE[quality]) * float(integer_shrink) / target_camera_shrink


func _apply_motion_blur() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var container := scene.get_node_or_null("SubViewportContainer") as SubViewportContainer
	if container != null and container.has_method("set_motion_blur_enabled"):
		container.call("set_motion_blur_enabled", motion_blur_enabled)


func _on_node_added(node: Node) -> void:
	if node is Light3D:
		var light := node as Light3D
		_light_shadow_defaults[light.get_instance_id()] = light.shadow_enabled
		_apply_light_shadow(light)
	elif node is SubViewport or node.name == "SubViewportContainer":
		call_deferred("_apply_scene_settings")


func _apply_scene_settings() -> void:
	_apply_quality()
	_apply_motion_blur()


func _apply_all_light_shadows() -> void:
	var root := get_tree().root
	for node: Node in root.find_children("*", "Light3D", true, false):
		_apply_light_shadow(node as Light3D)


func _apply_light_shadow(light: Light3D) -> void:
	if not is_instance_valid(light):
		return
	var instance_id := light.get_instance_id()
	if not _light_shadow_defaults.has(instance_id):
		_light_shadow_defaults[instance_id] = light.shadow_enabled
	light.shadow_enabled = bool(_light_shadow_defaults[instance_id]) and shadows_enabled
