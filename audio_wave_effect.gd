extends Control

const EFFECT_DURATION: float = 0.9
const WAVE_INTERVAL: float = 0.25
const FADE_IN_DURATION: float = 0.08

var _origin: Vector2 = Vector2.ZERO
var _elapsed: float = -1.0


func play_wave(origin: Vector2) -> void:
	_origin = origin
	_elapsed = 0.0
	set_process(true)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= EFFECT_DURATION + WAVE_INTERVAL:
		_elapsed = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _elapsed < 0.0:
		return

	for wave_index in range(2):
		var wave_start := float(wave_index) * WAVE_INTERVAL
		if _elapsed < wave_start:
			continue
		var progress := (_elapsed - wave_start) / EFFECT_DURATION
		if progress >= 1.0:
			continue

		var distance := _interpolate_value(progress, 2.0, 160.0)
		var vertical_radius := _interpolate_value(progress, 22.0, 70.0)
		var arc_angle := PI * 0.25
		var arc_radius := vertical_radius / sin(arc_angle)
		var fade_in := clampf(progress * EFFECT_DURATION / FADE_IN_DURATION, 0.0, 1.0)
		var alpha := 0.95 * fade_in * (1.0 - progress)
		var line_width := lerpf(6.5, 5.0, progress)
		var wave_color := Color(1.0, 1.0, 1.0, alpha)
		draw_arc(
			Vector2(_origin.x + distance - arc_radius * cos(arc_angle), _origin.y),
			arc_radius,
			-arc_angle,
			arc_angle,
			32,
			wave_color,
			line_width,
			true
		)


func _interpolate_value(progress: float, start_value: float, end_value: float) -> float:
	return lerpf(start_value, end_value, progress)
