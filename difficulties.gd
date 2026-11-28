extends Node

const MAYINMELIH: StringName = &"mayinmelih"
const OUZ: StringName = &"ouz"
const MIN_LEVEL := 1
const MAX_LEVEL := 20
const DEFAULT_LEVELS := {
	MAYINMELIH: 20,
	OUZ: 20,
}
const TIMINGS := {
	MAYINMELIH: {
		&"wake_delay_min": {&"level_1": 60, &"level_20": 8},
		&"wake_delay_max": {&"level_1": 120, &"level_20": 20},
		&"move_interval_min": {&"level_1": 35, &"level_20": 10},
		&"move_interval_max": {&"level_1": 50, &"level_20": 20},
		&"lure_delay_min": {&"level_1": 5.00, &"level_20": 6},
		&"lure_delay_max": {&"level_1": 10.00, &"level_20": 11},
		&"lure_success_chance": {&"level_1": 0.9, &"level_20": 0.3},
		&"notice_chance": {&"level_1": 0.1, &"level_20": 0.35},
		&"broken_door_notice_chance": {&"level_1": 0.30, &"level_20": 0.40},
		&"peek_time": {&"level_1": 14.00, &"level_20": 8},
		&"knock_gap": {&"level_1": 1.40, &"level_20": 1.4},
		&"knock_pose_change_time": {&"level_1": 0.25, &"level_20": 0.25},
		&"knock_pose_recovery_time": {&"level_1": 0.20, &"level_20": 0.20},
		&"break_wait": {&"level_1": 0.55, &"level_20": 0.55},
		&"unhidden_kick_jumpscare_delay": {&"level_1": 0.65, &"level_20": 0.65},
		&"enter_office_walk_time": {&"level_1": 1.25, &"level_20": 1.25},
		&"inside_walk_time": {&"level_1": 1.00, &"level_20": 1},
		&"inside_walk_minimum": {&"level_1": 2.00, &"level_20": 2},
		&"hidden_patrol_walk_time": {&"level_1": 1.00, &"level_20": 1},
		&"hidden_chase_walk_time": {&"level_1": 0.30, &"level_20": 0.19},
		&"broken_door_window_wait_min": {&"level_1": 8, &"level_20": 5},
		&"broken_door_window_wait_max": {&"level_1": 16, &"level_20": 10},
		&"rearm_delay": {&"level_1": 25.00, &"level_20": 15},
	},
	OUZ: {
		&"charge_drain_seconds": {&"level_1": 20.00, &"level_20": 10.00},
		&"full_wind_seconds": {&"level_1": 4.5, &"level_20": 5.00},
		&"commonroom_pose_wait_min": {&"level_1": 8.00, &"level_20": 3.5},
		&"commonroom_pose_wait_max": {&"level_1": 11.00, &"level_20": 5.5},
		&"wake_delay_min": {&"level_1": 10.00, &"level_20": 4.5},
		&"wake_delay_max": {&"level_1": 15.00, &"level_20": 7},
		&"song_change_request_interval_min": {&"level_1": 60, &"level_20": 25},
		&"song_change_request_interval_max": {&"level_1": 100, &"level_20": 40},
		&"song_change_request_duration": {&"level_1": 6.00, &"level_20": 2},
		&"music_change_late_delay_min": {&"level_1": 5.00, &"level_20": 2.00},
		&"music_change_late_delay_max": {&"level_1": 10.00, &"level_20": 4.00},
		&"room_wait_min": {&"level_1": 18.00, &"level_20": 7},
		&"room_wait_max": {&"level_1": 25.00, &"level_20": 12},
		&"office_approach_walk_seconds": {&"level_1": 5, &"level_20": 2},
		&"kick_pose_display_seconds": {&"level_1": 1.00, &"level_20": 1.00},
		&"door_window_pre_wait_seconds": {&"level_1": 1.00, &"level_20": 0.25},
		&"door_window_kick_delay_min": {&"level_1": 1.00, &"level_20": 0.5},
		&"door_window_kick_delay_max": {&"level_1": 3.00, &"level_20": 1},
		&"post_break_jumpscare_delay_min": {&"level_1": 1.00, &"level_20": 0.5},
		&"post_break_jumpscare_delay_max": {&"level_1": 3.00, &"level_20": 1.5},
		&"broken_door_wait_min": {&"level_1": 2.00, &"level_20": 1},
		&"broken_door_wait_max": {&"level_1": 7.00, &"level_20": 5},
	},
}

var mayinmelih_enabled: bool = true
var ouz_enabled: bool = false
var custom_night_active: bool = false

var _levels: Dictionary = DEFAULT_LEVELS.duplicate()


func get_level(animatronic: StringName) -> int:
	if not _levels.has(animatronic):
		push_error("Difficulties: Unknown animatronic '%s'." % animatronic)
		return MIN_LEVEL
	return clampi(int(_levels[animatronic]), MIN_LEVEL, MAX_LEVEL)


func set_level(animatronic: StringName, level: int) -> void:
	if not DEFAULT_LEVELS.has(animatronic):
		push_error("Difficulties: Unknown animatronic '%s'." % animatronic)
		return
	_levels[animatronic] = clampi(level, MIN_LEVEL, MAX_LEVEL)


func time(animatronic: StringName, timing_name: StringName, level: int = 0) -> float:
	if not TIMINGS.has(animatronic):
		push_error("Difficulties: No timings for animatronic '%s'." % animatronic)
		return 0.0
	var animatronic_timings: Dictionary = TIMINGS[animatronic]
	if not animatronic_timings.has(timing_name):
		push_error("Difficulties: Unknown timing '%s' for '%s'." % [timing_name, animatronic])
		return 0.0
	var selected_level := get_level(animatronic) if level == 0 else clampi(level, MIN_LEVEL, MAX_LEVEL)
	var level_fraction := float(selected_level - MIN_LEVEL) / float(MAX_LEVEL - MIN_LEVEL)
	var endpoints: Dictionary = animatronic_timings[timing_name]
	return _round_time(lerpf(float(endpoints[&"level_1"]), float(endpoints[&"level_20"]), level_fraction))


func _round_time(value: float) -> float:
	return roundf(value * 100.0) / 100.0


func random_time(
	animatronic: StringName,
	minimum_name: StringName,
	maximum_name: StringName,
	level: int = 0
) -> float:
	var minimum := time(animatronic, minimum_name, level)
	var maximum := time(animatronic, maximum_name, level)
	return _round_time(randf_range(minf(minimum, maximum), maxf(minimum, maximum)))
