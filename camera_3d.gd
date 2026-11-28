class_name PlayerCamera
extends Camera3D

signal zoom_finished
signal return_finished

@export_group("Sallanma")
@export var pitch_deg: float = 0.35
@export var yaw_deg: float = 0.5
@export var roll_deg: float = 0.15
@export var position_amount: float = 0.006
@export var speed: float = 0.4

@export_group("Kenar Kaydırma")
@export var max_turn_deg: float = 45.0
@export_range(0.02, 0.4) var edge_enter: float = 0.10
@export_range(0.02, 0.5) var edge_exit: float = 0.18
@export var turn_time: float = 0.8
@export var return_time: float = 0.8
@export var hidden_turn_time: float = 0.8
@export var confine_mouse: bool = false
@export_group("Hidden Edge Look")
@export_range(0.02, 0.4) var hidden_edge_enter: float = 0.25
@export_range(0.02, 0.5) var hidden_edge_exit: float = 0.32
@export_range(0.0, 45.0, 1.0) var hidden_max_turn_deg: float = 20.0
@export_group("Saklanma Sallantısı")
@export var hidden_sway_speed: float = 0.4
@export var hidden_sway_yaw_deg: float = 0.35
@export var hidden_sway_pitch_deg: float = 0.12
@export var hidden_sway_roll_deg: float = 0.1
@export var hidden_sway_position: float = 0.004
@export var hidden_fear_sway_speed: float = 3.2
@export var hidden_fear_yaw_deg: float = 4.0
@export var hidden_fear_pitch_deg: float = 1.8
@export var hidden_fear_roll_deg: float = 1.4
@export var hidden_fear_position: float = 0.035

@export_group("Aşağı Bakma")
@export var look_down_enabled: bool = true
@export var look_down_deg: float = 15.0
@export_range(0.02, 0.5) var edge_enter_y: float = 0.40
@export_range(0.02, 0.6) var edge_exit_y: float = 0.44
@export var look_down_time: float = 0.5

@export_group("Gece Müziği")
@export var the_music_enabled: bool = false
@export var night_music_delay: float = 1.0

var _base_rotation: Vector3
var _base_position: Vector3
var _base_fov: float
var _noise := FastNoiseLite.new()
var _t: float = 0.0

var _zone: int = 0
var _pan_yaw: float = 0.0
var _pan_tween: Tween

var _pitch_zone: int = 0
var _pan_pitch: float = 0.0
var _pitch_tween: Tween

var _shake_amount: float = 0.0
var _shake_tween: Tween
var _base_h_offset: float = 0.0
var _base_v_offset: float = 0.0

var _locked: bool = false
var _hidden_look_enabled: bool = false
var _hidden_fear_sway_amount: float = 0.0
var _hidden_fear_sway_tween: Tween
var _hidden_base_global_rotation: Vector3
var _hidden_base_global_position: Vector3
var _frozen: bool = false
var _move_tween: Tween
var _move_start: Transform3D
var _move_target: Transform3D
var _move_start_fov: float
var _move_target_fov: float
var _music_player: AudioStreamPlayer3D


func _ready() -> void:
	_base_rotation = rotation
	_base_position = position
	_base_fov = fov
	_base_h_offset = h_offset
	_base_v_offset = v_offset
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	if confine_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	_play_night_music_after_delay()


func _play_night_music_after_delay() -> void:
	if not the_music_enabled:
		return
	await get_tree().create_timer(maxf(night_music_delay, 0.0)).timeout
	if not is_inside_tree() or not the_music_enabled:
		return
	_music_player = get_tree().root.find_child("TheMusic", true, false) as AudioStreamPlayer3D
	if _music_player == null:
		push_warning("PlayerCamera: 'TheMusic' AudioStreamPlayer3D düğümü bulunamadı.")
		return
	if _music_player.stream == null:
		push_warning("PlayerCamera: 'TheMusic' düğümünde ses akışı (stream) atanmamış.")
		return
	if not _music_player.playing:
		_music_player.play()


func _process(delta: float) -> void:
	_update_shake_offsets()
	if _frozen:
		return
	var fear_amount := clampf(_hidden_fear_sway_amount, 0.0, 1.0)
	if _locked:
		if _hidden_look_enabled:
			_update_zone(_get_mouse_ratio().x, true)
			var sway_speed := lerpf(hidden_sway_speed, hidden_fear_sway_speed, fear_amount)
			var yaw_amount := lerpf(hidden_sway_yaw_deg, hidden_fear_yaw_deg, fear_amount)
			var pitch_amount := lerpf(hidden_sway_pitch_deg, hidden_fear_pitch_deg, fear_amount)
			var roll_amount := lerpf(hidden_sway_roll_deg, hidden_fear_roll_deg, fear_amount)
			var position_amount_hidden := lerpf(hidden_sway_position, hidden_fear_position, fear_amount)
			_t += delta * sway_speed
			var hidden_sway := Vector3(
				deg_to_rad(_noise.get_noise_1d(_t + 200.0) * pitch_amount),
				deg_to_rad(_noise.get_noise_1d(_t + 100.0) * yaw_amount),
				deg_to_rad(_noise.get_noise_1d(_t + 300.0) * roll_amount)
			)
			var local_sway := Vector3(
				_noise.get_noise_1d(_t + 400.0) * position_amount_hidden,
				_noise.get_noise_1d(_t + 500.0) * position_amount_hidden * 0.45,
				0.0
			)
			global_position = _hidden_base_global_position + Basis.from_euler(_hidden_base_global_rotation) * local_sway
			global_rotation = _hidden_base_global_rotation + hidden_sway + Vector3(0.0, _pan_yaw, 0.0)
		return

	var ratio := _get_mouse_ratio()
	_update_zone(ratio.x)
	_update_pitch_zone(ratio.y)

	var active_speed := lerpf(speed, hidden_fear_sway_speed, fear_amount)
	var active_pitch_deg := lerpf(pitch_deg, hidden_fear_pitch_deg, fear_amount)
	var active_yaw_deg := lerpf(yaw_deg, hidden_fear_yaw_deg, fear_amount)
	var active_roll_deg := lerpf(roll_deg, hidden_fear_roll_deg, fear_amount)
	var active_pos_amount := lerpf(position_amount, hidden_fear_position, fear_amount)

	_t += delta * active_speed
	var pitch := _noise.get_noise_1d(_t) * active_pitch_deg
	var yaw := _noise.get_noise_1d(_t + 100.0) * active_yaw_deg
	var roll := _noise.get_noise_1d(_t + 200.0) * active_roll_deg

	rotation = _base_rotation + Vector3(
		deg_to_rad(pitch) + _pan_pitch,
		deg_to_rad(yaw) + _pan_yaw,
		deg_to_rad(roll)
	)

	var offset := Vector3(
		_noise.get_noise_1d(_t + 300.0),
		_noise.get_noise_1d(_t + 400.0),
		0.0
	) * active_pos_amount

	position = _base_position + offset


func zoom_to(target: Transform3D, target_fov: float, duration: float) -> void:
	_locked = true
	_hidden_base_global_rotation = target.basis.get_euler()
	if _pan_tween:
		_pan_tween.kill()
	if _pitch_tween:
		_pitch_tween.kill()
	_start_move(target, target_fov, duration, _on_zoom_done)


func return_to_base(duration: float) -> void:
	_hidden_look_enabled = false
	var parent := get_parent_node_3d()
	var parent_xf := parent.global_transform if parent else Transform3D.IDENTITY
	var base_local := Transform3D(Basis.from_euler(_base_rotation), _base_position)
	_start_move(parent_xf * base_local, _base_fov, duration, _on_return_done)


func set_hidden_look_enabled(value: bool) -> void:
	_hidden_look_enabled = value
	if _pan_tween:
		_pan_tween.kill()
	_zone = 0
	_pan_yaw = 0.0
	if value:
		_hidden_base_global_rotation = global_rotation
		_hidden_base_global_position = global_position


func set_hidden_ambient_sway_enabled(value: bool, transition_duration: float = 0.0) -> void:
	if _hidden_fear_sway_tween:
		_hidden_fear_sway_tween.kill()
	var target_amount := 0.0 if value else 1.0
	if transition_duration <= 0.0:
		_hidden_fear_sway_amount = target_amount
	else:
		_hidden_fear_sway_tween = create_tween()
		_hidden_fear_sway_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hidden_fear_sway_tween.tween_property(self, "_hidden_fear_sway_amount", target_amount, transition_duration)
	if not value and _hidden_look_enabled:
		global_position = _hidden_base_global_position


func continue_fear_sway_and_fade_out(hold_duration: float, fade_out_duration: float) -> void:
	if _hidden_fear_sway_tween:
		_hidden_fear_sway_tween.kill()
	if _hidden_fear_sway_amount <= 0.001:
		_hidden_fear_sway_amount = 1.0
	_hidden_fear_sway_tween = create_tween()
	if hold_duration > 0.0:
		_hidden_fear_sway_tween.tween_interval(hold_duration)
	_hidden_fear_sway_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hidden_fear_sway_tween.tween_property(self, "_hidden_fear_sway_amount", 0.0, maxf(fade_out_duration, 0.01))
	_hidden_fear_sway_tween.finished.connect(func() -> void:
		if is_inside_tree() and _hidden_look_enabled:
			global_position = _hidden_base_global_position
	)


func set_frozen(value: bool) -> void:
	_frozen = value


func is_busy() -> bool:
	return _locked or _frozen


func snap_to_base() -> void:
	for tw: Tween in [_pan_tween, _pitch_tween, _move_tween]:
		if tw:
			tw.kill()
	_zone = 0
	_pitch_zone = 0
	_pan_yaw = 0.0
	_pan_pitch = 0.0
	rotation = _base_rotation
	position = _base_position
	fov = _base_fov


func shake(amount: float, duration: float) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_amount = amount
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "_shake_amount", 0.0, duration)


func reset_shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_amount = 0.0
	h_offset = _base_h_offset
	v_offset = _base_v_offset


func _update_shake_offsets() -> void:
	var amount := maxf(_shake_amount, 0.0)
	h_offset = _base_h_offset + randf_range(-amount, amount)
	v_offset = _base_v_offset + randf_range(-amount, amount)


func _start_move(target: Transform3D, target_fov: float, duration: float, on_done: Callable) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_start = global_transform
	_move_target = target
	_move_start_fov = fov
	_move_target_fov = target_fov
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_method(_apply_move, 0.0, 1.0, duration)
	_move_tween.finished.connect(on_done)


func _apply_move(w: float) -> void:
	global_transform = _move_start.interpolate_with(_move_target, w)
	fov = lerpf(_move_start_fov, _move_target_fov, w)


func _on_zoom_done() -> void:
	global_transform = _move_target
	fov = _move_target_fov
	_hidden_base_global_rotation = global_rotation
	zoom_finished.emit()


func _on_return_done() -> void:
	_locked = false
	_zone = 0
	_pitch_zone = 0
	_pan_yaw = 0.0
	_pan_pitch = 0.0
	fov = _base_fov
	return_finished.emit()


func _update_zone(x: float, hidden_look: bool = false) -> void:
	var new_zone := _zone
	var enter_threshold := hidden_edge_enter if hidden_look else edge_enter
	var exit_threshold := hidden_edge_exit if hidden_look else edge_exit
	var turn_angle := hidden_max_turn_deg if hidden_look else max_turn_deg

	match _zone:
		0:
			if x > 1.0 - enter_threshold:
				new_zone = 1
			elif x < enter_threshold:
				new_zone = -1
		1:
			if x < 1.0 - exit_threshold:
				new_zone = 0
		-1:
			if x > exit_threshold:
				new_zone = 0

	if new_zone != _zone:
		_zone = new_zone
		_turn_to(-float(_zone) * deg_to_rad(turn_angle), hidden_look)


func _update_pitch_zone(y: float) -> void:
	var new_zone := _pitch_zone
	if not look_down_enabled:
		new_zone = 0
	elif _pitch_zone == 0:
		if y > 1.0 - edge_enter_y:
			new_zone = 1
	else:
		if y < 1.0 - edge_exit_y:
			new_zone = 0

	if new_zone != _pitch_zone:
		_pitch_zone = new_zone
		_pitch_to(-float(_pitch_zone) * deg_to_rad(look_down_deg))


func _turn_to(target: float, hidden_look: bool = false) -> void:
	if _pan_tween:
		_pan_tween.kill()

	var turn_angle := hidden_max_turn_deg if hidden_look else max_turn_deg
	var max_rad := maxf(absf(deg_to_rad(turn_angle)), 0.0001)
	var base_time := hidden_turn_time if hidden_look else (return_time if is_zero_approx(target) else turn_time)
	var duration := base_time * absf(target - _pan_yaw) / max_rad

	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_property(self, "_pan_yaw", target, duration)


func _pitch_to(target: float) -> void:
	if _pitch_tween:
		_pitch_tween.kill()

	var max_rad := maxf(deg_to_rad(look_down_deg), 0.0001)
	var duration := look_down_time * absf(target - _pan_pitch) / max_rad

	_pitch_tween = create_tween()
	_pitch_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pitch_tween.tween_property(self, "_pan_pitch", target, duration)


func _get_mouse_ratio() -> Vector2:
	var vp := get_viewport()
	var container: SubViewportContainer = null
	if vp is SubViewport:
		container = vp.get_parent() as SubViewportContainer

	if container and container.size.x > 0.0 and container.size.y > 0.0:
		var p := container.get_local_mouse_position()
		return Vector2(p.x / container.size.x, p.y / container.size.y)

	var viewport_size := vp.get_visible_rect().size
	var m := vp.get_mouse_position()
	return Vector2(m.x / maxf(viewport_size.x, 1.0), m.y / maxf(viewport_size.y, 1.0))
