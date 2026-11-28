extends Node

const FIRST_KNOCK_SOUND: AudioStream = preload("res://audio/knockfirst.wav")
const JUMPSCARE_SOUND: AudioStream = preload("res://audio/jumpscare.wav")
const OUZ_MODULE_SCRIPT: Script = preload("res://ouz_ai.gd")
const MAYINMELIH_INSIDE_CHARGE_DRAIN_MULTIPLIER: float = 0.05
const LEAVE_FEAR_HOLD_MIN: float = 3.0
const LEAVE_FEAR_HOLD_MAX: float = 6.0
const LEAVE_FEAR_FADE_OUT_TIME: float = 1.2

enum State { SLEEP, ROAM, DOOR, INSIDE, JUMPSCARE, DONE }

const CAM_ROOMS: PackedStringArray = [
	"fireescape", "storage", "northhall", "janitorcloset", "backstage",
	"frontauditorium", "coliseum", "westhall", "southhall", "tearoom",
	"commonroom", "auditoriumenterance", "auditorium"
]
const DOOR_WINDOW_LURE_ROOMS: PackedStringArray = ["westhall", "southhall"]

const LINKS: Dictionary = {
	"fireescape": ["janitorcloset", "northhall"],
	"storage": ["northhall", "backstage", "janitorcloset"],
	"northhall": ["storage", "frontauditorium", "backstage", "janitorcloset"],
	"janitorcloset": ["northhall", "fireescape", "backstage", "westhall"],
	"backstage": ["northhall", "frontauditorium", "janitorcloset"],
	"frontauditorium": ["auditorium", "auditoriumenterance", "backstage"],
	"auditoriumenterance": ["frontauditorium", "auditorium", "commonroom", "southhall"],
	"auditorium": ["frontauditorium", "auditoriumenterance"],
	"coliseum": ["westhall", "southhall", "tearoom"],
	"westhall": ["southhall", "coliseum", "tearoom", "janitorcloset"],
	"southhall": ["tearoom", "commonroom", "westhall", "coliseum", "auditoriumenterance"],
	"tearoom": ["commonroom", "southhall", "coliseum", "westhall"],
	"commonroom": ["tearoom", "southhall", "auditoriumenterance"],
}

@export_group("Rota")
@export var door_rooms: PackedStringArray = ["westhall", "southhall"]
@export var roam_pose: String = "pose_stand"
@export var symmetric_links: bool = true
@export_range(0.0, 1.0) var door_bias: float = 0.7
@export_range(0.0, 1.0) var forward_bias: float = 0.7
@export var retreat_min_distance: int = 3

@export_group("Zamanlama")
@export_range(1.0, 8.0, 0.25) var roam_speed_multiplier: float = 3.0
@export_range(0.0, 1.0) var door_window_lure_success_chance: float = 0.75

@export_group("Kapı Saldırısı")
@export var knocks_before_kick: int = 2

@export_group("İçeride")
@export_range(0.0, 1.0) var broken_door_hidden_kill_chance: float = 0.5
@export var notice_delay_min: float = 2.0
@export var notice_delay_max: float = 5.0
@export var search_time_min: float = 2.5
@export var search_time_max: float = 4.0

@export_group("Jumpscare")
@export var jumpscare_time: float = 1.4
@export var jumpscare_shake: float = 0.18
@export var jumpscare_rotation_shake_deg: float = 7.5
@export_range(0.0, 1.0) var jumpscare_lunge: float = 0.18

@export_group("Test")
@export var debug_mode: bool = false
@export var debug_door_attack_delay: float = -1.0

var _state: State = State.SLEEP
var _busy: bool = false
var _room: String = "backstage"
var _safe_to_unhide: bool = false
var _sleep_left: float = 0.0
var _move_left: float = 0.0
var _lure_room: String = ""
var _lure_left: float = 0.0

var _graph: Dictionary = {}
var _dist: Dictionary = {}

var _monster: Node3D
var _monster_scale: Vector3 = Vector3.ONE
var _anim: AnimationPlayer
var _door: DoorSystem
var _door_window_owner: Node
var _hide: HideController
var _player_cam: Camera3D
var _scare_cam: Camera3D
var _jumpscare_camera: Camera3D
var _cam_system: CameraSystemUI
var _game: GameManager
var _ouz_module: Node
var _audio_listener: AudioListener3D
var _lure_sounds: Array[AudioStreamPlayer3D] = []
var _knock_sound: AudioStreamPlayer3D
var _first_knock_sound: AudioStreamPlayer3D
var _break_sound: AudioStreamPlayer3D
var _scare_sound: AudioStreamPlayer3D
var _woosh_sound: AudioStreamPlayer3D
var _heartbeats_node: Node
var _breathe_node: Node
var _mayinwalks_node: Node
var _heartbeats_tween: Tween
var _breathe_tween: Tween
var _mayinwalks_tween: Tween
var _waiting_broken_door_left_turn: bool = false
var _door_window2_lure_pending: bool = false
var _broken_door_heartbeats_triggered: bool = false
var _was_camera_open_last_frame: bool = false
var _inside_patrol_active: bool = false
var _inside_chase_started: bool = false
var _inside_notice_pending: bool = false
var _office_visit_count: int = 0


func _ready() -> void:
	var scene_root := _get_search_root()
	var mayinmelih_model := _find_node_in_scene("MayinMelih") as Node3D
	var ouz_model := _find_node_in_scene("Ouz") as Node3D
	if mayinmelih_model:
		mayinmelih_model.visible = true
	if ouz_model:
		ouz_model.visible = true
	var office_ambience := _find_node_in_scene("OfficeAmbiance") as AudioStreamPlayer
	if office_ambience:
		office_ambience.volume_db = AudioSettings.OFFICE_AMBIENCE_DEFAULT_DB
		if not office_ambience.playing:
			office_ambience.play()
	if Difficulties.ouz_enabled:
		_ouz_module = OUZ_MODULE_SCRIPT.new() as Node
		_ouz_module.name = "OuzModule"
		_ouz_module.set("debug_mode", debug_mode)
		add_child(_ouz_module)
	elif ouz_model:
		_place_disabled_ouz(ouz_model, scene_root)
	var camera_ui := _find_node_in_scene("CameraSystemUI") as CameraSystemUI
	if camera_ui:
		camera_ui.set_debug_mode(debug_mode)
	if debug_mode:
		set_process(false)
		return
	if not _find_nodes():
		set_process(false)
		return
	if not Difficulties.mayinmelih_enabled:
		_place_in_room("backstage", "pose_sit")
		set_process(false)
		return

	_build_graph()
	_compute_distances()

	_place_in_room("backstage", "pose_sit")
	_state = State.SLEEP
	_sleep_left = Difficulties.random_time(Difficulties.MAYINMELIH, &"wake_delay_min", &"wake_delay_max") * _night_scale()

	if _cam_system:
		_cam_system.lure_requested.connect(_on_lure_requested)
	if _game:
		_game.night_won.connect(_on_night_over)
		_game.night_lost.connect(_on_night_over)
	if _hide:
		_hide.unhide_clicked.connect(_on_unhide_clicked)
		_hide.hidden_changed.connect(_on_hidden_changed)

	if debug_door_attack_delay >= 0.0:
		_debug_door_attack()


func _get_search_root() -> Node:
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	return get_tree().root


func _find_node_in_scene(node_name: String, preferred_viewport: Viewport = null) -> Node:
	var candidates: Array[Node] = []
	var roots: Array[Node] = []
	if get_tree() and get_tree().current_scene:
		roots.append(get_tree().current_scene)
	if get_tree() and get_tree().root and not roots.has(get_tree().root):
		roots.append(get_tree().root)

	for root_node: Node in roots:
		var matches := root_node.find_children(node_name, "", true, false)
		for m: Node in matches:
			if m and is_instance_valid(m) and not candidates.has(m):
				candidates.append(m)

	if candidates.is_empty():
		return null

	if preferred_viewport != null:
		for c: Node in candidates:
			if c.get_viewport() == preferred_viewport:
				return c

	return candidates[0]


func _call_cam_method(cam: Node, method_name: String, args: Array = []) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	if cam.has_method(method_name):
		cam.callv(method_name, args)


func _place_disabled_ouz(ouz_model: Node3D, scene_root: Node) -> void:
	var spots := (scene_root.find_child("OuzSpots", true, false) as Node3D) if scene_root else (_find_node_in_scene("OuzSpots") as Node3D)
	var start_spot := spots.get_node_or_null("ouzSpot_commonroom") as Node3D if spots else null
	if start_spot:
		var start_transform := start_spot.global_transform
		start_transform.basis = start_transform.basis.orthonormalized().scaled(
			ouz_model.global_transform.basis.get_scale()
		)
		ouz_model.global_transform = start_transform
	else:
		push_warning("MonsterAI: disabled Ouz starting spot was not found.")

	var animation := ouz_model.find_child("AnimationPlayerOuz", true, false) as AnimationPlayer
	if not animation:
		push_warning("MonsterAI: disabled Ouz AnimationPlayerOuz was not found.")
		return
	if animation.has_animation("RESET"):
		animation.play("RESET", 0.0)
		animation.advance(0.0)
	if animation.has_animation("pose_listening_commonroom"):
		animation.play("pose_listening_commonroom", 0.0)
		animation.advance(0.0)
	else:
		push_warning("MonsterAI: Ouz listening animation was not found.")


func _find_nodes() -> bool:
	_monster = _find_node_in_scene("MayinMelih") as Node3D
	if _monster:
		_anim = _monster.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_monster_scale = _monster.global_transform.basis.get_scale()
	var vp: Viewport = _monster.get_viewport() if _monster else null
	_door = _find_node_in_scene("DoorSystem", vp) as DoorSystem
	_hide = _find_node_in_scene("HideHitbox", vp) as HideController
	_player_cam = _find_node_in_scene("Camera3D", vp) as Camera3D
	if _player_cam == null:
		_player_cam = _find_node_in_scene("PlayerCamera", vp) as Camera3D
	var target_vp: Viewport = _player_cam.get_viewport() if _player_cam else vp
	_scare_cam = _find_node_in_scene("ScareCam", target_vp) as Camera3D
	if not _scare_cam:
		push_warning("MonsterAI: ScareCam sahnede bulunamadı; jumpscare mevcut oyuncu kamerasını kullanacak.")
	_cam_system = _find_node_in_scene("CameraSystemUI", target_vp) as CameraSystemUI
	_game = _find_node_in_scene("GameManager", target_vp) as GameManager
	_audio_listener = _find_node_in_scene("OfficeAudioListener", target_vp) as AudioListener3D
	if _audio_listener:
		_audio_listener.make_current()
	_lure_sounds.clear()
	for sound_name: String in ["LureSound", "LureSound2", "LureSound3"]:
		var lure_player := _find_node_in_scene(sound_name, target_vp) as AudioStreamPlayer3D
		if lure_player:
			_lure_sounds.append(lure_player)
	_knock_sound = _find_node_in_scene("KnockSound", target_vp) as AudioStreamPlayer3D
	_first_knock_sound = _find_node_in_scene("FirstKnockSound", target_vp) as AudioStreamPlayer3D
	_break_sound = _find_node_in_scene("DoorBreakSound", target_vp) as AudioStreamPlayer3D
	_scare_sound = _find_node_in_scene("JumpscareSound", target_vp) as AudioStreamPlayer3D
	_woosh_sound = _find_node_in_scene("WooshMonster", target_vp) as AudioStreamPlayer3D
	_heartbeats_node = _find_node_in_scene("HeartBeats", target_vp)
	_breathe_node = _find_node_in_scene("Breathe", target_vp)
	_mayinwalks_node = _find_node_in_scene("MayinWalks", target_vp)
	_prepare_ambient_loop_node(_heartbeats_node, AudioSettings.HEARTBEATS_DB)
	_prepare_ambient_loop_node(_breathe_node, AudioSettings.BREATHE_DB)
	_prepare_ambient_loop_node(_mayinwalks_node, AudioSettings.MAYINWALKS_DB)

	if _first_knock_sound:
		_first_knock_sound.stream = FIRST_KNOCK_SOUND
	if _scare_sound:
		_scare_sound.stream = JUMPSCARE_SOUND
	var audio_players: Array[AudioStreamPlayer3D] = _lure_sounds.duplicate()
	for sound: AudioStreamPlayer3D in [_knock_sound, _first_knock_sound, _break_sound, _scare_sound, _woosh_sound]:
		if sound:
			audio_players.append(sound)
	for sound: AudioStreamPlayer3D in audio_players:
		sound.max_distance = 4096.0
		sound.unit_size = 20.0
		sound.volume_db = AudioSettings.DEFAULT_WORLD_SFX_DB
	for lure_player: AudioStreamPlayer3D in _lure_sounds:
		lure_player.volume_db = AudioSettings.LURE_DB
		lure_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if _scare_sound:
		_scare_sound.volume_db = AudioSettings.JUMPSCARE_DB
		_scare_sound.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
		_scare_sound.bus = AudioSettings.ensure_jumpscare_bus()
		_scare_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if _woosh_sound:
		_woosh_sound.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
	if not _monster or not _anim or not _door or not _hide or not _player_cam:
		push_error("MonsterAI: gerekli düğümler bulunamadı (MayinMelih+AnimationPlayer, DoorSystem, HideHitbox, Camera3D). Scriptlerin bağlı olduğundan emin ol.")
		return false
	if not _audio_listener:
		push_warning("MonsterAI: OfficeAudioListener bulunamadı; 3D sesler sessiz kalabilir.")
	return true


func _prepare_ambient_loop_node(node: Node, target_db: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var stream: AudioStream = node.get("stream") as AudioStream
	_enable_stream_loop(stream)
	if node is AudioStreamPlayer3D:
		var p3d := node as AudioStreamPlayer3D
		p3d.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
		p3d.max_distance = 4096.0
		p3d.unit_size = 20.0
		p3d.volume_db = AudioSettings.MUTED_DB if p3d.playing else target_db
	elif node is AudioStreamPlayer:
		var p2d := node as AudioStreamPlayer
		p2d.volume_db = AudioSettings.MUTED_DB if p2d.playing else target_db


func _enable_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _fade_in_loop_sound(node: Node, target_db: float, duration: float, tween_slot: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var stream: AudioStream = node.get("stream") as AudioStream
	if stream == null:
		return
	_enable_stream_loop(stream)
	var existing_tween: Tween = get(tween_slot) as Tween
	if existing_tween:
		existing_tween.kill()
	if node is AudioStreamPlayer3D:
		var p3d := node as AudioStreamPlayer3D
		p3d.max_db = AudioSettings.WORLD_AUDIO_MAX_DB
		p3d.max_distance = 4096.0
		p3d.unit_size = 20.0
		if not p3d.playing:
			p3d.volume_db = AudioSettings.MUTED_DB
			p3d.play()
		var tw := create_tween()
		tw.tween_property(p3d, "volume_db", target_db, maxf(duration, 0.01))
		set(tween_slot, tw)
	elif node is AudioStreamPlayer:
		var p2d := node as AudioStreamPlayer
		if not p2d.playing:
			p2d.volume_db = AudioSettings.MUTED_DB
			p2d.play()
		var tw := create_tween()
		tw.tween_property(p2d, "volume_db", target_db, maxf(duration, 0.01))
		set(tween_slot, tw)


func _fade_out_loop_sound(node: Node, duration: float, tween_slot: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var existing_tween: Tween = get(tween_slot) as Tween
	if existing_tween:
		existing_tween.kill()
	var is_playing := bool(node.get("playing"))
	if not is_playing:
		return
	var tw := create_tween()
	tw.tween_property(node, "volume_db", AudioSettings.MUTED_DB, maxf(duration, 0.01))
	tw.finished.connect(func() -> void:
		if is_instance_valid(node) and node.has_method("stop"):
			node.call("stop")
	)
	set(tween_slot, tw)


func _start_heartbeats_fade_in() -> void:
	_fade_in_loop_sound(_heartbeats_node, AudioSettings.HEARTBEATS_DB, AudioSettings.HEARTBEATS_FADE_IN_TIME, "_heartbeats_tween")


func _start_breathe_fade_in() -> void:
	_fade_in_loop_sound(_breathe_node, AudioSettings.BREATHE_DB, AudioSettings.BREATHE_FADE_IN_TIME, "_breathe_tween")


func _start_mayinwalks_fade_in() -> void:
	if _mayinwalks_node and is_instance_valid(_mayinwalks_node) and _monster and is_instance_valid(_monster):
		if _mayinwalks_node is Node3D:
			(_mayinwalks_node as Node3D).global_position = _monster.global_position
	_fade_in_loop_sound(_mayinwalks_node, AudioSettings.MAYINWALKS_DB, AudioSettings.MAYINWALKS_FADE_IN_TIME, "_mayinwalks_tween")


func _stop_mayinwalks_fade_out() -> void:
	_fade_out_loop_sound(_mayinwalks_node, AudioSettings.MAYINWALKS_FADE_OUT_TIME, "_mayinwalks_tween")


func _stop_leave_sequence_sounds() -> void:
	_stop_mayinwalks_fade_out()
	_schedule_leave_heartbeats_and_breathe_fade_out()


func _schedule_leave_heartbeats_and_breathe_fade_out() -> void:
	var hb_delay := randf_range(AudioSettings.HEARTBEATS_STOP_DELAY_MIN, AudioSettings.HEARTBEATS_STOP_DELAY_MAX)
	await _wait(hb_delay)
	if not is_inside_tree():
		return
	_fade_out_loop_sound(_heartbeats_node, AudioSettings.HEARTBEATS_FADE_OUT_TIME, "_heartbeats_tween")
	var br_delay := randf_range(AudioSettings.BREATHE_STOP_DELAY_MIN, AudioSettings.BREATHE_STOP_DELAY_MAX)
	await _wait(br_delay)
	if not is_inside_tree():
		return
	_fade_out_loop_sound(_breathe_node, AudioSettings.BREATHE_FADE_OUT_TIME, "_breathe_tween")


func _stop_all_ambient_loops_immediately() -> void:
	_waiting_broken_door_left_turn = false
	_door_window2_lure_pending = false
	for pair: Array in [
		[_heartbeats_node, "_heartbeats_tween"],
		[_breathe_node, "_breathe_tween"],
		[_mayinwalks_node, "_mayinwalks_tween"]
	]:
		var n: Node = pair[0]
		var slot: String = pair[1]
		var tw: Tween = get(slot) as Tween
		if tw:
			tw.kill()
		if n and is_instance_valid(n) and n.has_method("stop"):
			n.call("stop")


func _update_broken_door_left_turn_trigger() -> void:
	var cam_open := _cam_system != null and _cam_system.is_open()
	var can_trigger_window2_stage := (_state == State.DOOR or _door_window2_lure_pending) and _room == "doorway"
	if not _waiting_broken_door_left_turn or _broken_door_heartbeats_triggered:
		_was_camera_open_last_frame = cam_open
		return
	if not can_trigger_window2_stage:
		_was_camera_open_last_frame = cam_open
		return
	var left_turn_command := _is_turning_left_command()
	var just_exited_cam := _was_camera_open_last_frame and not cam_open
	if not cam_open and left_turn_command and (just_exited_cam or _player_cam == null or not bool(_player_cam.call("is_busy") if _player_cam.has_method("is_busy") else false)):
		_broken_door_heartbeats_triggered = true
		_waiting_broken_door_left_turn = false
		_start_heartbeats_fade_in()
	_was_camera_open_last_frame = cam_open


func _is_turning_left_command() -> bool:
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		return true
	if _player_cam == null or not is_instance_valid(_player_cam):
		return false
	var ratio: Vector2 = _player_cam.call("_get_mouse_ratio") if _player_cam.has_method("_get_mouse_ratio") else Vector2(0.5, 0.5)
	var edge: float = float(_player_cam.get("edge_enter")) if _player_cam.get("edge_enter") != null else 0.0
	return ratio.x <= edge


func _build_graph() -> void:
	_graph.clear()
	for room: String in LINKS:
		_graph[room] = []
	for room: String in LINKS:
		for n: String in LINKS[room]:
			if not _graph[room].has(n):
				_graph[room].append(n)
			if symmetric_links and _graph.has(n) and not _graph[n].has(room):
				_graph[n].append(room)


func _compute_distances() -> void:
	_dist.clear()
	var queue: Array[String] = []
	for r in door_rooms:
		_dist[r] = 1
		queue.append(r)
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n: String in _graph.get(cur, []):
			if not _dist.has(n):
				_dist[n] = int(_dist[cur]) + 1
				queue.append(n)


func _night_scale() -> float:
	var n := _game.night if _game else 1
	return clampf(1.0 - 0.12 * float(n - 1), 0.4, 1.0)


func _process(delta: float) -> void:
	if _mayinwalks_node and is_instance_valid(_mayinwalks_node) and _monster and is_instance_valid(_monster):
		if _mayinwalks_node is Node3D and bool(_mayinwalks_node.get("playing")):
			(_mayinwalks_node as Node3D).global_position = _monster.global_position
	_update_broken_door_left_turn_trigger()
	match _state:
		State.SLEEP:
			_sleep_left -= delta
			if _sleep_left <= 0.0:
				_wake_up()
		State.ROAM:
			if _busy:
				return
			if _lure_room != "":
				_lure_left -= delta
				if _lure_left <= 0.0:
					var target := _lure_room
					var was_door_window2_lure := _door_window2_lure_pending and _room == "doorway"
					_lure_room = ""
					_door_window2_lure_pending = false
					_waiting_broken_door_left_turn = false
					if was_door_window2_lure:
						_fade_out_loop_sound(_heartbeats_node, AudioSettings.HEARTBEATS_FADE_OUT_TIME, "_heartbeats_tween")
						if _player_cam:
							_call_cam_method(_player_cam, "shake", [0.16, 0.45])
					_schedule_next_move()
					_do_room_move(target)
				return
			_move_left -= delta
			if _move_left <= 0.0:
				_decide_move()


func _wake_up() -> void:
	_state = State.ROAM
	_busy = true
	var wake_spot := _spot("Spot_backstage2")
	if wake_spot:
		_place_at(wake_spot, roam_pose)
	else:
		push_warning("MonsterAI: Spot_backstage2 not found.")
	if _cam_system:
		var transition_finished: Signal = _cam_system.lost_signal_finished
		_cam_system.play_lost_signal(Callable(self, "_set_pose").bind(roam_pose))
		await transition_finished
	else:
		_set_pose(roam_pose)
	if _state != State.ROAM:
		return
	_busy = false
	_schedule_next_move()


func _schedule_next_move(extra: float = 0.0) -> void:
	var roam_interval := Difficulties.random_time(Difficulties.MAYINMELIH, &"move_interval_min", &"move_interval_max") * _night_scale()
	_move_left = roam_interval / maxf(roam_speed_multiplier, 1.0) + extra


func _alive() -> bool:
	return _state == State.DOOR or _state == State.INSIDE


func _on_night_over() -> void:
	_set_ouz_charge_drain_multiplier(1.0)
	if _player_cam:
		_call_cam_method(_player_cam, "set_hidden_ambient_sway_enabled", [true])
	release_door_window(self)
	_stop_all_ambient_loops_immediately()
	_state = State.DONE


func set_mayinmelih_difficulty_level(level: int) -> void:
	Difficulties.set_level(Difficulties.MAYINMELIH, level)
	if not is_node_ready():
		return
	if _state == State.SLEEP:
		_sleep_left = Difficulties.random_time(Difficulties.MAYINMELIH, &"wake_delay_min", &"wake_delay_max") * _night_scale()
	elif _state == State.ROAM and not _busy and _lure_room == "":
		_schedule_next_move()


func set_ouz_difficulty_level(level: int) -> void:
	Difficulties.set_level(Difficulties.OUZ, level)


func _set_ouz_charge_drain_multiplier(multiplier: float) -> void:
	if not _ouz_module or not is_instance_valid(_ouz_module):
		return
	if not _ouz_module.has_method("set_charge_drain_multiplier"):
		push_error("MonsterAI: OuzModule charge drain method not found.")
		return
	_ouz_module.call("set_charge_drain_multiplier", multiplier)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.01)).timeout


func try_reserve_door_window(requester: Node) -> bool:
	if requester == null or not is_instance_valid(requester):
		return false
	if is_instance_valid(_door_window_owner) and _door_window_owner != requester:
		return false
	_door_window_owner = requester
	return true


func release_door_window(requester: Node) -> void:
	if _door_window_owner == requester:
		_door_window_owner = null


func _wait_for_door_window_access() -> bool:
	while _alive():
		if try_reserve_door_window(self):
			return true
		var wait_time := Difficulties.random_time(Difficulties.MAYINMELIH, &"move_interval_min", &"move_interval_max") * _night_scale() / maxf(roam_speed_multiplier, 1.0)
		await _wait(wait_time)
	return false


func _decide_move() -> void:
	if door_rooms.has(_room) and randf() < door_bias:
		_start_door_attack()
		return
	var next := _pick_next_room()
	_schedule_next_move()
	if next != "":
		_do_room_move(next)


func _do_room_move(room: String) -> void:
	_busy = true
	var leaving_door_window := _room == "doorway"
	_door_window2_lure_pending = false
	var spot := _spot_for_room(room, roam_pose)
	if _room == "doorway":
		if _cam_system:
			var signal_covers_walk := _cam_system.is_camera_feed_active()
			var transition_finished: Signal = _cam_system.lost_signal_finished
			_cam_system.play_lost_signal(Callable(self, "_walk_to_lured_room").bind(spot, room, signal_covers_walk))
			await transition_finished
		else:
			await _walk_to_lured_room(spot, room, false)
	else:
		await _relocate(spot, roam_pose, room)
	if leaving_door_window and _room == room:
		release_door_window(self)
	_busy = false


func _walk_to_lured_room(spot: Node3D, room: String, _signal_covers_walk: bool) -> void:
	if room == "backstage":
		spot = _spot_for_room(room, roam_pose)
	if room == "southhall":
		var pre_southhall := _spot("Spot_preSouthhall")
		if pre_southhall:
			await _walk_to_spot(pre_southhall, Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"), roam_pose)
			if _state == State.DONE or _state == State.JUMPSCARE:
				return
	await _walk_to_spot(spot, Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"), roam_pose)
	if spot and _state == State.ROAM:
		_room = room


func _pick_next_room() -> String:
	var options: Array = _graph.get(_room, [])
	if options.is_empty():
		return ""
	var cur_d: int = int(_dist.get(_room, 99))
	var closer: Array[String] = []
	for n: String in options:
		if int(_dist.get(n, 99)) < cur_d:
			closer.append(n)
	if not closer.is_empty() and randf() < forward_bias:
		return String(closer.pick_random())
	return String(options.pick_random())


func _pick_retreat_room() -> String:
	var far: Array[String] = []
	for r: String in _dist:
		if int(_dist[r]) >= retreat_min_distance:
			far.append(r)
	if far.is_empty():
		return "backstage"
	return String(far.pick_random())


func _relocate(spot: Node3D, pose: String, room_name: String) -> void:
	if room_name == "backstage" and pose != "pose_sit":
		spot = _spot("Spot_backstage2")
	if spot == null:
		push_warning("MonsterAI: Spot bulunamadı (oda: %s)" % room_name)
		return
	var apply := func() -> void:
		_room = room_name
		_place_at(spot, pose)
	if _cam_system:
		var transition_finished: Signal = _cam_system.lost_signal_finished
		_cam_system.play_lost_signal(apply)
		await transition_finished
	else:
		apply.call()


func _on_lure_requested(cam_index: int) -> void:
	if cam_index < 0 or cam_index >= CAM_ROOMS.size():
		return
	var target: String = CAM_ROOMS[cam_index]
	if not Difficulties.ouz_enabled:
		_play_lure_sound(target)

	if target == _room:
		return

	var from_door_window := _room == "doorway" and _state == State.DOOR
	if from_door_window:
		if not DOOR_WINDOW_LURE_ROOMS.has(target):
			return
		if randf() >= door_window_lure_success_chance:
			return
		_door_window2_lure_pending = _waiting_broken_door_left_turn
		_state = State.ROAM
		_busy = false
		_lure_room = target
		_lure_left = Difficulties.random_time(Difficulties.MAYINMELIH, &"lure_delay_min", &"lure_delay_max")
		return

	if _state != State.ROAM:
		return
	var neighbors: Array = _graph.get(_room, [])
	if not neighbors.has(target):
		return
	if int(_dist.get(target, 99)) <= int(_dist.get(_room, 99)):
		return
	if randf() >= Difficulties.time(Difficulties.MAYINMELIH, &"lure_success_chance"):
		return
	_lure_room = target
	_lure_left = Difficulties.random_time(Difficulties.MAYINMELIH, &"lure_delay_min", &"lure_delay_max")


func _play_lure_sound(room: String) -> void:
	if _lure_sounds.is_empty():
		return
	var player: AudioStreamPlayer3D = _lure_sounds.pick_random()
	player.stop()
	var spot := _spot("Spot_" + room)
	if spot:
		player.global_position = spot.global_position
	player.play()


func _start_door_attack() -> void:
	_state = State.DOOR
	_busy = true
	_safe_to_unhide = false
	_lure_room = ""
	_waiting_broken_door_left_turn = false
	_door_window2_lure_pending = false
	_broken_door_heartbeats_triggered = false
	var door_window := _spot("Spot_DoorWindow")
	if door_window == null:
		push_warning("MonsterAI: Spot_DoorWindow bulunamadı.")
		_busy = false
		_state = State.ROAM
		return
	var has_door_window_access := await _wait_for_door_window_access()
	if not has_door_window_access:
		return
	if _cam_system:
		var signal_covers_walk := _cam_system.is_camera_feed_active()
		var transition_finished: Signal = _cam_system.lost_signal_finished
		_cam_system.play_lost_signal(Callable(self, "_walk_to_door_window").bind(signal_covers_walk))
		await transition_finished
	else:
		await _walk_to_door_window()
	if not _alive():
		return
	await _door_sequence()


func _walk_to_door_window(signal_covers_walk: bool = false) -> void:
	var covered_walk_budget := 0.0
	if signal_covers_walk and _cam_system:
		covered_walk_budget = maxf(0.1, _cam_system.lost_signal_time + _cam_system.pending_after_lost_time - 0.15)
	var pre_approach_duration := 0.0
	if _room == "southhall":
		var pre_southhall := _spot("Spot_preSouthhall")
		if pre_southhall:
			var pre_distance := _monster.global_position.distance_to(pre_southhall.global_position)
			var door_window_marker := _spot("Spot_DoorWindow")
			var door_distance := pre_southhall.global_position.distance_to(door_window_marker.global_position) if door_window_marker else 0.0
			var pre_approach_time := maxf(Difficulties.time(Difficulties.MAYINMELIH, &"enter_office_walk_time"), pre_distance / 2.5)
			if signal_covers_walk:
				var total_distance := maxf(pre_distance + door_distance, 0.001)
				pre_approach_time = covered_walk_budget * pre_distance / total_distance
			pre_approach_duration = pre_approach_time
			await _walk_to_spot(pre_southhall, pre_approach_time, roam_pose)
			if not _alive():
				return
	var door_window := _spot("Spot_DoorWindow")
	if door_window == null:
		return
	var approach_time := maxf(Difficulties.time(Difficulties.MAYINMELIH, &"enter_office_walk_time"), _monster.global_position.distance_to(door_window.global_position) / 2.5)
	if signal_covers_walk:
		approach_time = maxf(0.05, covered_walk_budget - pre_approach_duration)
	await _walk_to_spot(door_window, approach_time, "pose_window")
	if _alive():
		_room = "doorway"


func _door_sequence() -> void:
	var door_was_already_broken := _door.is_broken if _door else false
	if door_was_already_broken:
		await _broken_door_window_sequence()
		return

	await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"peek_time"))
	if not _alive():
		return

	var knock_spot := _spot("Spot_DoorKnock")
	if knock_spot:
		_place_at(knock_spot, "pose_knock_b")
	else:
		push_warning("MonsterAI: Spot_DoorKnock bulunamadı, mevcut konumda kapıya vuruluyor.")
		_set_pose("pose_knock_b")

	if knocks_before_kick > 0:
		await _first_knock_at_door()
	for hit_number in range(2, knocks_before_kick + 1):
		await _wait(randf_range(Difficulties.time(Difficulties.MAYINMELIH, &"knock_gap") * 0.8, Difficulties.time(Difficulties.MAYINMELIH, &"knock_gap") * 1.2))
		if not _alive():
			return
		await _knock(hit_number)
		if not _alive():
			return
	await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"knock_gap"))
	if not _alive():
		return
	await _kick()
	if not _alive():
		return
	if _hide and not _hide.is_concealed():
		await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"unhidden_kick_jumpscare_delay"))
		if not _alive():
			return
		if _hide and not _hide.is_concealed():
			_jumpscare("Spot_JumpscareOffice")
			return
	await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"break_wait"))
	if not _alive():
		return

	await _enter_office()


func _broken_door_window_sequence() -> void:
	var door_window := _spot("Spot_DoorWindow2")
	if door_window:
		_place_at(door_window, "pose_stand_2")
	else:
		_set_pose("pose_stand_2")
	_room = "doorway"
	_waiting_broken_door_left_turn = true
	_door_window2_lure_pending = false
	_broken_door_heartbeats_triggered = false
	_was_camera_open_last_frame = _cam_system != null and _cam_system.is_open()

	await _wait(Difficulties.random_time(Difficulties.MAYINMELIH, &"broken_door_window_wait_min", &"broken_door_window_wait_max"))
	_waiting_broken_door_left_turn = false
	_door_window2_lure_pending = false
	if not _alive():
		return

	if _hide and not _hide.is_concealed():
		_jumpscare("Spot_JumpscareOffice")
		return

	await _lock_cams_for_door()
	if not _alive():
		return

	await _enter_office_broken_door_hidden()


func _enter_office_broken_door_hidden() -> void:
	_state = State.INSIDE
	if _player_cam:
		_call_cam_method(_player_cam, "set_hidden_ambient_sway_enabled", [false])
	if _cam_system:
		_cam_system.play_office_static()
	_set_ouz_charge_drain_multiplier(MAYINMELIH_INSIDE_CHARGE_DRAIN_MULTIPLIER)
	await _walk_to_spot(_spot("Spot_Inside1"), Difficulties.time(Difficulties.MAYINMELIH, &"enter_office_walk_time"))
	if not _alive():
		return
	if not _prepare_inside_patrol(&"broken_door_notice_chance"):
		return
	if not _alive():
		return
	await _walk_to_spot(_spot("Spot_Inside2"), Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"))
	if not _alive():
		return
	await _patrol_inside_while_hidden()


func _lock_cams_for_door() -> void:
	if _cam_system == null:
		return
	_cam_system.lock_cams("door")
	if _cam_system.is_open():
		_cam_system.force_close()
		var timer := get_tree().create_timer(1.5)
		await _wait_signal_or_timeout(_cam_system.closed, timer)


func _wait_signal_or_timeout(sig: Signal, timer: SceneTreeTimer) -> void:
	var done := [false]
	var on_sig := func(_a = null, _b = null, _c = null) -> void:
		done[0] = true
	var on_to := func() -> void:
		done[0] = true
	sig.connect(on_sig, CONNECT_ONE_SHOT)
	timer.timeout.connect(on_to, CONNECT_ONE_SHOT)
	while not done[0]:
		await get_tree().process_frame
	if sig.is_connected(on_sig):
		sig.disconnect(on_sig)
	if timer.timeout.is_connected(on_to):
		timer.timeout.disconnect(on_to)


func _knock(hit_number: int) -> void:
	_set_pose("pose_knock_a")
	await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"knock_pose_change_time"))
	if not _alive():
		return
	_set_pose("pose_knock_b")
	var knock_player := _first_knock_sound if hit_number == 1 else _knock_sound
	if knock_player:
		knock_player.global_position = _knock_sound.global_position if _knock_sound else _monster.global_position
	_play_sound(knock_player)
	if _door:
		_door.hit(hit_number)
	if _player_cam:
		_call_cam_method(_player_cam, "shake", [0.22, 0.35])
	await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"knock_pose_recovery_time"))
	if not _alive():
		return
	_set_pose("pose_knock_a")


func _first_knock_at_door() -> void:
	_set_ouz_charge_drain_multiplier(MAYINMELIH_INSIDE_CHARGE_DRAIN_MULTIPLIER)
	_set_pose("pose_knock_b")
	_start_heartbeats_fade_in()
	if _first_knock_sound:
		_first_knock_sound.global_position = _knock_sound.global_position if _knock_sound else _monster.global_position
	_play_sound(_first_knock_sound)
	await _lock_cams_for_door()
	if not _alive():
		return
	if _door:
		_door.hit(1)
	if _player_cam:
		_call_cam_method(_player_cam, "shake", [0.22, 0.35])
	await _wait(Difficulties.time(Difficulties.MAYINMELIH, &"knock_pose_recovery_time"))
	if _alive():
		_set_pose("pose_knock_a")


func _kick() -> void:
	_set_ouz_charge_drain_multiplier(MAYINMELIH_INSIDE_CHARGE_DRAIN_MULTIPLIER)
	_set_pose("pose_kick")
	_play_sound(_break_sound)
	if _cam_system:
		_cam_system.play_office_static()
	var from_spot := _spot("Spot_DoorKnock")
	var to_spot := _spot("Spot_Inside1")
	var dir := Vector3.FORWARD
	if from_spot and to_spot:
		dir = to_spot.global_position - from_spot.global_position
		dir.y = 0.0
	if _door:
		_door.break_door(dir)
	if _player_cam:
		_call_cam_method(_player_cam, "shake", [0.32, 0.5])


func _enter_office() -> void:
	_state = State.INSIDE
	if _player_cam:
		_call_cam_method(_player_cam, "set_hidden_ambient_sway_enabled", [false])
	if _cam_system:
		_cam_system.play_office_static()
	await _walk_to_spot(_spot("Spot_Inside1"), Difficulties.time(Difficulties.MAYINMELIH, &"enter_office_walk_time"))
	if not _alive():
		return
	if not _prepare_inside_patrol(&"notice_chance"):
		return

	await _walk_to_spot(_spot("Spot_Inside2"), Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"))
	if not _alive():
		return

	await _patrol_inside_while_hidden()


func _prepare_inside_patrol(chance_key: StringName) -> bool:
	_office_visit_count += 1
	_inside_notice_pending = false
	if _hide and not _hide.is_concealed():
		_jumpscare("Spot_JumpscareOffice")
		return false
	if _hide and _hide.is_hidden:
		_start_breathe_fade_in()
		var notice_chance := Difficulties.time(Difficulties.MAYINMELIH, chance_key)
		if _office_visit_count > 2:
			var visit_multiplier := 1.0 + float(_office_visit_count - 2) * 0.2
			notice_chance = minf(notice_chance * visit_multiplier, 1.0)
		_inside_notice_pending = randf() < notice_chance
	return true


func _patrol_inside_while_hidden() -> void:
	if not _hide or not _hide.is_concealed():
		_jumpscare("Spot_JumpscareOffice")
		return
	var patrol_spots: Array[Node3D] = []
	for spot_number in range(1, 10):
		var spot := _spot("Spot_Inside%d" % spot_number)
		if spot == null:
			push_error("MonsterAI: Spot_Inside%d bulunamadı." % spot_number)
			return
		patrol_spots.append(spot)

	_inside_patrol_active = true
	_inside_chase_started = false
	var current_spot := _spot("Spot_Inside2")
	for _step in range(randi_range(4, 9)):
		if not _alive() or not _inside_patrol_active:
			return
		var destinations: Array[Node3D] = []
		for spot: Node3D in patrol_spots:
			if spot != current_spot:
				destinations.append(spot)
		var destination: Node3D = destinations.pick_random()
		await _walk_to_spot(destination, Difficulties.time(Difficulties.MAYINMELIH, &"hidden_patrol_walk_time"), roam_pose, true)
		if not _alive() or not _inside_patrol_active:
			return
		current_spot = destination
		if _inside_notice_pending:
			_inside_notice_pending = false
			_inside_patrol_active = false
			_inside_chase_started = true
			await _chase_unhidden_player()
			return

	await _walk_to_spot(_spot("Spot_Inside1"), Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"), roam_pose, true)
	if not _alive() or not _inside_patrol_active or _inside_chase_started:
		return
	await _leave()


func _chase_unhidden_player() -> void:
	if not _alive() or _state != State.INSIDE:
		return
	var chase_transform := _monster.global_transform
	if _player_cam:
		var player_position := _player_cam.global_position
		chase_transform.origin = Vector3(player_position.x, _monster.global_position.y, player_position.z)
	await _walk_to_transform(chase_transform, Difficulties.time(Difficulties.MAYINMELIH, &"hidden_chase_walk_time"), roam_pose)
	if _alive() and _state == State.INSIDE:
		_jumpscare("Spot_JumpscareDesk")


func _leave() -> void:
	if _cam_system:
		_cam_system.stop_office_static()
	_stop_leave_sequence_sounds()
	var has_door_window_access := await _wait_for_door_window_access()
	if not has_door_window_access:
		return
	if _inside_chase_started or not _alive():
		return
	var door_window := _spot("Spot_DoorWindow")
	await _walk_to_spot(door_window, Difficulties.time(Difficulties.MAYINMELIH, &"enter_office_walk_time"), roam_pose, _inside_patrol_active)
	if not _alive() or _inside_chase_started:
		return
	_room = "doorway"
	_set_ouz_charge_drain_multiplier(1.0)
	_inside_patrol_active = false
	_safe_to_unhide = true
	var room := "southhall" if randf() < 0.5 else "westhall"
	_play_monster_woosh()
	if room == "southhall":
		await _walk_to_spot(_spot("Spot_preSouthhall"), Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"), roam_pose)
		if not _alive():
			return
	await _walk_to_spot(_spot("Spot_" + room), maxf(Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_time"), Difficulties.time(Difficulties.MAYINMELIH, &"inside_walk_minimum")), roam_pose)
	if not _alive():
		return
	_room = room
	if _player_cam:
		var hold_duration := randf_range(LEAVE_FEAR_HOLD_MIN, LEAVE_FEAR_HOLD_MAX)
		_call_cam_method(_player_cam, "continue_fear_sway_and_fade_out", [hold_duration, LEAVE_FEAR_FADE_OUT_TIME])
	release_door_window(self)
	if _cam_system:
		_cam_system.unlock_cams("door")
	_state = State.ROAM
	_busy = false
	_schedule_next_move(Difficulties.time(Difficulties.MAYINMELIH, &"rearm_delay"))


func _on_unhide_clicked() -> void:
	if _state == State.INSIDE and not _safe_to_unhide:
		if _inside_patrol_active:
			_hide.unhide()
			return
		_jumpscare("Spot_JumpscareDesk")
	elif _hide:
		_hide.unhide()


func _on_hidden_changed(value: bool) -> void:
	if value and _state == State.INSIDE:
		_start_breathe_fade_in()
	if not value and _state == State.INSIDE and _inside_patrol_active:
		_inside_notice_pending = false
		_inside_patrol_active = false
		_inside_chase_started = true
		_chase_unhidden_player()
		return
	if not _player_cam:
		return
	if value and _state == State.INSIDE:
		_call_cam_method(_player_cam, "set_hidden_ambient_sway_enabled", [false])
		_call_cam_method(_player_cam, "shake", [0.2, 0.45])
	elif not value and _state != State.INSIDE:
		_call_cam_method(_player_cam, "set_hidden_ambient_sway_enabled", [true])


func _resolve_scare_cam() -> Camera3D:
	var target_vp: Viewport = _player_cam.get_viewport() if _player_cam and is_instance_valid(_player_cam) else null
	var found := _find_node_in_scene("ScareCam", target_vp) as Camera3D
	if found and is_instance_valid(found):
		return found
	return _find_node_in_scene("ScareCam") as Camera3D


func _activate_jumpscare_camera() -> void:
	var player_is_hidden := _hide.is_concealed() if _hide else false
	if player_is_hidden and _player_cam != null and is_instance_valid(_player_cam):
		_jumpscare_camera = _player_cam
		_force_jumpscare_camera_current()
		return
	_scare_cam = _resolve_scare_cam()
	if _scare_cam != null and is_instance_valid(_scare_cam):
		if _jumpscare_camera != _scare_cam and _player_cam:
			_call_cam_method(_player_cam, "snap_to_base")
		if _player_cam and is_instance_valid(_player_cam) and _player_cam != _scare_cam:
			_player_cam.current = false
		_jumpscare_camera = _scare_cam
		_force_jumpscare_camera_current()
	elif _player_cam and is_instance_valid(_player_cam):
		_jumpscare_camera = _player_cam
		_jumpscare_camera.current = true
		_jumpscare_camera.make_current()


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


func _jumpscare(spot_name: String) -> void:
	if _state == State.JUMPSCARE or _state == State.DONE:
		return
	_set_ouz_charge_drain_multiplier(1.0)
	_stop_all_ambient_loops_immediately()
	_state = State.JUMPSCARE
	release_door_window(self)
	_busy = true
	_lure_room = ""
	var was_watching_cameras := _cam_system != null and _cam_system.is_open()
	if _cam_system:
		_cam_system.hide_mobile_exit_button()
		_cam_system.set_mobile_hide_exit_mode(false)
		_cam_system.lock_cams("jumpscare")
		if was_watching_cameras:
			_cam_system.interrupt_for_jumpscare()

	if _player_cam:
		_call_cam_method(_player_cam, "set_frozen", [true])
	_activate_jumpscare_camera()
	if _jumpscare_camera:
		_call_cam_method(_jumpscare_camera, "set_frozen", [true])
		_call_cam_method(_jumpscare_camera, "shake", [jumpscare_shake * 0.5, jumpscare_time])

	var target_spot := _spot(spot_name)
	if target_spot:
		_place_at(target_spot, "pose_jumpscare")
	else:
		_set_pose("pose_jumpscare")
	_play_sound(_scare_sound)
	await _jumpscare_effect()

	if _game:
		_game.trigger_game_over()
	else:
		get_tree().reload_current_scene()


func _jumpscare_effect() -> void:
	_activate_jumpscare_camera()
	if _jumpscare_camera == null or not is_instance_valid(_jumpscare_camera):
		await _wait(jumpscare_time)
		return
	var start_pos := _monster.global_position
	var target_pos := _jumpscare_camera.global_position
	var base_cam_pos := _jumpscare_camera.position
	var base_cam_rotation := _jumpscare_camera.rotation
	var base_h_offset := _jumpscare_camera.h_offset
	var base_v_offset := _jumpscare_camera.v_offset
	var poses := _jumpscare_poses()
	var elapsed := 0.0
	var pose_timer := 0.0
	var pose_idx := 0
	var pos_shake := jumpscare_shake * 0.25
	var offset_shake := jumpscare_shake * 0.35

	while elapsed < jumpscare_time:
		await get_tree().process_frame
		_activate_jumpscare_camera()
		_force_jumpscare_camera_current()
		var dt := get_process_delta_time()
		elapsed += dt
		var k := clampf(elapsed / jumpscare_time, 0.0, 1.0)

		_jumpscare_camera.position = base_cam_pos + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
		) * pos_shake
		var rotation_shake := deg_to_rad(jumpscare_rotation_shake_deg)
		_jumpscare_camera.rotation = base_cam_rotation + Vector3(
			randf_range(-rotation_shake, rotation_shake),
			randf_range(-rotation_shake, rotation_shake),
			randf_range(-rotation_shake * 0.75, rotation_shake * 0.75)
		)
		if _jumpscare_camera != _player_cam:
			_jumpscare_camera.h_offset = base_h_offset + randf_range(-offset_shake, offset_shake)
			_jumpscare_camera.v_offset = base_v_offset + randf_range(-offset_shake, offset_shake)
		_monster.global_position = start_pos.lerp(target_pos, jumpscare_lunge * k)

		if poses.size() > 1:
			pose_timer += dt
			if pose_timer >= 0.08:
				pose_timer = 0.0
				pose_idx = (pose_idx + 1) % poses.size()
				_set_pose(poses[pose_idx])

	_jumpscare_camera.position = base_cam_pos
	_jumpscare_camera.rotation = base_cam_rotation
	if _jumpscare_camera:
		_call_cam_method(_jumpscare_camera, "reset_shake")
	_jumpscare_camera.h_offset = base_h_offset
	_jumpscare_camera.v_offset = base_v_offset


func _jumpscare_poses() -> Array[String]:
	var result: Array[String] = []
	for p in ["pose_jumpscare", "pose_jumpscare_a", "pose_jumpscare_b", "pose_jumpscare_c"]:
		if _anim.has_animation(p):
			result.append(p)
	return result


func _spot(spot_name: String) -> Node3D:
	return _find_node_in_scene(spot_name) as Node3D


func _spot_for_room(room: String, pose: String) -> Node3D:
	if room == "backstage" and pose != "pose_sit":
		return _spot("Spot_backstage2")
	return _spot("Spot_" + room)


func _place_at(spot: Node3D, pose: String) -> void:
	if spot == null:
		return
	var xf := spot.global_transform
	xf.basis = xf.basis.orthonormalized().scaled(_monster_scale)
	_monster.global_transform = xf
	_set_pose(pose)


func _place_in_room(room: String, pose: String = "") -> void:
	var final_pose := pose if pose != "" else roam_pose
	var spot := _spot_for_room(room, final_pose)
	if spot == null:
		push_warning("MonsterAI: Spot_%s bulunamadı." % room)
		return
	_room = room
	_place_at(spot, final_pose)


func _walk_to_spot(
	spot: Node3D,
	duration: float,
	final_pose: String = "pose_inside",
	cancel_if_unhidden: bool = false
) -> void:
	if spot == null:
		push_warning("MonsterAI: Yürüme hedefi bulunamadı.")
		return
	var play_walk_sound := spot.name.begins_with("Spot_Inside")
	await _walk_to_transform(spot.global_transform, duration, final_pose, cancel_if_unhidden, play_walk_sound)


func _walk_to_transform(
	target_xf: Transform3D,
	duration: float,
	final_pose: String = "pose_inside",
	cancel_if_unhidden: bool = false,
	play_walk_sound: bool = false
) -> void:
	var start_xf := _monster.global_transform
	var arrival_basis := target_xf.basis.orthonormalized()
	var facing_basis := arrival_basis
	var travel_direction := target_xf.origin - start_xf.origin
	travel_direction.y = 0.0
	if not travel_direction.is_zero_approx():
		facing_basis = Basis.looking_at(travel_direction.normalized(), Vector3.UP)
	var start_basis := start_xf.basis.orthonormalized()
	_set_pose(roam_pose)
	if play_walk_sound:
		_start_mayinwalks_fade_in()
	var elapsed := 0.0
	var travel_time := maxf(duration, 0.01)
	while elapsed < travel_time and _state != State.DONE and _state != State.JUMPSCARE:
		await get_tree().process_frame
		if _state == State.DONE or _state == State.JUMPSCARE:
			break
		if cancel_if_unhidden and _hide and not _hide.is_concealed():
			break
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / travel_time, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var walking_xf := Transform3D.IDENTITY
		walking_xf.origin = start_xf.origin.lerp(target_xf.origin, t)
		var walking_basis := start_basis.slerp(facing_basis, t)
		var arrival_turn := clampf((t - 0.75) / 0.25, 0.0, 1.0)
		arrival_turn = arrival_turn * arrival_turn * (3.0 - 2.0 * arrival_turn)
		walking_basis = walking_basis.slerp(arrival_basis, arrival_turn)
		walking_xf.basis = walking_basis.scaled(_monster_scale)
		_monster.global_transform = walking_xf
	if play_walk_sound:
		_stop_mayinwalks_fade_out()
	if _state != State.DONE and _state != State.JUMPSCARE:
		target_xf.basis = arrival_basis.scaled(_monster_scale)
		_monster.global_transform = target_xf
		_set_pose(final_pose)


func _set_pose(pose: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation("RESET"):
		_anim.play("RESET", 0.0)
		_anim.advance(0.0)
	if _anim.has_animation(pose):
		_anim.play(pose, 0.0)
		_anim.advance(0.0)
	else:
		push_warning("MonsterAI: '%s' animasyonu bulunamadı." % pose)


func _play_sound(player: AudioStreamPlayer3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.stop()
	if player.stream == null:
		return
	if player.name in ["DoorBreakSound", "KnockSound", "FirstKnockSound"]:
		player.pitch_scale = randf_range(0.8, 1.2)
	player.play()


func _play_monster_woosh() -> void:
	if not _woosh_sound or not is_instance_valid(_woosh_sound):
		return
	_woosh_sound.global_position = _monster.global_position
	_play_sound(_woosh_sound)


func _debug_door_attack() -> void:
	await _wait(debug_door_attack_delay)
	if _state == State.SLEEP or _state == State.ROAM:
		_state = State.ROAM
		_room = door_rooms[0] if not door_rooms.is_empty() else "westhall"
		_start_door_attack()
