class_name HideController
extends Area3D

signal hidden_changed(value: bool)
## Saklanırken ekrana tıklandı (canavar mantığı karar verir)
signal unhide_clicked

@export var hide_time: float = 0.6
@export var unhide_time: float = 0.5

var is_hidden: bool = false

var _hiding: bool = false
var _busy: bool = false
var _over: bool = false
var _was_pressed: bool = false
var _cursor_hand: bool = false
var _player_cam: PlayerCamera
var _hide_view: Camera3D
var _cam_system: CameraSystemUI
var _debug_walker: DebugWalker
var _debug_mode_before_hide: bool = false
var _hiding_audio: AudioStreamPlayer3D
var _hiding_streams: Array[AudioStream] = []


func _ready() -> void:
	var r := get_tree().root
	_player_cam = r.find_child("Camera3D", true, false) as PlayerCamera
	_hide_view = r.find_child("HideView", true, false) as Camera3D
	_cam_system = r.find_child("CameraSystemUI", true, false) as CameraSystemUI
	if _cam_system and not _cam_system.mobile_hide_exit_requested.is_connected(unhide):
		_cam_system.mobile_hide_exit_requested.connect(unhide)
	_debug_walker = r.find_child("CharacterBody3D", true, false) as DebugWalker
	_hiding_audio = r.find_child("Hiding", true, false) as AudioStreamPlayer3D
	if _hiding_audio:
		_hiding_audio.volume_db = AudioSettings.HIDING_DB
		_hiding_audio.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
	_hiding_streams.clear()
	for i in range(1, 8):
		var hiding_stream := load("res://audio/hiding/hiding%d.wav" % i) as AudioStream
		if hiding_stream:
			_hiding_streams.append(hiding_stream)
	if not _player_cam or not _hide_view:
		push_error("HideController: Camera3D veya HideView bulunamadı.")
		set_process(false)
		set_physics_process(false)


## Saklı ya da saklanıyor mu
func is_concealed() -> bool:
	return is_hidden or _hiding


func _physics_process(_delta: float) -> void:
	_over = _is_mouse_over_hitbox()
	_set_hand_cursor(is_hidden or (_over and _can_hide()))


func _exit_tree() -> void:
	_set_hand_cursor(false)


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed := pressed and not _was_pressed
	_was_pressed = pressed
	if not just_pressed or _busy:
		return

	if is_hidden:
		if GameSettings.mobile_mode:
			return
		# Saklıyken herhangi bir yere tıklamak çıkış isteğidir
		if get_signal_connection_list("unhide_clicked").is_empty():
			unhide()
		else:
			unhide_clicked.emit()
		return

	if _over and _can_hide():
		hide_under_desk()


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or _busy:
		return
	if is_hidden:
		if not GameSettings.mobile_mode:
			if get_signal_connection_list("unhide_clicked").is_empty():
				unhide()
			else:
				unhide_clicked.emit()
			get_viewport().set_input_as_handled()
		return
	if _can_hide() and _is_screen_point_over_hitbox(touch.position):
		hide_under_desk()
		get_viewport().set_input_as_handled()


func _can_hide() -> bool:
	if _cam_system and _cam_system.is_open():
		return false
	return not _player_cam.is_busy()


func hide_under_desk() -> void:
	if is_hidden or _busy:
		return
	_busy = true
	_hiding = true
	var sound_duration := _play_hiding_sound()
	if _cam_system:
		_cam_system.lock_cams("hide")
	_debug_mode_before_hide = _debug_walker != null and _debug_walker.is_debug_mode_enabled()
	if _debug_mode_before_hide:
		_debug_walker.set_debug_camera_active(false)
	var hide_transform := _hide_view.global_transform
	var transition_time := maxf(hide_time, sound_duration)
	_player_cam.zoom_to(hide_transform, _hide_view.fov, transition_time)
	await _player_cam.zoom_finished
	is_hidden = true
	_player_cam.set_hidden_look_enabled(true)
	if _cam_system:
		_cam_system.set_mobile_hide_exit_mode(true)
	_hiding = false
	_busy = false
	hidden_changed.emit(true)


func unhide() -> void:
	if not is_hidden or _busy:
		return
	_busy = true
	var sound_duration := _play_hiding_sound()
	_player_cam.set_hidden_look_enabled(false)
	_player_cam.return_to_base(maxf(unhide_time, sound_duration))
	await _player_cam.return_finished
	is_hidden = false
	_busy = false
	if _cam_system:
		_cam_system.set_mobile_hide_exit_mode(false)
		_cam_system.unlock_cams("hide")
	if _debug_mode_before_hide and _debug_walker and is_instance_valid(_debug_walker):
		_debug_walker.set_debug_camera_active(true)
	_debug_mode_before_hide = false
	hidden_changed.emit(false)


func _play_hiding_sound() -> float:
	if not _hiding_audio or not is_instance_valid(_hiding_audio) or _hiding_streams.is_empty():
		return 0.0
	_hiding_audio.stop()
	if _player_cam and is_instance_valid(_player_cam):
		_hiding_audio.global_position = _player_cam.global_position
	var stream: AudioStream = _hiding_streams.pick_random()
	_hiding_audio.stream = stream
	_hiding_audio.play()
	return stream.get_length()


func _is_mouse_over_hitbox() -> bool:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		return false

	var container: SubViewportContainer = null
	if vp is SubViewport:
		container = vp.get_parent() as SubViewportContainer

	var mouse_pos: Vector2
	if container:
		var local := container.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, container.size).has_point(local):
			return false
		if container.stretch and container.size.x > 0.0 and container.size.y > 0.0:
			var viewport_size := vp.get_visible_rect().size
			mouse_pos = local * viewport_size / container.size
		else:
			mouse_pos = local / maxf(float(container.stretch_shrink), 1.0)
	else:
		mouse_pos = vp.get_mouse_position()

	return _ray_hits_hide_hitbox(mouse_pos, cam)


func _is_screen_point_over_hitbox(screen_position: Vector2) -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_3d()
	if cam == null:
		return false
	if _ray_hits_hide_hitbox(screen_position, cam):
		return true
	if vp is SubViewport:
		var container := vp.get_parent() as SubViewportContainer
		if container and container.size.x > 0.0 and container.size.y > 0.0:
			var local := container.get_global_transform_with_canvas().affine_inverse() * screen_position
			if Rect2(Vector2.ZERO, container.size).has_point(local):
				var mapped := local * vp.get_visible_rect().size / container.size
				return _ray_hits_hide_hitbox(mapped, cam)
	return false


func _ray_hits_hide_hitbox(mouse_pos: Vector2, cam: Camera3D) -> bool:
	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 2
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == self


func _set_hand_cursor(enable: bool) -> void:
	if enable == _cursor_hand:
		return
	_cursor_hand = enable
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if enable else Input.CURSOR_ARROW)
