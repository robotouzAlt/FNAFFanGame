class_name DebugWalker
extends CharacterBody3D

const DEBUG_CODE: Array[Key] = [KEY_D, KEY_E, KEY_B, KEY_U, KEY_G]

@export var debug_walker_enabled: bool = false

@export_group("Hareket")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 9.5
@export var noclip_vertical_speed: float = 6.5
@export var accel_ground: float = 12.0
@export var decel_ground: float = 10.0
@export var accel_air: float = 3.5
@export var decel_air: float = 1.5
@export var jump_velocity: float = 5.0
@export var fall_gravity_multiplier: float = 1.35

@export_group("Kamera ve Fener")
@export var mouse_sensitivity: float = 0.012
@export var debug_camera: Camera3D
@export var flashlight: SpotLight3D
var debug_audio_listener: AudioListener3D
var player_audio_listener: AudioListener3D

@export_group("Head Bob & Zıplama Hissi")
@export var bob_enabled: bool = true
@export var walk_bob_freq: float = 9.0
@export var sprint_bob_freq: float = 13.5
@export var walk_bob_amp_y: float = 0.045
@export var sprint_bob_amp_y: float = 0.075
@export var walk_bob_amp_x: float = 0.03
@export var sprint_bob_amp_x: float = 0.055
@export var landing_bob_scale: float = 0.018
@export var jump_tilt_deg: float = 2.2
@export var sprint_fov_boost: float = 5.0

var _debug_mode: bool = false
var _debug_code_index: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _cam_base_pos: Vector3 = Vector3.ZERO
var _cam_base_fov: float = 75.0
var _bob_time: float = 0.0
var _bob_offset: Vector2 = Vector2.ZERO
var _impact_offset_y: float = 0.0
var _jump_pitch_offset: float = 0.0
var _was_on_floor: bool = false
var _saved_collision_layer: int = 1
var _saved_collision_mask: int = 1
var _disabled_colliders: Array[Node] = []


func _ready() -> void:
	debug_audio_listener = find_child("DebugAudioListener", true, false) as AudioListener3D
	player_audio_listener = get_tree().root.find_child("OfficeAudioListener", true, false) as AudioListener3D
	if not debug_camera:
		debug_camera = find_child("DebugCamera3D", true, false) as Camera3D
	if not flashlight:
		flashlight = find_child("SpotLight3D", true, false) as SpotLight3D

	if debug_camera:
		_cam_base_pos = debug_camera.position
		_cam_base_fov = debug_camera.fov
		debug_camera.current = false
	if flashlight:
		flashlight.visible = false

	set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _process_debug_code(event.keycode):
			return
		if not _debug_mode:
			return
		if event.keycode == KEY_F:
			_toggle_flashlight()

	if not _debug_mode:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if debug_camera:
			debug_camera.rotate_x(-event.relative.y * mouse_sensitivity)
			debug_camera.rotation.x = clampf(debug_camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _process_debug_code(keycode: Key) -> bool:
	if not debug_walker_enabled:
		_debug_code_index = 0
		if _debug_mode:
			_exit_debug_mode()
		return false
	if keycode == DEBUG_CODE[_debug_code_index]:
		_debug_code_index += 1
		if _debug_code_index >= DEBUG_CODE.size():
			_debug_code_index = 0
			if _debug_mode:
				_exit_debug_mode()
			else:
				_enter_debug_mode_permanently()
			return true
	else:
		_debug_code_index = 1 if keycode == DEBUG_CODE[0] else 0
	return false


func _set_noclip_enabled(enabled: bool) -> void:
	if enabled:
		_saved_collision_layer = collision_layer
		_saved_collision_mask = collision_mask
		collision_layer = 0
		collision_mask = 0
		_disabled_colliders.clear()
		for child in find_children("*", "CollisionShape3D", true, false):
			var shape := child as CollisionShape3D
			if shape and not shape.disabled:
				shape.disabled = true
				_disabled_colliders.append(shape)
		for child in find_children("*", "CollisionPolygon3D", true, false):
			var poly := child as CollisionPolygon3D
			if poly and not poly.disabled:
				poly.disabled = true
				_disabled_colliders.append(poly)
	else:
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		for node in _disabled_colliders:
			if not is_instance_valid(node):
				continue
			if node is CollisionShape3D:
				(node as CollisionShape3D).disabled = false
			elif node is CollisionPolygon3D:
				(node as CollisionPolygon3D).disabled = false
		_disabled_colliders.clear()


func _enter_debug_mode_permanently() -> void:
	_debug_mode = true
	_set_noclip_enabled(true)
	velocity = Vector3.ZERO
	set_physics_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if debug_audio_listener:
		debug_audio_listener.make_current()

	if not debug_camera:
		debug_camera = find_child("DebugCamera3D", true, false) as Camera3D
	if debug_camera:
		_cam_base_pos = debug_camera.position
		_cam_base_fov = debug_camera.fov
		debug_camera.current = true
		debug_camera.make_current()

	if not flashlight:
		flashlight = find_child("SpotLight3D", true, false) as SpotLight3D
	if flashlight:
		flashlight.visible = true

	_was_on_floor = false


func is_debug_mode_enabled() -> bool:
	return _debug_mode


func set_debug_camera_active(active: bool) -> void:
	if not _debug_mode:
		return
	var player_camera := get_tree().root.find_child("Camera3D", true, false) as Camera3D
	if active:
		if debug_camera:
			debug_camera.make_current()
		if debug_audio_listener:
			debug_audio_listener.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		if player_camera:
			player_camera.make_current()
		if player_audio_listener:
			player_audio_listener.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _exit_debug_mode() -> void:
	_debug_mode = false
	_debug_code_index = 0
	set_physics_process(false)
	velocity = Vector3.ZERO
	_set_noclip_enabled(false)
	if debug_camera:
		debug_camera.current = false
	if flashlight:
		flashlight.visible = false

	var player_camera := get_tree().root.find_child("Camera3D", true, false) as Camera3D
	if player_camera:
		player_camera.make_current()
	if player_audio_listener:
		player_audio_listener.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _toggle_flashlight() -> void:
	if not flashlight:
		flashlight = find_child("SpotLight3D", true, false) as SpotLight3D
	if flashlight:
		flashlight.visible = not flashlight.visible


func _physics_process(delta: float) -> void:
	if not _debug_mode:
		return

	var is_sprinting := Input.is_key_pressed(KEY_SHIFT)

	# WASD yatay hareket
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vec.x += 1.0
	input_vec = input_vec.limit_length(1.0)

	# Space: yukarı, Ctrl: aşağı
	var vert_input := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vert_input += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		vert_input -= 1.0

	var horiz_speed := sprint_speed if is_sprinting else walk_speed
	var vert_speed := noclip_vertical_speed * (sprint_speed / maxf(walk_speed, 0.1) if is_sprinting else 1.0)
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var blend := clampf(accel_ground * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, wish_dir.x * horiz_speed, blend)
	velocity.z = lerpf(velocity.z, wish_dir.z * horiz_speed, blend)
	velocity.y = lerpf(velocity.y, vert_input * vert_speed, blend)

	# Çarpışma kapalıyken doğrudan konum güncelle (her şeyin içinden takılmadan geçer)
	global_position += velocity * delta
	_update_noclip_camera_motion(delta, is_sprinting)


func _update_noclip_camera_motion(delta: float, is_sprinting: bool) -> void:
	if not debug_camera or not is_instance_valid(debug_camera):
		return

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if bob_enabled and horiz_speed > 0.25:
		var freq := sprint_bob_freq if is_sprinting else walk_bob_freq
		var amp_y := sprint_bob_amp_y * 0.45 if is_sprinting else walk_bob_amp_y * 0.45
		var amp_x := sprint_bob_amp_x * 0.45 if is_sprinting else walk_bob_amp_x * 0.45
		_bob_time += delta * freq * clampf(horiz_speed / maxf(walk_speed, 0.1), 0.5, 1.4)
		_bob_offset.y = sin(_bob_time * 2.0) * amp_y
		_bob_offset.x = cos(_bob_time) * amp_x
	else:
		_bob_time = 0.0
		_bob_offset = _bob_offset.lerp(Vector2.ZERO, clampf(10.0 * delta, 0.0, 1.0))

	_impact_offset_y = lerpf(_impact_offset_y, 0.0, clampf(12.0 * delta, 0.0, 1.0))
	debug_camera.position = _cam_base_pos + Vector3(_bob_offset.x, _bob_offset.y + _impact_offset_y, 0.0)

	if absf(_jump_pitch_offset) > 0.0001:
		var step := lerpf(_jump_pitch_offset, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		var diff := step - _jump_pitch_offset
		debug_camera.rotate_x(diff)
		debug_camera.rotation.x = clampf(debug_camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
		_jump_pitch_offset = step

	var active_sprint := is_sprinting and horiz_speed > 1.0
	var target_fov := _cam_base_fov + (sprint_fov_boost if active_sprint else 0.0)
	debug_camera.fov = lerpf(debug_camera.fov, target_fov, clampf(8.0 * delta, 0.0, 1.0))
