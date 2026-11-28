extends Node

const MUSIC_BOX_ECHO_CAMERA := 10
const MUSIC_BOX_REMOTE_CAMERAS: Array[int] = [9, 8, 11]
const LURE_CAM_ROOMS: PackedStringArray = [
	"fireescape", "storage", "northhall", "janitorcloset", "backstage",
	"frontauditorium", "coliseum", "westhall", "southhall", "tearoom",
	"commonroom", "auditoriumenterance", "auditorium"
]
const COMMONROOM_POSE := "pose_listening_commonroom"
const AWAKE_POSE := "pose_awake_commonroom"
const STANDING_POSE := "pose_stand_general"
const KICKING_POSE := "pose_kicking"
const JUMPSCARE_POSE := "pose_jumpscare"

const TRANSFORMING_BUS_NAME := "TransformingEcho"
const TRANSFORMING_REVERB_ROOM_SIZE := 0.5
const TRANSFORMING_REVERB_DAMPING := 0.15
const TRANSFORMING_REVERB_WET := 0.5
const MAP_LIGHT_COUNT := 20
const FIRST_KNOCK_SOUND: AudioStream = preload("res://audio/knockfirst.wav")
const JUMPSCARE_SOUND: AudioStream = preload("res://audio/jumpscare.wav")

@export_group("Karamsar WorldEnvironment")
@export_range(1.0, 30.0, 0.5) var dread_env_fade_seconds: float = 10.0
@export var dread_bg_color: Color = Color(0.18, 0.28, 0.44, 1.0)
@export var dread_fog_color: Color = Color(0.28, 0.44, 0.68, 1.0)
@export_range(0.0, 0.1, 0.001) var dread_fog_density: float = 0.003
@export_range(0.0, 1.0, 0.05) var dread_blue_tint: float = 0.28

@export_group("Transforming")
@export_range(0.0, 1.0, 0.05) var transforming_reverb_wet: float = TRANSFORMING_REVERB_WET

@export_group("Jumpscare")
@export_range(0.2, 5.0, 0.1) var jumpscare_time: float = 1.4
@export_range(0.05, 3.0, 0.01) var jumpscare_shake: float = 0.18
@export_range(1.0, 60.0, 0.5) var jumpscare_rotation_shake_deg: float = 7.5
@export_range(0.0, 1.0, 0.05) var jumpscare_lunge: float = 0.18
@export_group("Attack Timing")
@export_range(0.02, 2.0, 0.02) var camera_approach_walk_seconds: float = 0.08
@export_range(0.02, 1.0, 0.01) var door_break_dash_seconds: float = 0.12

var _ouz: Node3D
var _animation: AnimationPlayer
var _spots: Node3D
var _monster_spots: Node3D
var _door: DoorSystem
var _lure_sounds: Array[AudioStreamPlayer3D] = []
var _music_box: AudioStreamPlayer3D
var _music_box_2: AudioStreamPlayer3D
var _music_box_late: AudioStreamPlayer3D
var _camera_ui: CameraSystemUI
var _game: GameManager
var _audio_listener: AudioListener3D
var _player_camera: PlayerCamera
var _scare_camera: Camera3D
var _jumpscare_camera: Camera3D
var _world_env: WorldEnvironment
var _env: Environment
var _env_initialized := false
var _map_lights: Array[Light3D] = []
var _init_light_colors: Array[Color] = []
var _dread_tween: Tween
var _init_bg_color: Color
var _init_fog_enabled: bool
var _init_fog_color: Color
var _init_fog_density: float
var _transforming_sound: Node
var _transforming_reverb: AudioEffectReverb
var _first_knock_sound: AudioStreamPlayer3D
var _door_break_sound: AudioStreamPlayer3D
var _jumpscare_sound: AudioStreamPlayer3D
var _hide_controller: HideController
var _office_ambience: AudioStreamPlayer
var _charge := 1.0
var _charge_drain_multiplier := 1.0
var _awake := false
var _sequence_running := false
var _ended := false
var _room := "commonroom"
var _ouz_scale := Vector3.ONE
var _alt_song_active := false
var _next_request_timer := 0.0
var _request_active := false
var _request_waiting_for_cameras := false
var _late_start_pending := false
var _request_left := 0.0
var debug_mode: bool = false


func _ready() -> void:
	var world := get_tree().root
	_ouz = world.find_child("Ouz", true, false) as Node3D
	_spots = world.find_child("OuzSpots", true, false) as Node3D
	_monster_spots = world.find_child("MonsterSpots", true, false) as Node3D
	_door = world.find_child("DoorSystem", true, false) as DoorSystem
	_animation = world.find_child("AnimationPlayerOuz", true, false) as AnimationPlayer
	_music_box = world.find_child("MusicBox", true, false) as AudioStreamPlayer3D
	_music_box_2 = world.find_child("MusicBox2", true, false) as AudioStreamPlayer3D
	_music_box_late = world.find_child("MusicBoxLate", true, false) as AudioStreamPlayer3D
	_camera_ui = world.find_child("CameraSystemUI", true, false) as CameraSystemUI
	_game = world.find_child("GameManager", true, false) as GameManager
	_audio_listener = world.find_child("OfficeAudioListener", true, false) as AudioListener3D
	_office_ambience = world.find_child("OfficeAmbiance", true, false) as AudioStreamPlayer
	_player_camera = world.find_child("Camera3D", true, false) as PlayerCamera
	_scare_camera = world.find_child("ScareCam", true, false) as Camera3D
	_world_env = world.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_transforming_sound = world.find_child("Transforming", true, false)
	_first_knock_sound = world.find_child("FirstKnockSound", true, false) as AudioStreamPlayer3D
	_door_break_sound = world.find_child("DoorBreakSound", true, false) as AudioStreamPlayer3D
	_jumpscare_sound = world.find_child("OuzJumpscareSound", true, false) as AudioStreamPlayer3D
	if not _jumpscare_sound:
		_jumpscare_sound = world.find_child("JumpscareSound", true, false) as AudioStreamPlayer3D
	_hide_controller = world.find_child("HideHitbox", true, false) as HideController
	if not _ouz or not _spots or not _animation or not _music_box or not _music_box_late or not _camera_ui:
		push_error("OuzAI: Ouz, OuzSpots, AnimationPlayerOuz, MusicBox/MusicBoxLate veya CameraSystemUI eksik.")
		set_process(false)
		return
	_setup_world_environment()
	_setup_map_lights(world)
	_reset_dread_environment_and_lights()
	for sound_name: String in ["LureSound", "LureSound2", "LureSound3"]:
		var lure_player := world.find_child(sound_name, true, false) as AudioStreamPlayer3D
		if lure_player:
			lure_player.max_distance = 100.0
			lure_player.unit_size = 20.0
			lure_player.volume_db = AudioSettings.LURE_DB
			lure_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			_lure_sounds.append(lure_player)
	if not _camera_ui.lure_requested.is_connected(_on_lure_requested):
		_camera_ui.lure_requested.connect(_on_lure_requested)
	if not _camera_ui.music_change_requested.is_connected(_on_music_change_requested):
		_camera_ui.music_change_requested.connect(_on_music_change_requested)

	_ensure_music_buses()
	_ensure_transforming_bus()
	_configure_transforming_sound()
	_ouz_scale = _ouz.global_transform.basis.get_scale()
	if _audio_listener:
		_audio_listener.make_current()
	if _office_ambience:
		_set_office_ambience_reduced(_camera_ui.is_open())
	if not _camera_ui.opened.is_connected(_on_camera_system_opened):
		_camera_ui.opened.connect(_on_camera_system_opened)
	if not _camera_ui.closed.is_connected(_on_camera_system_closed):
		_camera_ui.closed.connect(_on_camera_system_closed)
	_teleport_to("commonroom", COMMONROOM_POSE)
	_charge = 1.0
	_alt_song_active = false
	_request_active = false
	_request_waiting_for_cameras = false
	_request_left = 0.0
	if not debug_mode:
		_schedule_next_song_request()
	_music_box_late.stop()
	if _music_box_2:
		_music_box_2.stop()
		_music_box_2.global_position = _ouz.global_position
		_music_box_2.max_distance = 100.0
		_music_box_2.unit_size = 12.0
		_music_box_2.volume_db = AudioSettings.MUTED_DB
		_music_box_2.max_db = AudioSettings.MUSIC_BOX_MAX_DB
		_music_box_2.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		if _music_box_2.stream is AudioStreamOggVorbis:
			(_music_box_2.stream as AudioStreamOggVorbis).loop = true
	_music_box.global_position = _ouz.global_position
	_music_box.max_distance = 100.0
	_music_box.unit_size = 12.0
	_music_box.volume_db = AudioSettings.MUTED_DB
	_music_box.max_db = AudioSettings.MUSIC_BOX_MAX_DB
	_music_box.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_music_box_late.bus = "MusicBoxLateEcho"
	_music_box_late.volume_db = AudioSettings.MUSIC_BOX_LATE_DB
	_music_box_late.max_db = AudioSettings.MUSIC_BOX_MAX_DB
	_music_box_late.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if _first_knock_sound:
		if _first_knock_sound.stream == null:
			_first_knock_sound.stream = FIRST_KNOCK_SOUND
		_first_knock_sound.max_distance = 100.0
		_first_knock_sound.unit_size = 20.0
	if _jumpscare_sound:
		if _jumpscare_sound.stream == null:
			_jumpscare_sound.stream = JUMPSCARE_SOUND
		_jumpscare_sound.volume_db = AudioSettings.JUMPSCARE_DB
		_jumpscare_sound.bus = AudioSettings.ensure_jumpscare_bus()
		_jumpscare_sound.process_mode = Node.PROCESS_MODE_ALWAYS
		if _jumpscare_sound is AudioStreamPlayer3D:
			var scare_3d := _jumpscare_sound as AudioStreamPlayer3D
			scare_3d.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
			scare_3d.max_distance = 100.0
			scare_3d.unit_size = 20.0
	if _music_box.stream is AudioStreamOggVorbis:
		(_music_box.stream as AudioStreamOggVorbis).loop = true
	_update_music_bus()
	_music_box.play()
	_camera_ui.set_music_box_alt_active(false)
	_camera_ui.set_song_request_state(false, 0.0)
	_camera_ui.set_music_box_enabled(true)
	_camera_ui.set_music_box_charge(_charge)
	if _game:
		_game.night_won.connect(_on_game_finished)
		_game.night_lost.connect(_on_game_finished)


func _schedule_next_song_request() -> void:
	_next_request_timer = Difficulties.random_time(Difficulties.OUZ, &"song_change_request_interval_min", &"song_change_request_interval_max")


func set_charge_drain_multiplier(multiplier: float) -> void:
	_charge_drain_multiplier = maxf(multiplier, 0.0)


func _process(delta: float) -> void:
	if _ended or _awake or _sequence_running:
		return
	if debug_mode:
		_charge = 1.0
		_camera_ui.set_music_box_charge(_charge)
		_update_music_bus()
		return
	if _camera_ui.is_music_box_winding():
		_charge = minf(_charge + delta / maxf(Difficulties.time(Difficulties.OUZ, &"full_wind_seconds"), 0.1), 1.0)
	else:
		_charge = maxf(_charge - delta / maxf(Difficulties.time(Difficulties.OUZ, &"charge_drain_seconds"), 0.1) * _charge_drain_multiplier, 0.0)
	_camera_ui.set_music_box_charge(_charge)
	_update_music_bus()
	if _charge <= 0.0 and not _late_start_pending:
		_force_classic_late_from_music_box()
		return
	if _late_start_pending:
		return

	if _request_active:
		var dur := maxf(Difficulties.time(Difficulties.OUZ, &"song_change_request_duration"), 0.1)
		_request_left = maxf(_request_left - delta, 0.0)
		var progress := _request_left / dur
		_camera_ui.set_song_request_state(true, progress)
		if _request_left <= 0.0:
			_request_active = false
			_camera_ui.set_song_request_state(false, 0.0)
			if _late_start_pending:
				_schedule_next_song_request()
			else:
				_force_classic_late_from_music_box()
				return
	else:
		if _request_waiting_for_cameras:
			if _camera_ui.is_camera_feed_active():
				_start_song_change_request()
		else:
			_next_request_timer = maxf(_next_request_timer - delta, 0.0)
			if _next_request_timer <= 0.0:
				if _camera_ui.is_camera_feed_active():
					_start_song_change_request()
				else:
					_request_waiting_for_cameras = true


func _start_song_change_request() -> void:
	if _ended or _awake or _sequence_running or _late_start_pending or debug_mode or _request_active:
		_request_waiting_for_cameras = false
		return
	_request_waiting_for_cameras = false
	_request_active = true
	_request_left = maxf(Difficulties.time(Difficulties.OUZ, &"song_change_request_duration"), 0.1)
	_camera_ui.set_song_request_state(true, 1.0)


func _on_music_change_requested() -> void:
	if _ended or _awake or _sequence_running:
		return
	_alt_song_active = not _alt_song_active
	_camera_ui.set_music_box_alt_active(_alt_song_active)
	_switch_active_song_player()
	_update_music_bus()

	if _request_active:
		_request_active = false
		_request_left = 0.0
		_camera_ui.set_song_request_state(false, 0.0)
		_schedule_next_song_request()
		return

	if not _late_start_pending:
		_late_start_pending = true
		await get_tree().create_timer(Difficulties.random_time(Difficulties.OUZ, &"music_change_late_delay_min", &"music_change_late_delay_max")).timeout
		if _ended or _awake or _sequence_running:
			_late_start_pending = false
			return
		_force_classic_late_from_music_box()
		_late_start_pending = false


func _switch_active_song_player() -> void:
	var active_player := _get_active_song_player()
	var inactive_player := _music_box_2 if active_player == _music_box else _music_box
	if inactive_player and inactive_player != active_player and is_instance_valid(inactive_player) and inactive_player.playing:
		inactive_player.stream_paused = true
	if active_player and is_instance_valid(active_player):
		active_player.global_position = _ouz.global_position
		if active_player.stream is AudioStreamOggVorbis:
			(active_player.stream as AudioStreamOggVorbis).loop = true
		active_player.stream_paused = false
		if not active_player.playing and active_player.stream != null:
			active_player.play()


func _get_active_song_player() -> AudioStreamPlayer3D:
	if _alt_song_active and _music_box_2 and is_instance_valid(_music_box_2):
		return _music_box_2
	return _music_box


func _force_classic_late_from_music_box() -> void:
	_request_active = false
	_request_waiting_for_cameras = false
	_request_left = 0.0
	_alt_song_active = false
	_camera_ui.set_music_box_alt_active(false)
	_camera_ui.set_song_request_state(false, 0.0)
	if _music_box and is_instance_valid(_music_box):
		_music_box.stop()
	if _music_box_2 and is_instance_valid(_music_box_2):
		_music_box_2.stop()
	_begin_wake_sequence()


func _begin_wake_sequence() -> void:
	if _sequence_running or _awake or _ended:
		return
	_sequence_running = true
	_awake = true
	_request_active = false
	_request_waiting_for_cameras = false
	_request_left = 0.0
	_start_dread_environment_fade()
	_camera_ui.set_song_request_state(false, 0.0)
	_camera_ui.set_music_box_late_active(true)
	_camera_ui.set_music_box_enabled(false, true)
	_music_box.stop()
	if _music_box_2:
		_music_box_2.stop()
	_music_box_late.global_position = _ouz.global_position
	_music_box_late.max_distance = 100.0
	_music_box_late.unit_size = 12.0
	if _music_box_late.stream is AudioStreamOggVorbis:
		(_music_box_late.stream as AudioStreamOggVorbis).loop = true
	_music_box_late.play()
	if _player_camera:
		_player_camera.shake(0.035, 2.0)
	_update_music_bus()
	var wake_delay := Difficulties.random_time(Difficulties.OUZ, &"wake_delay_min", &"wake_delay_max")
	if wake_delay > 0.0:
		await get_tree().create_timer(wake_delay).timeout
	if _ended:
		return

	await _play_pose_with_signal(AWAKE_POSE, true)
	await _wait_commonroom_pose_change()
	if _ended:
		return
	if _room == "commonroom" and _spots and _spots.get_node_or_null("ouzSpot_commonroom2"):
		await _teleport_with_signal("commonroom2", STANDING_POSE, 1.0, true)
		_room = "commonroom"
	else:
		await _play_pose_with_signal(STANDING_POSE, true)
	await _wait_commonroom_pose_change()
	if _ended:
		return

	await _teleport_with_signal("southhall", STANDING_POSE, 1.0, true)
	if _ended:
		return
	await _wait_in_room()
	if _ended:
		return

	var has_door_window_access := await _wait_for_door_window_access()
	if not has_door_window_access:
		return

	await _walk_to_room_with_signal("preSouthhall", STANDING_POSE, Difficulties.time(Difficulties.OUZ, &"office_approach_walk_seconds"))
	if _ended:
		return
	await get_tree().create_timer(Difficulties.time(Difficulties.OUZ, &"door_window_pre_wait_seconds")).timeout
	if _ended:
		return
	await _walk_to_room("preDoorWindow", STANDING_POSE, Difficulties.time(Difficulties.OUZ, &"office_approach_walk_seconds"))
	if _ended:
		return
	await _walk_to_room("DoorWindow", STANDING_POSE, Difficulties.time(Difficulties.OUZ, &"office_approach_walk_seconds"))
	if _ended:
		return

	var door_already_broken := _door != null and is_instance_valid(_door) and _door.is_broken
	if door_already_broken:
		var broken_wait := Difficulties.random_time(Difficulties.OUZ, &"broken_door_wait_min", &"broken_door_wait_max")
		if broken_wait > 0.0:
			await get_tree().create_timer(broken_wait).timeout
		if _ended:
			return
	else:
		var kick_delay := Difficulties.random_time(Difficulties.OUZ, &"door_window_kick_delay_min", &"door_window_kick_delay_max")
		if kick_delay > 0.0:
			await get_tree().create_timer(kick_delay).timeout
		if _ended:
			return

		_lock_and_exit_camera_on_kick()
		_set_pose(KICKING_POSE)
		_break_door_stage3()
		_shake_camera_on_door_kick(0.7, 0.6)

		await get_tree().create_timer(Difficulties.time(Difficulties.OUZ, &"kick_pose_display_seconds")).timeout
		if _ended:
			return

		_set_pose(STANDING_POSE)
		var stand_wait := Difficulties.random_time(Difficulties.OUZ, &"post_break_jumpscare_delay_min", &"post_break_jumpscare_delay_max")
		if stand_wait > 0.0:
			await get_tree().create_timer(stand_wait).timeout
		if _ended:
			return

	_sequence_running = false
	_set_pose(JUMPSCARE_POSE)
	await _walk_to_camera_xz_in_jumpscare_pose(0.08)
	if _ended:
		return
	await _start_jumpscare(door_already_broken)


func _lock_and_exit_camera_on_kick() -> void:
	if not _camera_ui or not is_instance_valid(_camera_ui):
		return
	_camera_ui.lock_cams("ouz_kicking")
	if _camera_ui.is_open():
		if _camera_ui.has_method("force_close"):
			_camera_ui.force_close()
		elif _camera_ui.has_method("interrupt_for_jumpscare"):
			_camera_ui.interrupt_for_jumpscare()


func _shake_camera_on_door_kick(intensity: float, duration: float) -> void:
	if not _player_camera or not is_instance_valid(_player_camera):
		return
	if _camera_ui and is_instance_valid(_camera_ui) and _camera_ui.is_open():
		return
	if _player_camera.has_method("shake"):
		_player_camera.shake(intensity, duration)
	var base_pos := _player_camera.position
	var base_rot := _player_camera.rotation
	var elapsed := 0.0
	var shake_dur := maxf(duration, 0.05)
	while elapsed < shake_dur and not _ended:
		await get_tree().process_frame
		if not is_instance_valid(_player_camera):
			return
		elapsed += get_process_delta_time()
		var decay := 1.0 - clampf(elapsed / shake_dur, 0.0, 1.0)
		var jitter := intensity * 0.08 * decay
		_player_camera.position = base_pos + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)
		) * jitter
		var rot_jitter := deg_to_rad(10.0 * intensity * decay)
		_player_camera.rotation = base_rot + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)
		) * rot_jitter
	if is_instance_valid(_player_camera):
		_player_camera.position = base_pos
		_player_camera.rotation = base_rot


func _setup_world_environment() -> void:
	if not _world_env or not is_instance_valid(_world_env):
		return
	_env = _world_env.environment
	if not _env:
		_env = Environment.new()
		_world_env.environment = _env
	if _env_initialized:
		return
	_init_bg_color = _env.background_color
	_init_fog_enabled = _env.fog_enabled
	_init_fog_color = _env.fog_light_color
	_init_fog_density = _env.fog_density
	_env_initialized = true


func _setup_map_lights(world: Node) -> void:
	var already_captured := not _map_lights.is_empty() and _map_lights.size() == _init_light_colors.size()
	var lights_parent := world.find_child("isiklar", true, false) as Node
	if not already_captured:
		_map_lights.clear()
		_init_light_colors.clear()
	for idx in range(1, MAP_LIGHT_COUNT + 1):
		var light_name := "isiks%d" % idx
		var light_node: Light3D = null
		if lights_parent:
			light_node = lights_parent.find_child(light_name, true, false) as Light3D
		if not light_node:
			light_node = world.find_child(light_name, true, false) as Light3D
		if light_node and not already_captured:
			_map_lights.append(light_node)
			_init_light_colors.append(light_node.light_color)


func _tint_color_blue(base_color: Color, strength: float) -> Color:
	var s := clampf(strength, 0.0, 1.0)
	var tinted := base_color.lerp(Color(0.55, 0.78, 1.0, base_color.a), s)
	tinted.r = minf(tinted.r, base_color.r * lerp(1.0, 0.85, s))
	tinted.g = minf(tinted.g, base_color.g * lerp(1.0, 0.95, s))
	tinted.b = maxf(tinted.b, base_color.b)
	return tinted


func _reset_dread_environment_and_lights() -> void:
	if _dread_tween and _dread_tween.is_valid():
		_dread_tween.kill()
		_dread_tween = null

	if _env and _env_initialized:
		if _env.background_mode == Environment.BG_COLOR:
			_env.background_color = _init_bg_color
		_env.fog_enabled = _init_fog_enabled
		_env.fog_light_color = _init_fog_color
		_env.fog_density = _init_fog_density

	for i in range(mini(_map_lights.size(), _init_light_colors.size())):
		var light_node := _map_lights[i]
		if light_node and is_instance_valid(light_node):
			light_node.light_color = _init_light_colors[i]


func _start_dread_environment_fade() -> void:
	var duration := maxf(dread_env_fade_seconds, 0.1)
	if _dread_tween and _dread_tween.is_valid():
		_dread_tween.kill()

	var has_env := _env != null
	if not has_env:
		_setup_world_environment()
		has_env = _env != null

	if has_env:
		if _env.background_mode == Environment.BG_COLOR:
			_env.background_color = _init_bg_color
		_env.fog_enabled = true
		_env.fog_light_color = _init_fog_color if _init_fog_enabled else dread_fog_color
		_env.fog_density = _init_fog_density if _init_fog_enabled else 0.0

	for i in range(mini(_map_lights.size(), _init_light_colors.size())):
		var light_node := _map_lights[i]
		if light_node and is_instance_valid(light_node):
			light_node.light_color = _init_light_colors[i]

	if not has_env and _map_lights.is_empty():
		return

	_dread_tween = create_tween()
	_dread_tween.set_parallel(true)
	_dread_tween.set_trans(Tween.TRANS_SINE)
	_dread_tween.set_ease(Tween.EASE_IN_OUT)

	if has_env:
		if _env.background_mode == Environment.BG_COLOR:
			var target_bg := _init_bg_color.lerp(dread_bg_color, dread_blue_tint)
			_dread_tween.tween_property(_env, "background_color", target_bg, duration)
		var target_fog_color := _tint_color_blue(
			_init_fog_color if _init_fog_enabled else dread_fog_color,
			dread_blue_tint
		)
		var target_fog_density := maxf(_init_fog_density, dread_fog_density) if _init_fog_enabled else dread_fog_density
		_dread_tween.tween_property(_env, "fog_light_color", target_fog_color, duration)
		_dread_tween.tween_property(_env, "fog_density", target_fog_density, duration)

	for i in range(mini(_map_lights.size(), _init_light_colors.size())):
		var light_node := _map_lights[i]
		if light_node and is_instance_valid(light_node):
			var target_light := _tint_color_blue(_init_light_colors[i], dread_blue_tint)
			_dread_tween.tween_property(light_node, "light_color", target_light, duration)


func _break_door_stage3() -> void:
	if _door_break_sound and is_instance_valid(_door_break_sound):
		_door_break_sound.stop()
		if _door_break_sound.stream != null:
			_door_break_sound.pitch_scale = randf_range(0.8, 1.2)
			_door_break_sound.play()
	if _first_knock_sound and is_instance_valid(_first_knock_sound):
		_first_knock_sound.stop()
		if _first_knock_sound.stream != null:
			_first_knock_sound.pitch_scale = randf_range(0.8, 1.2)
			_first_knock_sound.play()
	if not _door or not is_instance_valid(_door):
		return
	var from_spot := _get_spot_node("DoorKnock")
	if not from_spot:
		from_spot = _get_spot_node("DoorWindow")
	var to_spot := _get_spot_node("Inside1")
	if not to_spot:
		to_spot = _get_spot_node("JumpscareOffice")
	var dir := Vector3.FORWARD
	if from_spot and to_spot:
		dir = to_spot.global_position - from_spot.global_position
		dir.y = 0.0
	if dir.is_zero_approx():
		dir = -_ouz.global_transform.basis.z
		dir.y = 0.0
	if not _door.is_broken:
		_door.set_stage(2)
		_door.break_door(dir)


func _wait_in_room() -> void:
	await get_tree().create_timer(Difficulties.random_time(Difficulties.OUZ, &"room_wait_min", &"room_wait_max")).timeout


func _wait_for_door_window_access() -> bool:
	var coordinator := get_parent()
	if not is_instance_valid(coordinator) or not coordinator.has_method("try_reserve_door_window"):
		push_error("OuzAI: DoorWindow rezervasyon kontrolcüsü bulunamadı.")
		return false
	while not _ended:
		if coordinator.call("try_reserve_door_window", self) == true:
			return true
		await _wait_in_room()
	return false


func _release_door_window() -> void:
	var coordinator := get_parent()
	if is_instance_valid(coordinator) and coordinator.has_method("release_door_window"):
		coordinator.call("release_door_window", self)


func _wait_commonroom_pose_change() -> void:
	await get_tree().create_timer(Difficulties.random_time(Difficulties.OUZ, &"commonroom_pose_wait_min", &"commonroom_pose_wait_max")).timeout


func _play_pose_with_signal(pose_name: String, sync_transforming: bool = false) -> void:
	if _camera_ui:
		var transition_finished: Signal = _camera_ui.lost_signal_finished
		_camera_ui.play_lost_signal(Callable(self, "_set_pose").bind(pose_name))
		if sync_transforming:
			_play_transforming_sound()
		await transition_finished
	else:
		_set_pose(pose_name)
		if sync_transforming:
			_play_transforming_sound()


func _teleport_with_signal(
	room_name: String,
	pose_name: String,
	duration_multiplier: float = 1.0,
	sync_transforming: bool = false
) -> void:
	if _camera_ui:
		if not _camera_ui.is_camera_feed_active() and duration_multiplier > 1.0:
			_teleport_to(room_name, pose_name)
			if sync_transforming:
				_play_transforming_sound()
			var transition_time := (_camera_ui.lost_signal_time + _camera_ui.pending_after_lost_time) * duration_multiplier
			await get_tree().create_timer(transition_time).timeout
			return
		var transition_finished: Signal = _camera_ui.lost_signal_finished
		_camera_ui.play_lost_signal(Callable(self, "_teleport_to").bind(room_name, pose_name), duration_multiplier)
		if sync_transforming:
			_play_transforming_sound()
		await transition_finished
	else:
		_teleport_to(room_name, pose_name)
		if sync_transforming:
			_play_transforming_sound()


func _teleport_to(room_name: String, pose_name: String) -> void:
	var spot := _get_spot_node(room_name)
	if not spot:
		push_warning("OuzAI: %s spotu bulunamadı." % room_name)
		return
	var next_transform := spot.global_transform
	next_transform.basis = next_transform.basis.orthonormalized().scaled(_ouz_scale)
	_ouz.global_transform = next_transform
	_room = room_name
	_set_pose(pose_name)
	_music_box.global_position = _ouz.global_position
	if _music_box_2:
		_music_box_2.global_position = _ouz.global_position
	_music_box_late.global_position = _ouz.global_position


func _walk_to_room(room_name: String, pose_name: String, duration: float) -> void:
	var spot := _get_walk_marker(room_name)
	if not spot:
		push_warning("OuzAI: %s yürüyüş marker'ı bulunamadı." % room_name)
		return
	await _walk_to_marker(spot, room_name, pose_name, duration)


func _get_walk_marker(room_name: String) -> Node3D:
	return _get_spot_node(room_name)


func _get_spot_node(spot_key: String) -> Node3D:
	if _spots:
		var direct := _spots.get_node_or_null("ouzSpot_" + spot_key) as Node3D
		if direct:
			return direct
		var plain := _spots.get_node_or_null(spot_key) as Node3D
		if plain:
			return plain
	var root := get_tree().root
	var fallback := root.find_child("ouzSpot_" + spot_key, true, false) as Node3D
	if fallback:
		return fallback
	return root.find_child(spot_key, true, false) as Node3D


func _walk_to_marker(spot: Node3D, room_name: String, pose_name: String, duration: float) -> void:
	if not spot:
		push_warning("OuzAI: %s yürüyüş marker'ı bulunamadı." % room_name)
		return
	var start_xf := _ouz.global_transform
	var target_xf := spot.global_transform
	var start_basis := start_xf.basis.orthonormalized()
	var target_basis := target_xf.basis.orthonormalized()
	var elapsed := 0.0
	var travel_time := maxf(duration, 0.01)
	while elapsed < travel_time and not _ended:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / travel_time, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var walking_xf := Transform3D.IDENTITY
		walking_xf.origin = start_xf.origin.lerp(target_xf.origin, t)
		walking_xf.basis = start_basis.slerp(target_basis, t).scaled(_ouz_scale)
		_ouz.global_transform = walking_xf
	if _ended:
		return
	target_xf.basis = target_basis.scaled(_ouz_scale)
	_ouz.global_transform = target_xf
	_room = room_name
	_set_pose(pose_name)
	_music_box.global_position = _ouz.global_position
	if _music_box_2:
		_music_box_2.global_position = _ouz.global_position
	_music_box_late.global_position = _ouz.global_position


func _walk_to_room_with_signal(room_name: String, pose_name: String, duration: float) -> void:
	var spot := _get_walk_marker(room_name)
	if not spot:
		push_warning("OuzAI: %s yürüyüş marker'ı bulunamadı." % room_name)
		return
	if _camera_ui:
		var transition_finished: Signal = _camera_ui.lost_signal_finished
		_camera_ui.play_lost_signal(
			Callable(self, "_walk_to_marker").bind(spot, room_name, pose_name, duration)
		)
		await transition_finished
	else:
		await _walk_to_marker(spot, room_name, pose_name, duration)


func _set_pose(pose_name: String) -> void:
	if not _animation or not is_instance_valid(_animation):
		return
	var resolved_name := _resolve_pose_animation_name(pose_name)
	if resolved_name.is_empty():
		push_warning("OuzAI: AnimationPlayerOuz/%s animasyonu bulunamadı." % pose_name)
		return
	if _animation.has_animation("RESET") and resolved_name != "RESET":
		_animation.play("RESET", 0.0)
		_animation.advance(0.0)
	_animation.play(resolved_name, 0.0)
	_animation.advance(0.0)


func _resolve_pose_animation_name(pose_name: String) -> String:
	if _animation.has_animation(pose_name):
		return pose_name
	for anim_name: StringName in _animation.get_animation_list():
		var s := String(anim_name)
		if s.to_lower() == pose_name.to_lower() or s.to_lower().ends_with("/" + pose_name.to_lower()):
			return s
	return ""


func _ensure_transforming_bus() -> void:
	var bus_idx := _ensure_bus(TRANSFORMING_BUS_NAME)
	if bus_idx < 0:
		return
	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		_transforming_reverb = AudioEffectReverb.new()
		_transforming_reverb.room_size = TRANSFORMING_REVERB_ROOM_SIZE
		_transforming_reverb.damping = TRANSFORMING_REVERB_DAMPING
		_transforming_reverb.wet = transforming_reverb_wet
		AudioServer.add_bus_effect(bus_idx, _transforming_reverb)
	else:
		_transforming_reverb = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectReverb
		if _transforming_reverb:
			_transforming_reverb.room_size = TRANSFORMING_REVERB_ROOM_SIZE
			_transforming_reverb.damping = TRANSFORMING_REVERB_DAMPING
			_transforming_reverb.wet = transforming_reverb_wet


func _configure_transforming_sound() -> void:
	if not _transforming_sound or not is_instance_valid(_transforming_sound):
		return
	if _transforming_sound is AudioStreamPlayer:
		var p2d := _transforming_sound as AudioStreamPlayer
		p2d.volume_db = AudioSettings.TRANSFORMING_DB
		if AudioServer.get_bus_index(TRANSFORMING_BUS_NAME) >= 0:
			p2d.bus = TRANSFORMING_BUS_NAME
	elif _transforming_sound is AudioStreamPlayer3D:
		var p3d := _transforming_sound as AudioStreamPlayer3D
		p3d.volume_db = AudioSettings.TRANSFORMING_DB
		p3d.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p3d.max_distance = 100.0
		p3d.unit_size = 20.0
		if AudioServer.get_bus_index(TRANSFORMING_BUS_NAME) >= 0:
			p3d.bus = TRANSFORMING_BUS_NAME


func _play_transforming_sound() -> void:
	if not _transforming_sound or not is_instance_valid(_transforming_sound):
		return
	_configure_transforming_sound()
	if _transforming_reverb:
		_transforming_reverb.room_size = TRANSFORMING_REVERB_ROOM_SIZE
		_transforming_reverb.damping = TRANSFORMING_REVERB_DAMPING
		_transforming_reverb.wet = transforming_reverb_wet
	if _transforming_sound is AudioStreamPlayer:
		var p2d := _transforming_sound as AudioStreamPlayer
		p2d.stop()
		if p2d.stream != null:
			p2d.play()
	elif _transforming_sound is AudioStreamPlayer3D:
		var p3d := _transforming_sound as AudioStreamPlayer3D
		if _audio_listener and is_instance_valid(_audio_listener):
			p3d.global_position = _audio_listener.global_position
		p3d.stop()
		if p3d.stream != null:
			p3d.play()


func _walk_to_camera_xz_in_jumpscare_pose(custom_duration: float = -1.0) -> void:
	if _ended or not _ouz or not is_instance_valid(_ouz):
		return
	_set_pose(JUMPSCARE_POSE)
	if not _player_camera or not is_instance_valid(_player_camera):
		return
	var start_xf := _ouz.global_transform
	var start_basis := start_xf.basis.orthonormalized()
	var cam_pos := _player_camera.global_position
	var target_origin := Vector3(cam_pos.x, start_xf.origin.y, cam_pos.z)
	var travel_vec := target_origin - start_xf.origin
	travel_vec.y = 0.0
	var target_basis := start_basis
	if not travel_vec.is_zero_approx():
		target_basis = Basis.looking_at(travel_vec.normalized(), Vector3.UP)
	var elapsed := 0.0
	var chosen_duration := custom_duration if custom_duration > 0.0 else camera_approach_walk_seconds
	var travel_time := maxf(chosen_duration, 0.01)
	while elapsed < travel_time and not _ended:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / travel_time, 0.0, 1.0)
		var cur_cam := _player_camera.global_position
		var cur_target := Vector3(cur_cam.x, start_xf.origin.y, cur_cam.z)
		var step_xf := Transform3D.IDENTITY
		step_xf.origin = start_xf.origin.lerp(cur_target, t)
		step_xf.basis = start_basis.slerp(target_basis, t).scaled(_ouz_scale)
		_ouz.global_transform = step_xf
		_set_pose(JUMPSCARE_POSE)
	if _ended:
		return
	var final_cam := _player_camera.global_position
	var end_xf := Transform3D.IDENTITY
	end_xf.origin = Vector3(final_cam.x, start_xf.origin.y, final_cam.z)
	end_xf.basis = target_basis.scaled(_ouz_scale)
	_ouz.global_transform = end_xf
	_set_pose(JUMPSCARE_POSE)


func _start_jumpscare(door_was_already_broken: bool = false) -> void:
	if _ended:
		return
	if _camera_ui and is_instance_valid(_camera_ui):
		_camera_ui.set_input_blocked(true)
	var player_hidden := _hide_controller != null and _hide_controller.is_concealed()
	var jumpscare_spot_name := "JumpscareDesk" if player_hidden else "JumpscareOffice"
	var target_spot := _get_spot_node(jumpscare_spot_name)
	if target_spot:
		_teleport_to(jumpscare_spot_name, JUMPSCARE_POSE)
	else:
		_room = jumpscare_spot_name
		_set_pose(JUMPSCARE_POSE)
	_ended = true
	_release_door_window()
	_reset_dread_environment_and_lights()
	var was_watching_cameras := _camera_ui != null and _camera_ui.is_open()
	if _camera_ui:
		_camera_ui.hide_mobile_exit_button()
		_camera_ui.set_mobile_hide_exit_mode(false)
		_camera_ui.lock_cams("jumpscare")
		if was_watching_cameras:
			_camera_ui.interrupt_for_jumpscare()
	if _player_camera:
		var scare_cam_is_usable := false
		if not player_hidden:
			_scare_camera = _resolve_scare_camera()
			scare_cam_is_usable = _scare_camera != null and is_instance_valid(_scare_camera)
		if scare_cam_is_usable:
			if not was_watching_cameras and not door_was_already_broken:
				_player_camera.snap_to_base()
			_jumpscare_camera = _scare_camera
			_force_jumpscare_camera_current()
		else:
			_jumpscare_camera = _player_camera
			_force_jumpscare_camera_current()
		_player_camera.set_frozen(true)
		var scare_controller := _jumpscare_camera as PlayerCamera
		if scare_controller:
			scare_controller.set_frozen(true)
			scare_controller.shake(jumpscare_shake * 0.5, jumpscare_time)
	_set_pose(JUMPSCARE_POSE)
	if _jumpscare_sound and is_instance_valid(_jumpscare_sound):
		if _jumpscare_sound is AudioStreamPlayer3D:
			(_jumpscare_sound as AudioStreamPlayer3D).global_position = _ouz.global_position
		_jumpscare_sound.stop()
		if _jumpscare_sound.stream != null:
			_jumpscare_sound.play()
	if _jumpscare_camera:
		await _run_jumpscare_shake()
	if _game and is_instance_valid(_game):
		if _game.has_method("trigger_game_over_frozen"):
			await _game.trigger_game_over_frozen()
		else:
			_game.trigger_game_over()
	else:
		get_tree().reload_current_scene()


func _resolve_scare_camera() -> Camera3D:
	if _player_camera == null or not is_instance_valid(_player_camera):
		return null
	if _scare_camera != null and is_instance_valid(_scare_camera):
		if _scare_camera.get_viewport() == _player_camera.get_viewport():
			return _scare_camera
	var scene_root := get_tree().current_scene if get_tree() else null
	if scene_root:
		for candidate: Node in scene_root.find_children("ScareCam", "Camera3D", true, false):
			var camera := candidate as Camera3D
			if camera and camera.get_viewport() == _player_camera.get_viewport():
				return camera
	return null


func _force_jumpscare_camera_current() -> void:
	if _jumpscare_camera == null or not is_instance_valid(_jumpscare_camera):
		return
	var camera_viewport := _jumpscare_camera.get_viewport()
	if camera_viewport:
		for candidate: Node in camera_viewport.find_children("*", "Camera3D", true, false):
			var other_camera := candidate as Camera3D
			if other_camera and other_camera != _jumpscare_camera and other_camera.current:
				other_camera.current = false
	_jumpscare_camera.current = true
	_jumpscare_camera.make_current()
	if camera_viewport and camera_viewport.get_camera_3d() != _jumpscare_camera:
		_jumpscare_camera.call_deferred("make_current")


func _run_jumpscare_shake() -> void:
	var start_position := _ouz.global_position
	var target_position := _jumpscare_camera.global_position
	var base_camera_position := _jumpscare_camera.position
	var base_camera_rotation := _jumpscare_camera.rotation
	var base_h_offset := _jumpscare_camera.h_offset
	var base_v_offset := _jumpscare_camera.v_offset
	var elapsed := 0.0
	var pos_shake := jumpscare_shake * 0.25
	var offset_shake := jumpscare_shake * 0.35
	while elapsed < jumpscare_time:
		await get_tree().process_frame
		_force_jumpscare_camera_current()
		elapsed += get_process_delta_time()
		var progress := clampf(elapsed / jumpscare_time, 0.0, 1.0)
		_ouz.global_position = start_position.lerp(target_position, jumpscare_lunge * progress)
		_jumpscare_camera.position = base_camera_position + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
		) * pos_shake
		var angle := deg_to_rad(jumpscare_rotation_shake_deg)
		_jumpscare_camera.rotation = base_camera_rotation + Vector3(
			randf_range(-angle, angle), randf_range(-angle, angle), randf_range(-angle * 0.75, angle * 0.75)
		)
		if _jumpscare_camera != _player_camera:
			_jumpscare_camera.h_offset = base_h_offset + randf_range(-offset_shake, offset_shake)
			_jumpscare_camera.v_offset = base_v_offset + randf_range(-offset_shake, offset_shake)

	_jumpscare_camera.position = base_camera_position
	_jumpscare_camera.rotation = base_camera_rotation
	var scare_controller := _jumpscare_camera as PlayerCamera
	if scare_controller:
		scare_controller.reset_shake()
	else:
		_jumpscare_camera.h_offset = base_h_offset
		_jumpscare_camera.v_offset = base_v_offset


func _update_music_bus() -> void:
	var feed_active := _camera_ui.is_camera_feed_active()
	var camera_index := _camera_ui.get_current_camera_index()
	var is_echo_camera := camera_index == MUSIC_BOX_ECHO_CAMERA
	var is_remote_camera := MUSIC_BOX_REMOTE_CAMERAS.has(camera_index)
	var target_bus := "MusicBoxEcho" if is_echo_camera else "MusicBoxMuffledEcho"
	var target_db := AudioSettings.MUTED_DB
	if feed_active and is_echo_camera:
		target_db = AudioSettings.MUSIC_BOX_CAM11_DB
	elif feed_active and is_remote_camera:
		match camera_index:
			9:
				target_db = AudioSettings.MUSIC_BOX_CAM10_DB
			8:
				target_db = AudioSettings.MUSIC_BOX_CAM9_DB
			11:
				target_db = AudioSettings.MUSIC_BOX_CAM6B_DB
	if feed_active and _alt_song_active:
		match camera_index:
			10:
				target_db = AudioSettings.MUSIC_CHANGED_CAM11_DB
			9:
				target_db = AudioSettings.MUSIC_CHANGED_CAM10_DB
			8:
				target_db = AudioSettings.MUSIC_CHANGED_CAM9_DB
			11:
				target_db = AudioSettings.MUSIC_CHANGED_CAM6B_DB
	var active_player := _get_active_song_player()
	var other_player := _music_box_2 if active_player == _music_box else _music_box
	if active_player and is_instance_valid(active_player):
		active_player.bus = target_bus
		active_player.volume_db = target_db
	if other_player and is_instance_valid(other_player):
		other_player.bus = target_bus
		other_player.volume_db = AudioSettings.MUTED_DB


func _on_camera_system_opened() -> void:
	_set_office_ambience_reduced(true)


func _on_camera_system_closed() -> void:
	_set_office_ambience_reduced(false)


func _set_office_ambience_reduced(reduced: bool) -> void:
	if not _office_ambience or not is_instance_valid(_office_ambience):
		return
	_office_ambience.volume_db = AudioSettings.OFFICE_AMBIENCE_MONITOR_DB if reduced else AudioSettings.OFFICE_AMBIENCE_DB


func _ensure_music_buses() -> void:
	var late_echo_bus := _ensure_bus("MusicBoxLateEcho")
	if late_echo_bus >= 0 and AudioServer.get_bus_effect_count(late_echo_bus) == 0:
		var late_reverb := AudioEffectReverb.new()
		late_reverb.room_size = 0.9
		late_reverb.damping = 0.1
		late_reverb.wet = 0.5
		AudioServer.add_bus_effect(late_echo_bus, late_reverb)
	var echo_bus := _ensure_bus("MusicBoxEcho")
	if echo_bus >= 0 and AudioServer.get_bus_effect_count(echo_bus) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.72
		reverb.damping = 0.58
		reverb.wet = 0.4
		AudioServer.add_bus_effect(echo_bus, reverb)
	var muffled_echo_bus := _ensure_bus("MusicBoxMuffledEcho")
	if muffled_echo_bus >= 0 and AudioServer.get_bus_effect_count(muffled_echo_bus) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.72
		reverb.damping = 0.58
		reverb.wet = 0.3
		AudioServer.add_bus_effect(muffled_echo_bus, reverb)
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 1750.0
		AudioServer.add_bus_effect(muffled_echo_bus, low_pass)


func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index


func _on_game_finished() -> void:
	_ended = true
	_request_active = false
	_request_waiting_for_cameras = false
	_reset_dread_environment_and_lights()
	_camera_ui.set_song_request_state(false, 0.0)
	_camera_ui.set_music_box_late_active(false)
	_camera_ui.set_music_box_enabled(false)
	_music_box.stop()
	if _music_box_2:
		_music_box_2.stop()
	_music_box_late.stop()
	set_process(false)


func _on_lure_requested(cam_index: int) -> void:
	if cam_index < 0 or cam_index >= LURE_CAM_ROOMS.size() or _lure_sounds.is_empty():
		return
	var player: AudioStreamPlayer3D = _lure_sounds.pick_random()
	var spot := _monster_spots.get_node_or_null("Spot_" + LURE_CAM_ROOMS[cam_index]) as Node3D if _monster_spots else null
	if spot:
		player.global_position = spot.global_position
	player.stop()
	player.play()
