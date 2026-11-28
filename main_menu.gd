extends Control

const GAME_SCENE := "res://main.tscn"

const FLAG_EN = preload("res://png/flag_en.png")
const FLAG_TR = preload("res://png/flag_tr.png")
const BTN_NORMAL = preload("res://png/btn_normal.png")
const BTN_HOVER = preload("res://png/btn_hover.png")
const BTN_PRESSED = preload("res://png/btn_pressed.png")
const SETTINGS_ICON = preload("res://png/settings.png")
const CUSTOM_NIGHT_ARROW = preload("res://png/customnightarrow.png")
const CUSTOM_NIGHT_OUZ_PORTRAIT = preload("res://png/cn/ouzcn.PNG")
const CUSTOM_NIGHT_MELIH_PORTRAIT = preload("res://png/cn/melihcn.PNG")
const QUALITY_LABEL_KEYS := [
	"QUALITY_DEFAULT", "QUALITY_MEDIUM", "QUALITY_LOW", "QUALITY_POTATO",
	"QUALITY_DIPSHIT", "QUALITY_I_RESPECT_THAT"
]
const FPS_LABEL_KEYS := [
	"FPS_VSYNC_DEFAULT", "FPS_30", "FPS_60", "FPS_120", "FPS_240", "FPS_UNCAPPED"
]

@export_group("Yazı")
@export var custom_font: Font
@export var title_size: int = 112
@export var button_size: int = 32
@export var loading_size: int = 40
@export var percent_size: int = 28

@export_group("Butonlar")
@export var button_min_size: Vector2 = Vector2(200, 64)
@export var button_margin: int = 6
@export var flag_size: Vector2 = Vector2(72, 48)

@export_group("Yükleme")
@export var bar_thickness: float = 6.0
@export var bar_track_color: Color = Color(1, 1, 1, 0.12)
@export var percent_margin: float = 24.0
@export var percent_gap: float = 10.0
@export var show_loading_title: bool = true
@export var bar_speed: float = 120.0
@export var finish_delay: float = 0.3

@onready var background: ColorRect = $Background
@onready var menu_page: Control = $MenuPage
@onready var menu_vbox: BoxContainer = $MenuPage/VBox
@onready var title_label: Label = $MenuPage/VBox/TitleLabel
@onready var buttons_row: BoxContainer = $MenuPage/VBox/Buttons
@onready var btn_no: Button = $MenuPage/VBox/Buttons/BtnNo
@onready var btn_yes: Button = $MenuPage/VBox/Buttons/YesColumn/BtnYes
@onready var custom_night_button: Button = $MenuPage/VBox/Buttons/YesColumn/CustomNightButton
@onready var settings_button: Button = $MenuPage/VBox/SettingsButton
@onready var settings_page: ColorRect = $SettingsPage
@onready var custom_night_page: ColorRect = $CustomNightPage
@onready var close_custom_night_button: Button = $CustomNightPage/CloseCustomNightButton
@onready var start_night_button: Button = $CustomNightPage/StartNightButton
@onready var ouz_portrait_panel: Panel = $CustomNightPage/Center/Portraits/OuzColumn/OuzPortraitPanel
@onready var ouz_portrait: TextureRect = $CustomNightPage/Center/Portraits/OuzColumn/OuzPortraitPanel/OuzPortrait
@onready var ouz_level_label: Label = $CustomNightPage/Center/Portraits/OuzColumn/OuzPortraitPanel/OuzLevel
@onready var ouz_level_up_button: TextureButton = $CustomNightPage/Center/Portraits/OuzColumn/OuzArrows/OuzIncrease
@onready var ouz_level_down_button: TextureButton = $CustomNightPage/Center/Portraits/OuzColumn/OuzArrows/OuzDecrease
@onready var melih_portrait_panel: Panel = $CustomNightPage/Center/Portraits/MelihColumn/MelihPortraitPanel
@onready var melih_portrait: TextureRect = $CustomNightPage/Center/Portraits/MelihColumn/MelihPortraitPanel/MelihPortrait
@onready var melih_level_label: Label = $CustomNightPage/Center/Portraits/MelihColumn/MelihPortraitPanel/MelihLevel
@onready var melih_level_up_button: TextureButton = $CustomNightPage/Center/Portraits/MelihColumn/MelihArrows/MelihIncrease
@onready var melih_level_down_button: TextureButton = $CustomNightPage/Center/Portraits/MelihColumn/MelihArrows/MelihDecrease
@onready var quality_option: OptionButton = $SettingsPage/ContentCenter/SettingsContent/QualityRow/QualityOption
@onready var fps_slider: HSlider = $SettingsPage/ContentCenter/SettingsContent/FpsRow/FpsSlider
@onready var fps_value_label: Label = $SettingsPage/ContentCenter/SettingsContent/FpsRow/FpsValue
@onready var motion_blur_check: CheckButton = $SettingsPage/ContentCenter/SettingsContent/MotionBlurCheck
@onready var shadows_check: CheckButton = $SettingsPage/ContentCenter/SettingsContent/ShadowsCheck
@onready var mobile_check: CheckButton = $SettingsPage/ContentCenter/SettingsContent/MobileCheck
@onready var close_settings_button: Button = $SettingsPage/CloseSettingsButton
@onready var loading_page: Control = $LoadingPage
@onready var loading_vbox: BoxContainer = $LoadingPage/VBox
@onready var loading_label: Label = $LoadingPage/VBox/LoadingLabel
@onready var load_progress: ProgressBar = $LoadingPage/VBox/LoadProgress
@onready var percent_label: Label = $LoadingPage/VBox/PercentLabel
@onready var lang_button: TextureButton = $LangButton
@onready var hover_audio: AudioStreamPlayer2D = $SFX/Hover
@onready var click_audio: AudioStreamPlayer2D = $SFX/Click
@onready var menu_music: AudioStreamPlayer2D = $SFX/Music

var _lang: String = "en"
var _loading: bool = false
var _load_done: bool = false
var _shown: float = 0.0
var _last_pct: int = -1
var _progress: Array = []
var _flag_en_tex: Texture2D
var _flag_tr_tex: Texture2D
var _last_lang_toggle_msec: int = 0
var _custom_night_ouz_level: int = 0
var _custom_night_mayinmelih_level: int = 0
var _custom_night_portrait_alpha_elapsed: float = 0.0
var _custom_night_repeat_timer: Timer
var _held_custom_night_button: TextureButton
var _held_custom_night_animatronic: StringName
var _held_custom_night_delta: int = 0
var _custom_night_button_held: bool = false
var _custom_night_mouse_hold_detected: bool = false
var _custom_night_hovered_buttons: Array[TextureButton] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c: Control in [background, menu_page, loading_page]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color.BLACK
	hover_audio.volume_db = AudioSettings.MENU_HOVER_DB
	click_audio.volume_db = AudioSettings.MENU_CLICK_DB
	menu_music.volume_db = AudioSettings.MENU_MUSIC_DB
	settings_page.z_index = 10
	custom_night_page.z_index = 11

	menu_page.visible = true
	custom_night_button.visible = GameSettings.custom_night_unlocked

	title_label.text = "MENU_READY"
	btn_yes.text = "MENU_YES"
	btn_no.text = "MENU_NO"
	loading_label.text = "LOADING"
	loading_label.visible = show_loading_title

	_ensure_translations()
	_lang = GameSettings.language
	TranslationServer.set_locale(_lang)
	_custom_night_ouz_level = GameSettings.custom_night_ouz_level
	_custom_night_mayinmelih_level = GameSettings.custom_night_mayinmelih_level
	_refresh_menu_texts()
	_flag_en_tex = _trim_transparent(FLAG_EN)
	_flag_tr_tex = _trim_transparent(FLAG_TR)

	_style_labels()
	_style_buttons()
	_style_settings_button()
	_setup_settings_controls()
	_style_settings_controls()
	_setup_custom_night_controls()
	_style_custom_night_controls()
	_update_start_night_button_state()
	_style_progress_bar()
	_style_flag()
	_layout_loading_bar()
	_set_loading_visible(false)

	menu_vbox.add_theme_constant_override("separation", 56)
	buttons_row.add_theme_constant_override("separation", 56)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_vbox.add_theme_constant_override("separation", 24)

	_update_flag()
	_update_percent_label()

	btn_yes.pressed.connect(_on_yes_pressed)
	btn_no.pressed.connect(_on_no_pressed)
	custom_night_button.pressed.connect(_on_custom_night_open_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	close_settings_button.pressed.connect(_on_settings_close_pressed)
	close_custom_night_button.pressed.connect(_on_custom_night_close_pressed)
	start_night_button.pressed.connect(_on_custom_night_start_pressed)
	quality_option.item_selected.connect(_on_quality_selected)
	fps_slider.value_changed.connect(_on_fps_slider_changed)
	motion_blur_check.toggled.connect(GameSettings.set_motion_blur_enabled)
	shadows_check.toggled.connect(GameSettings.set_shadows_enabled)
	mobile_check.toggled.connect(GameSettings.set_mobile_mode)
	lang_button.pressed.connect(_on_lang_button_pressed)

	if not OS.has_feature("mobile") and not OS.has_feature("android"):
		for button: Button in [
			btn_yes, btn_no, custom_night_button, settings_button, close_settings_button,
			close_custom_night_button
		]:
			button.mouse_entered.connect(_play_hover_audio)
		start_night_button.mouse_entered.connect(_on_start_night_button_hovered)
		lang_button.mouse_entered.connect(_play_hover_audio)

	set_process(false)


func _ensure_translations() -> void:
	if TranslationServer.get_loaded_locales().size() > 0:
		return
	for path in ["res://translations/texts.en.translation", "res://translations/texts.tr.translation"]:
		var t := load(path) as Translation
		if t:
			TranslationServer.add_translation(t)
		else:
			push_error("Çeviri dosyası yüklenemedi: " + path)


func _trim_transparent(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used)
	return atlas


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if custom_font:
		label.add_theme_font_override("font", custom_font)


func _style_labels() -> void:
	_style_label(title_label, title_size)
	_style_label(loading_label, loading_size)
	_style_label(percent_label, percent_size)


func _style_buttons() -> void:
	for b: Button in [btn_yes, btn_no, custom_night_button, settings_button, start_night_button]:
		var pressed_style := _make_style(BTN_PRESSED)
		b.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
		b.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", pressed_style)
		b.add_theme_stylebox_override("hover_pressed", pressed_style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", button_size)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(color_name, Color.WHITE)
		if custom_font:
			b.add_theme_font_override("font", custom_font)
		b.focus_mode = Control.FOCUS_NONE
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = button_min_size


func _on_start_night_button_hovered() -> void:
	if _is_start_night_allowed():
		_play_hover_audio()


func _is_start_night_allowed() -> bool:
	return _custom_night_ouz_level > 0 or _custom_night_mayinmelih_level > 0


func _is_max_custom_night() -> bool:
	return _custom_night_ouz_level == 20 and _custom_night_mayinmelih_level == 20


func _update_start_night_button_state() -> void:
	if not start_night_button or not is_instance_valid(start_night_button):
		return
	start_night_button.text = tr("START_NIGHT_SURE") if _is_max_custom_night() else tr("START_NIGHT")
	var enabled := _is_start_night_allowed()
	var normal_style := _make_style(BTN_NORMAL)
	start_night_button.disabled = not enabled
	start_night_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	start_night_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if enabled:
		var pressed_style := _make_style(BTN_PRESSED)
		start_night_button.add_theme_stylebox_override("normal", normal_style)
		start_night_button.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
		start_night_button.add_theme_stylebox_override("pressed", pressed_style)
		start_night_button.add_theme_stylebox_override("hover_pressed", pressed_style)
		start_night_button.add_theme_stylebox_override("disabled", normal_style)
		start_night_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		start_night_button.add_theme_stylebox_override("normal", normal_style)
		start_night_button.add_theme_stylebox_override("hover", normal_style)
		start_night_button.add_theme_stylebox_override("pressed", normal_style)
		start_night_button.add_theme_stylebox_override("hover_pressed", normal_style)
		start_night_button.add_theme_stylebox_override("disabled", normal_style)
		start_night_button.modulate = Color(1.0, 1.0, 1.0, 0.5)


func _style_settings_button() -> void:
	settings_button.reparent(self)
	settings_button.z_index = 0
	settings_button.text = ""
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	settings_button.offset_left = 16.0
	settings_button.offset_top = 16.0
	settings_button.offset_right = 112.0
	settings_button.offset_bottom = 112.0
	settings_button.custom_minimum_size = Vector2(96.0, 96.0)
	settings_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	settings_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	settings_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	settings_button.add_theme_stylebox_override("hover_pressed", StyleBoxEmpty.new())
	settings_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	settings_button.modulate = Color(0.8, 0.8, 0.8)
	settings_button.mouse_entered.connect(_on_settings_button_hovered)
	settings_button.mouse_exited.connect(_on_settings_button_unhovered)
	settings_button.button_down.connect(_on_settings_button_down)
	settings_button.button_up.connect(_on_settings_button_up)
	var icon := settings_button.get_node("Icon") as TextureRect
	icon.texture = SETTINGS_ICON
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE


func _setup_settings_controls() -> void:
	_refresh_settings_option_labels()
	motion_blur_check.button_pressed = GameSettings.motion_blur_enabled
	shadows_check.button_pressed = GameSettings.shadows_enabled
	mobile_check.button_pressed = GameSettings.mobile_mode
	fps_slider.set_value_no_signal(maxi(GameSettings.FPS_LIMITS.find(GameSettings.max_fps), 0))
	_update_fps_value_label(int(fps_slider.value))


func _refresh_settings_option_labels() -> void:
	quality_option.clear()
	for key: String in QUALITY_LABEL_KEYS:
		quality_option.add_item(tr(key))
	quality_option.select(GameSettings.QUALITY_OPTIONS.find(GameSettings.quality))

	_update_fps_value_label(int(fps_slider.value))


func _style_settings_controls() -> void:
	var setting_labels: Array[Label] = [
		$SettingsPage/ContentCenter/SettingsContent/QualityRow/QualityLabel,
		$SettingsPage/ContentCenter/SettingsContent/FpsRow/FpsLabel,
	]
	var label_width := 0.0
	for label: Label in setting_labels:
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		if custom_font:
			label.add_theme_font_override("font", custom_font)
		label_width = maxf(label_width, label.get_combined_minimum_size().x)
	for label: Label in setting_labels:
		label.custom_minimum_size = Vector2(label_width, label.custom_minimum_size.y)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for option: OptionButton in [quality_option]:
		option.focus_mode = Control.FOCUS_NONE
		option.add_theme_font_size_override("font_size", 24)
		option.add_theme_color_override("font_color", Color.WHITE)
		var option_style := StyleBoxFlat.new()
		option_style.bg_color = Color(0.20, 0.20, 0.20)
		option_style.set_content_margin_all(10.0)
		option.add_theme_stylebox_override("normal", option_style)
		option.add_theme_stylebox_override("hover", option_style)
		option.add_theme_stylebox_override("pressed", option_style)
		if custom_font:
			option.add_theme_font_override("font", custom_font)
	fps_slider.focus_mode = Control.FOCUS_NONE
	fps_value_label.add_theme_font_size_override("font_size", 24)
	fps_value_label.add_theme_color_override("font_color", Color.WHITE)
	fps_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if custom_font:
		fps_value_label.add_theme_font_override("font", custom_font)

	for checkbox: CheckButton in [motion_blur_check, shadows_check, mobile_check]:
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.add_theme_font_size_override("font_size", 24)
		checkbox.add_theme_color_override("font_color", Color.WHITE)
		if custom_font:
			checkbox.add_theme_font_override("font", custom_font)
	mobile_check.disabled = GameSettings.is_android

	close_settings_button.focus_mode = Control.FOCUS_NONE
	close_settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_settings_button.add_theme_font_size_override("font_size", 64)
	close_settings_button.add_theme_color_override("font_color", Color.WHITE)
	if custom_font:
		close_settings_button.add_theme_font_override("font", custom_font)


func _setup_custom_night_controls() -> void:
	ouz_portrait.texture = CUSTOM_NIGHT_OUZ_PORTRAIT
	melih_portrait.texture = CUSTOM_NIGHT_MELIH_PORTRAIT

	var down_image := CUSTOM_NIGHT_ARROW.get_image()
	var down_texture: Texture2D = CUSTOM_NIGHT_ARROW
	if down_image:
		down_image.flip_y()
		down_texture = ImageTexture.create_from_image(down_image)
	else:
		push_error("Custom Night arrow image could not be loaded.")

	_configure_custom_night_arrow(ouz_level_up_button, CUSTOM_NIGHT_ARROW)
	_configure_custom_night_arrow(ouz_level_down_button, down_texture)
	_configure_custom_night_arrow(melih_level_up_button, CUSTOM_NIGHT_ARROW)
	_configure_custom_night_arrow(melih_level_down_button, down_texture)

	ouz_level_up_button.button_down.connect(_on_custom_night_arrow_down.bind(Difficulties.OUZ, 1, ouz_level_up_button))
	ouz_level_up_button.button_up.connect(_on_custom_night_arrow_up.bind(ouz_level_up_button))
	ouz_level_down_button.button_down.connect(_on_custom_night_arrow_down.bind(Difficulties.OUZ, -1, ouz_level_down_button))
	ouz_level_down_button.button_up.connect(_on_custom_night_arrow_up.bind(ouz_level_down_button))
	melih_level_up_button.button_down.connect(_on_custom_night_arrow_down.bind(Difficulties.MAYINMELIH, 1, melih_level_up_button))
	melih_level_up_button.button_up.connect(_on_custom_night_arrow_up.bind(melih_level_up_button))
	melih_level_down_button.button_down.connect(_on_custom_night_arrow_down.bind(Difficulties.MAYINMELIH, -1, melih_level_down_button))
	melih_level_down_button.button_up.connect(_on_custom_night_arrow_up.bind(melih_level_down_button))
	for button: TextureButton in [
		ouz_level_up_button, ouz_level_down_button, melih_level_up_button, melih_level_down_button
	]:
		button.mouse_entered.connect(_on_custom_night_arrow_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_custom_night_arrow_mouse_exited.bind(button))

	_custom_night_repeat_timer = Timer.new()
	_custom_night_repeat_timer.one_shot = true
	_custom_night_repeat_timer.timeout.connect(_repeat_custom_night_level)
	add_child(_custom_night_repeat_timer)
	_refresh_custom_night_level_labels()


func _configure_custom_night_arrow(button: TextureButton, texture: Texture2D) -> void:
	button.texture_normal = texture
	button.texture_hover = texture
	button.texture_pressed = texture
	button.modulate = Color(0.68, 0.68, 0.68)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(100.0, 84.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_custom_night_controls() -> void:
	custom_night_page.z_index = 11
	for panel: Panel in [ouz_portrait_panel, melih_portrait_panel]:
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color.BLACK
		frame_style.border_color = Color.WHITE
		frame_style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", frame_style)

	for portrait: TextureRect in [ouz_portrait, melih_portrait]:
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var level_font := SystemFont.new()
	level_font.font_names = PackedStringArray([
		"Courier New", "Consolas", "Arial", "DejaVu Sans"
	])
	for label: Label in [ouz_level_label, melih_level_label]:
		label.add_theme_font_override("font", level_font)
		label.add_theme_font_size_override("font_size", 48)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	custom_night_button.custom_minimum_size = Vector2(280.0, 64.0)
	btn_yes.custom_minimum_size = Vector2(
		maxf(btn_yes.custom_minimum_size.x, custom_night_button.custom_minimum_size.x),
		btn_yes.custom_minimum_size.y
	)
	btn_no.custom_minimum_size = btn_yes.custom_minimum_size
	btn_no.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	start_night_button.custom_minimum_size = Vector2(360.0, 72.0)
	start_night_button.add_theme_font_size_override("font_size", button_size)
	close_custom_night_button.focus_mode = Control.FOCUS_NONE
	close_custom_night_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_custom_night_button.add_theme_font_size_override("font_size", 64)
	close_custom_night_button.add_theme_color_override("font_color", Color.WHITE)
	var close_pressed_style := _make_style(BTN_PRESSED)
	close_custom_night_button.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
	close_custom_night_button.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
	close_custom_night_button.add_theme_stylebox_override("pressed", close_pressed_style)
	close_custom_night_button.add_theme_stylebox_override("hover_pressed", close_pressed_style)
	close_custom_night_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		close_custom_night_button.add_theme_color_override(color_name, Color.WHITE)
	if custom_font:
		close_custom_night_button.add_theme_font_override("font", custom_font)


func _refresh_menu_texts() -> void:
	title_label.text = tr("MENU_READY")
	btn_yes.text = tr("MENU_YES")
	btn_no.text = tr("MENU_NO")
	custom_night_button.text = tr("MENU_CUSTOM_NIGHT")
	loading_label.text = tr("LOADING")
	close_settings_button.text = tr("CLOSE")
	close_custom_night_button.text = tr("CLOSE")
	start_night_button.text = tr("START_NIGHT")
	_update_start_night_button_state()


func _refresh_custom_night_level_labels() -> void:
	ouz_level_label.text = str(_custom_night_ouz_level)
	melih_level_label.text = str(_custom_night_mayinmelih_level)
	_update_start_night_button_state()


func _randomize_custom_night_portrait_opacity() -> void:
	for portrait: TextureRect in [ouz_portrait, melih_portrait]:
		var tint := portrait.modulate
		tint.a = randf_range(0.67, 1.0)
		portrait.modulate = tint


func _change_custom_night_level(animatronic: StringName, amount: int) -> bool:
	var previous_level := -1
	if animatronic == Difficulties.OUZ:
		previous_level = _custom_night_ouz_level
		_custom_night_ouz_level = clampi(_custom_night_ouz_level + amount, 0, 20)
	elif animatronic == Difficulties.MAYINMELIH:
		previous_level = _custom_night_mayinmelih_level
		_custom_night_mayinmelih_level = clampi(_custom_night_mayinmelih_level + amount, 0, 20)
	if previous_level < 0:
		return false
	var changed := previous_level != _custom_night_ouz_level if animatronic == Difficulties.OUZ else previous_level != _custom_night_mayinmelih_level
	if changed:
		_refresh_custom_night_level_labels()
		GameSettings.set_custom_night_levels(_custom_night_ouz_level, _custom_night_mayinmelih_level)
	return changed


func _on_custom_night_arrow_mouse_entered(button: TextureButton) -> void:
	if not _custom_night_hovered_buttons.has(button):
		_custom_night_hovered_buttons.append(button)
	button.modulate = Color(0.35, 0.35, 0.35) if button == _held_custom_night_button and _custom_night_button_held else Color.WHITE
	_play_hover_audio()


func _on_custom_night_arrow_mouse_exited(button: TextureButton) -> void:
	_custom_night_hovered_buttons.erase(button)
	button.modulate = Color(0.35, 0.35, 0.35) if button == _held_custom_night_button and _custom_night_button_held else Color(0.68, 0.68, 0.68)


func _on_custom_night_arrow_down(animatronic: StringName, amount: int, button: TextureButton) -> void:
	_stop_custom_night_level_repeat()
	_held_custom_night_button = button
	_held_custom_night_animatronic = animatronic
	_held_custom_night_delta = amount
	_custom_night_button_held = true
	button.modulate = Color(0.35, 0.35, 0.35)
	_play_click_audio()
	_change_custom_night_level(animatronic, amount)
	_custom_night_repeat_timer.start(0.35)


func _on_custom_night_arrow_up(button: TextureButton) -> void:
	if button == _held_custom_night_button:
		_stop_custom_night_level_repeat()
	button.modulate = Color.WHITE if _custom_night_hovered_buttons.has(button) else Color(0.68, 0.68, 0.68)


func _repeat_custom_night_level() -> void:
	if not _custom_night_button_held or not custom_night_page.visible:
		_stop_custom_night_level_repeat()
		return
	if _change_custom_night_level(_held_custom_night_animatronic, _held_custom_night_delta):
		_play_click_audio()
	_custom_night_repeat_timer.start(0.08)


func _update_custom_night_arrow_hold() -> void:
	if not custom_night_page.visible:
		if _custom_night_mouse_hold_detected:
			_stop_custom_night_level_repeat()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _custom_night_mouse_hold_detected:
			_stop_custom_night_level_repeat()
		return
	for button: TextureButton in [
		ouz_level_up_button, ouz_level_down_button, melih_level_up_button, melih_level_down_button
	]:
		if button.disabled or not button.get_global_rect().has_point(button.get_global_mouse_position()):
			continue
		if button != _held_custom_night_button:
			if button == ouz_level_up_button:
				_on_custom_night_arrow_down(Difficulties.OUZ, 1, button)
			elif button == ouz_level_down_button:
				_on_custom_night_arrow_down(Difficulties.OUZ, -1, button)
			elif button == melih_level_up_button:
				_on_custom_night_arrow_down(Difficulties.MAYINMELIH, 1, button)
			else:
				_on_custom_night_arrow_down(Difficulties.MAYINMELIH, -1, button)
		_custom_night_mouse_hold_detected = true
		return
	if _custom_night_mouse_hold_detected:
		_stop_custom_night_level_repeat()


func _stop_custom_night_level_repeat() -> void:
	if _custom_night_repeat_timer:
		_custom_night_repeat_timer.stop()
	var was_held := _custom_night_button_held
	if _held_custom_night_button:
		_held_custom_night_button.modulate = Color.WHITE if _custom_night_hovered_buttons.has(_held_custom_night_button) else Color(0.68, 0.68, 0.68)
	_custom_night_button_held = false
	_custom_night_mouse_hold_detected = false
	_held_custom_night_button = null
	_held_custom_night_animatronic = &""
	_held_custom_night_delta = 0
	if was_held:
		GameSettings.set_custom_night_levels(_custom_night_ouz_level, _custom_night_mayinmelih_level)


func _on_settings_button_hovered() -> void:
	settings_button.modulate = Color.WHITE


func _on_settings_button_unhovered() -> void:
	settings_button.modulate = Color(0.8, 0.8, 0.8)


func _on_settings_button_down() -> void:
	settings_button.modulate = Color(0.35, 0.35, 0.35)


func _on_settings_button_up() -> void:
	settings_button.modulate = Color.WHITE


func _on_settings_button_pressed() -> void:
	_play_click_audio()
	settings_page.visible = true


func _on_settings_close_pressed() -> void:
	_play_click_audio()
	settings_page.visible = false


func _on_custom_night_open_pressed() -> void:
	if _loading or not GameSettings.custom_night_unlocked:
		return
	_play_click_audio()
	_stop_custom_night_level_repeat()
	menu_page.visible = false
	custom_night_page.visible = true
	_custom_night_portrait_alpha_elapsed = 0.0
	_randomize_custom_night_portrait_opacity()
	_update_start_night_button_state()
	set_process(true)


func _on_custom_night_close_pressed() -> void:
	_play_click_audio()
	_stop_custom_night_level_repeat()
	custom_night_page.visible = false
	menu_page.visible = true
	set_process(false)
	GameSettings.set_custom_night_levels(_custom_night_ouz_level, _custom_night_mayinmelih_level)


func _on_custom_night_start_pressed() -> void:
	if _loading or not _is_start_night_allowed():
		return
	_stop_custom_night_level_repeat()
	GameSettings.set_custom_night_levels(_custom_night_ouz_level, _custom_night_mayinmelih_level)
	Difficulties.custom_night_active = true
	Difficulties.ouz_enabled = _custom_night_ouz_level > 0
	Difficulties.mayinmelih_enabled = _custom_night_mayinmelih_level > 0
	if _custom_night_ouz_level > 0:
		Difficulties.set_level(Difficulties.OUZ, _custom_night_ouz_level)
	if _custom_night_mayinmelih_level > 0:
		Difficulties.set_level(Difficulties.MAYINMELIH, _custom_night_mayinmelih_level)
	_start_game()


func _on_quality_selected(index: int) -> void:
	if index >= 0 and index < GameSettings.QUALITY_OPTIONS.size():
		GameSettings.set_quality(GameSettings.QUALITY_OPTIONS[index])
		motion_blur_check.set_pressed_no_signal(GameSettings.motion_blur_enabled)
		shadows_check.set_pressed_no_signal(GameSettings.shadows_enabled)


func _on_fps_slider_changed(value: float) -> void:
	var index := clampi(roundi(value), 0, GameSettings.FPS_LIMITS.size() - 1)
	GameSettings.set_max_fps(GameSettings.FPS_LIMITS[index])
	_update_fps_value_label(index)


func _update_fps_value_label(index: int) -> void:
	if fps_value_label and is_instance_valid(fps_value_label):
		var bounded_index := clampi(index, 0, FPS_LABEL_KEYS.size() - 1)
		fps_value_label.text = tr(FPS_LABEL_KEYS[bounded_index])


func _make_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = button_margin
	sb.texture_margin_right = button_margin
	sb.texture_margin_top = button_margin
	sb.texture_margin_bottom = button_margin
	return sb


func _style_progress_bar() -> void:
	load_progress.show_percentage = false
	load_progress.min_value = 0.0
	load_progress.max_value = 100.0
	load_progress.value = 0.0
	load_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := StyleBoxFlat.new()
	bg.bg_color = bar_track_color
	bg.set_content_margin_all(0.0)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_content_margin_all(0.0)

	load_progress.add_theme_stylebox_override("background", bg)
	load_progress.add_theme_stylebox_override("fill", fill)


func _layout_loading_bar() -> void:
	load_progress.reparent(self, false)
	percent_label.reparent(self, false)

	load_progress.custom_minimum_size = Vector2(0.0, bar_thickness)
	load_progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0)

	percent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	percent_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	percent_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	percent_label.offset_right = -percent_margin
	percent_label.offset_bottom = -(bar_thickness + percent_gap)
	percent_label.offset_left = percent_label.offset_right
	percent_label.offset_top = percent_label.offset_bottom


func _set_loading_visible(on: bool) -> void:
	loading_page.visible = on
	load_progress.visible = on
	percent_label.visible = on


func _style_flag() -> void:
	lang_button.ignore_texture_size = true
	lang_button.stretch_mode = TextureButton.STRETCH_SCALE
	lang_button.custom_minimum_size = flag_size
	lang_button.focus_mode = Control.FOCUS_NONE
	lang_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	lang_button.mouse_filter = Control.MOUSE_FILTER_STOP
	lang_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	lang_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lang_button.offset_right = -24.0
	lang_button.offset_left = -24.0 - flag_size.x
	lang_button.offset_top = 24.0
	lang_button.offset_bottom = 24.0 + flag_size.y

	lang_button.modulate = Color(0.85, 0.85, 0.85)
	if not OS.has_feature("mobile") and not OS.has_feature("android"):
		lang_button.mouse_entered.connect(func() -> void: lang_button.modulate = Color.WHITE)
		lang_button.mouse_exited.connect(func() -> void: lang_button.modulate = Color(0.85, 0.85, 0.85))


func _on_lang_button_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_lang_toggle_msec < 120:
		return
	_last_lang_toggle_msec = now
	_play_click_audio()
	_toggle_language()


func _toggle_language() -> void:
	_lang = "tr" if _lang == "en" else "en"
	GameSettings.set_language(_lang)
	TranslationServer.set_locale(_lang)
	_refresh_menu_texts()
	_refresh_settings_option_labels()
	_style_settings_controls()
	_update_flag()
	_last_pct = -1
	_update_percent_label()


func _update_flag() -> void:
	lang_button.texture_normal = _flag_tr_tex if _lang == "tr" else _flag_en_tex


func _percent_text(value: int) -> String:
	var fmt := tr("LOADING_PERCENT")
	if fmt.contains("%d"):
		return fmt % value
	return "%d%%" % value


func _update_percent_label() -> void:
	var pct := int(_shown)
	if pct == _last_pct:
		return
	_last_pct = pct
	percent_label.text = _percent_text(pct)


func _on_no_pressed() -> void:
	_play_click_audio()
	await click_audio.finished
	get_tree().quit()


func _play_hover_audio() -> void:
	_play_ui_audio(hover_audio)


func _play_click_audio() -> void:
	_play_ui_audio(click_audio)


func _play_ui_audio(player: AudioStreamPlayer2D) -> void:
	if player.stream == null:
		return
	player.stop()
	player.play()


func _on_yes_pressed() -> void:
	if _loading:
		return
	Difficulties.custom_night_active = false
	Difficulties.ouz_enabled = true
	Difficulties.mayinmelih_enabled = true
	Difficulties.set_level(Difficulties.OUZ, 10)
	Difficulties.set_level(Difficulties.MAYINMELIH, 10)
	_start_game()


func _start_game() -> void:
	if _loading:
		return
	_play_click_audio()
	_stop_custom_night_level_repeat()
	_loading = true
	_load_done = false
	_shown = 0.0
	_last_pct = -1
	load_progress.value = 0.0
	loading_label.text = tr("GOOD_LUCK") if Difficulties.custom_night_active and _custom_night_ouz_level == 20 and _custom_night_mayinmelih_level == 20 else tr("LOADING")
	_update_percent_label()

	menu_page.visible = false
	settings_page.visible = false
	custom_night_page.visible = false
	settings_button.visible = false
	lang_button.visible = false
	_set_loading_visible(true)

	var err := ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
	if err != OK:
		push_warning("Arka plan yüklemesi başlatılamadı; doğrudan yükleme deneniyor: " + GAME_SCENE)
		set_process(false)
		call_deferred("_fallback_load_game_scene")
		return
	set_process(true)


func _cancel_loading() -> void:
	_loading = false
	set_process(false)
	_set_loading_visible(false)
	menu_page.visible = true
	settings_page.visible = false
	custom_night_page.visible = false
	settings_button.visible = true
	lang_button.visible = true


func _process(delta: float) -> void:
	if not _loading:
		_update_custom_night_arrow_hold()
		if custom_night_page.visible:
			_custom_night_portrait_alpha_elapsed += delta
			while _custom_night_portrait_alpha_elapsed >= 0.1:
				_custom_night_portrait_alpha_elapsed -= 0.1
				_randomize_custom_night_portrait_opacity()
		else:
			_custom_night_portrait_alpha_elapsed = 0.0
		return
	var target := 100.0

	if not _load_done:
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, _progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				target = float(_progress[0]) * 100.0
			ResourceLoader.THREAD_LOAD_LOADED:
				_load_done = true
			_:
				push_warning("Arka plan yüklemesi başarısız; doğrudan yükleme deneniyor: " + GAME_SCENE)
				set_process(false)
				call_deferred("_fallback_load_game_scene")
				return

	_shown = move_toward(_shown, target, bar_speed * delta)
	load_progress.value = _shown
	_update_percent_label()

	if _load_done and _shown >= 100.0:
		set_process(false)
		_finish()


func _finish() -> void:
	await get_tree().create_timer(finish_delay).timeout
	var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if packed == null:
		push_warning("Arka plan yüklemesi sahneyi vermedi; doğrudan yükleme deneniyor: " + GAME_SCENE)
		_fallback_load_game_scene()
		return
	get_tree().change_scene_to_packed(packed)


func _fallback_load_game_scene() -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
		return
	push_error("Oyun sahnesi yüklenemedi: " + GAME_SCENE)
	_cancel_loading()
