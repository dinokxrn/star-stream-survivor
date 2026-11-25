extends Control

const UiTheme = preload("res://scripts/ui/UiTheme.gd")

var _controls_root: Control
var _toggle_btn: Button
var _exit_btn: Button
var _visible_on_screen: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.create_theme()

	# Auto-show on touch devices / mobile web (iPhone, iPad, Android)
	_visible_on_screen = (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("web_ios")
		or OS.has_feature("web_android")
		or OS.has_feature("mobile")
	)

	_controls_root = Control.new()
	_controls_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_root.visible = _visible_on_screen
	add_child(_controls_root)

	# Small toggle button at top-center so desktop users can test touch buttons too
	_toggle_btn = Button.new()
	_toggle_btn.text = "📱 ปุ่มมือถือ"
	_toggle_btn.position = Vector2(722, 12)
	_toggle_btn.custom_minimum_size = Vector2(122, 30)
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(func():
		_visible_on_screen = not _visible_on_screen
		_controls_root.visible = _visible_on_screen
	)
	add_child(_toggle_btn)

	# --- LEFT SIDE: Move Left / Right + Jump / Dash ---
	_make_hold_btn("◀", "move_left", Vector2(26, 515), Vector2(88, 88), 28)
	_make_hold_btn("▶", "move_right", Vector2(126, 515), Vector2(88, 88), 28)
	_make_tap_btn("กระโดด", "jump", Vector2(26, 430), Vector2(92, 70), 16)
	_make_tap_btn("พุ่งหลบ", "dash", Vector2(126, 430), Vector2(92, 70), 16)

	# --- RIGHT SIDE: Attack, Parry, Interact + Skills 1/2/3/R + Items Q/E ---
	_make_tap_btn("โจมตี", "attack", Vector2(1148, 505), Vector2(106, 98), 20, Color(0.55, 0.14, 0.18, 0.85), Color(1.0, 0.45, 0.45))
	_make_tap_btn("ปัดป้อง", "parry", Vector2(1042, 515), Vector2(96, 86), 17, Color(0.42, 0.32, 0.06, 0.85), UiTheme.COL_GOLD)
	_make_tap_btn("โต้ตอบ [F]", "interact", Vector2(1148, 422), Vector2(106, 70), 15, Color(0.08, 0.36, 0.24, 0.85), Color(0.35, 0.96, 0.58))

	_make_tap_btn("สกิล 1", "skill_1", Vector2(950, 428), Vector2(86, 58), 14)
	_make_tap_btn("สกิล 2", "skill_2", Vector2(1044, 428), Vector2(94, 58), 14)
	_make_tap_btn("สกิล 3", "skill_3", Vector2(950, 360), Vector2(86, 58), 14)
	_make_tap_btn("★ สติกมา", "stigma_skill", Vector2(1044, 360), Vector2(94, 58), 14, Color(0.36, 0.25, 0.04, 0.88), UiTheme.COL_GOLD)

	_make_tap_btn("ยา [Q]", "item_1", Vector2(856, 520), Vector2(82, 58), 14)
	_make_tap_btn("ยา [E]", "item_2", Vector2(948, 520), Vector2(82, 58), 14)

	# --- TOP UTILITY: Status, Shop, Exit Train ---
	_make_tap_btn("สเตตัส", "toggle_status", Vector2(416, 12), Vector2(106, 44), 15)
	_make_tap_btn("ถุงโดแกบี", "toggle_shop", Vector2(734, 12), Vector2(112, 44), 15, Color(0.36, 0.25, 0.04, 0.88), UiTheme.COL_GOLD)
	_exit_btn = _make_tap_btn("ออกรถไฟ [G]", "exit_train", Vector2(560, 52), Vector2(150, 42), 14, Color(0.10, 0.38, 0.24, 0.9), Color(0.4, 1.0, 0.65))
	_exit_btn.visible = false


func _process(_delta: float) -> void:
	if _exit_btn != null:
		_exit_btn.visible = ScenarioManager.is_farming


func _make_hold_btn(label_txt: String, action_name: String, pos: Vector2, sz: Vector2, fsize: int) -> Button:
	var b := Button.new()
	b.text = label_txt
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_stylebox_override("normal", UiTheme.make_button_style(Color(0.05, 0.14, 0.26, 0.72), Color(0.22, 0.74, 0.97, 0.85)))
	b.button_down.connect(func(): Input.action_press(action_name))
	b.button_up.connect(func(): Input.action_release(action_name))
	_controls_root.add_child(b)
	return b


func _make_tap_btn(label_txt: String, action_name: String, pos: Vector2, sz: Vector2, fsize: int, bg_col: Color = Color(0.05, 0.14, 0.26, 0.72), border_col: Color = Color(0.22, 0.74, 0.97, 0.85)) -> Button:
	var b := Button.new()
	b.text = label_txt
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_stylebox_override("normal", UiTheme.make_button_style(bg_col, border_col))
	b.button_down.connect(func():
		Input.action_press(action_name)
		call_deferred("_release_action", action_name)
	)
	_controls_root.add_child(b)
	return b


func _release_action(action_name: String) -> void:
	Input.action_release(action_name)
