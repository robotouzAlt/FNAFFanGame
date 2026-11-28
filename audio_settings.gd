extends Node

const MUTED_DB: float = -80.0
const MENU_HOVER_DB: float = -8.0
const MENU_CLICK_DB: float = -8.0
const MENU_MUSIC_DB: float = 0.0
const UNIVERSAL_SFX_DB: float = -4.0
const DEFAULT_WORLD_SFX_DB: float = 0.0
const WORLD_AUDIO_MAX_DB: float = 6.0
const HIDING_DB: float = -12.0
const LURE_DB: float = -6.0
const JUMPSCARE_DB: float = 12.0
const CAMERA_SELECT_DB: float = -12.0
const CAMERA_CLICK_DB: float = -12.0
const CAMERA_LOST_SIGNAL_DB: float = -4.0
const CAMERA_DANGER_DB: float = -18.0
const CAMERA_AFTER_LOST_DB: float = -32.0
const CAMERA_CHANGE_REQUEST_DB: float = -12.0
const MONITOR_OPEN_DB: float = -28.0
const MONITOR_GLOW_MAX_DB: float = -48.0
const MUSIC_BOX_MAX_DB: float = 12.0
const MUSIC_BOX_CAM11_DB: float = -12.0
const MUSIC_BOX_CAM10_DB: float = -14.0
const MUSIC_BOX_CAM9_DB: float = -15.0
const MUSIC_BOX_CAM6B_DB: float = -18.0
const MUSIC_CHANGED_CAM11_DB: float = -10.0
const MUSIC_CHANGED_CAM10_DB: float = -12.0
const MUSIC_CHANGED_CAM9_DB: float = -14.0
const MUSIC_CHANGED_CAM6B_DB: float = -17.0
const MUSIC_BOX_LATE_DB: float = -6.0
const WINDING_DB: float = -32.0
const WINDING_PITCH_SCALE: float = 0.7
const OFFICE_AMBIENCE_DEFAULT_DB: float = -30
const OFFICE_AMBIENCE_DB: float = -30
const OFFICE_AMBIENCE_MONITOR_DB: float = -45.0
const TRANSFORMING_DB: float = -24.0
const JUMPSCARE_BUS_NAME: String = "JumpscareEcho"
const JUMPSCARE_REVERB_ROOM_SIZE: float = 0.8
const JUMPSCARE_REVERB_DAMPING: float = 0.4
const JUMPSCARE_REVERB_WET: float = 0.5
const BREATHE_DB: float = -16.0
const HEARTBEATS_DB: float = -10.0
const MAYINWALKS_DB: float = -20.0
const BREATHE_FADE_IN_TIME: float = 0.8
const BREATHE_FADE_OUT_TIME: float = 1.0
const HEARTBEATS_FADE_IN_TIME: float = 0.6
const HEARTBEATS_FADE_OUT_TIME: float = 1.0
const MAYINWALKS_FADE_IN_TIME: float = 0.5
const MAYINWALKS_FADE_OUT_TIME: float = 0.8
const HEARTBEATS_STOP_DELAY_MIN: float = 3.0
const HEARTBEATS_STOP_DELAY_MAX: float = 8.0
const BREATHE_STOP_DELAY_MIN: float = 1.0
const BREATHE_STOP_DELAY_MAX: float = 5.0


func ensure_jumpscare_bus() -> String:
	var bus_idx := AudioServer.get_bus_index(JUMPSCARE_BUS_NAME)
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, JUMPSCARE_BUS_NAME)
	var reverb: AudioEffectReverb
	for effect_idx in range(AudioServer.get_bus_effect_count(bus_idx)):
		reverb = AudioServer.get_bus_effect(bus_idx, effect_idx) as AudioEffectReverb
		if reverb:
			break
	if reverb == null:
		reverb = AudioEffectReverb.new()
		AudioServer.add_bus_effect(bus_idx, reverb)
	reverb.room_size = JUMPSCARE_REVERB_ROOM_SIZE
	reverb.damping = JUMPSCARE_REVERB_DAMPING
	reverb.wet = JUMPSCARE_REVERB_WET
	AudioServer.set_bus_send(bus_idx, "Master")
	return JUMPSCARE_BUS_NAME
