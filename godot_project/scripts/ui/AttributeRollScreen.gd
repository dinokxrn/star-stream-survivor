extends Control

const UiTheme = preload("res://scripts/ui/UiTheme.gd")
const GameData = preload("res://scripts/data/GameData.gd")
const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")

signal start_game_requested(attr_id: String)
signal continue_save_requested

var _rolled_attr: Dictionary = {}
var _char_idx: int = 0
var _char_preview: TextureRect
var _char_name_lbl: Label
var _name_lbl: Label
var _rarity_lbl: Label
var _stats_lbl: Label
var _gear_lbl: Label
var _passive_lbl: Label
var _reroll_count: int = 0
var _reroll_btn: Button
var _start_btn: Button
var _continue_btn: Button
var _name_input: LineEdit
var _code_input: LineEdit
var _create_room_btn: Button
var _join_room_btn: Button
var _copy_code_btn: Button
var _leave_room_btn: Button
var _coop_status_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.create_theme()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.09, 0.96)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 610)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BORDER, UiTheme.COL_BG, 3))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var sys_header := Label.new()
	sys_header.text = "[ STAR STREAM — หน้าต่างสร้างข้อมูลผู้รอดชีวิต ]"
	sys_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sys_header.add_theme_font_override("font", UiTheme.load_font(true))
	sys_header.add_theme_font_size_override("font_size", 24)
	sys_header.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	vbox.add_child(sys_header)

	var subtitle := Label.new()
	subtitle.text = "รถไฟใต้ดินสาย 3 — ขบวน 3707 | คุณไม่ใช่กลุ่มตัวเอก แต่บทละครแรกกำลังจะเริ่มขึ้นในตู้ของคุณ"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# 10 Playable Character Selector (Male, Female, Kid, Elder)
	var char_row := HBoxContainer.new()
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_row.add_theme_constant_override("separation", 16)
	vbox.add_child(char_row)

	var btn_prev := Button.new()
	btn_prev.text = "◀ ตัวละครก่อนหน้า"
	btn_prev.pressed.connect(func():
		_char_idx = (_char_idx - 1 + GameData.CHARACTERS.size()) % GameData.CHARACTERS.size()
		SfxManager.play("coin")
		_refresh_char()
	)
	char_row.add_child(btn_prev)

	_char_preview = TextureRect.new()
	_char_preview.custom_minimum_size = Vector2(64, 80)
	_char_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	char_row.add_child(_char_preview)

	_char_name_lbl = Label.new()
	_char_name_lbl.custom_minimum_size = Vector2(280, 44)
	_char_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_char_name_lbl.add_theme_font_size_override("font_size", 16)
	_char_name_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	char_row.add_child(_char_name_lbl)

	var btn_next := Button.new()
	btn_next.text = "ตัวละครถัดไป ▶"
	btn_next.pressed.connect(func():
		_char_idx = (_char_idx + 1) % GameData.CHARACTERS.size()
		SfxManager.play("coin")
		_refresh_char()
	)
	char_row.add_child(btn_next)

	# Rolled Attribute card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.25, 0.55, 0.78, 0.8), UiTheme.COL_BG_DARK, 2))
	vbox.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)

	var top_row := HBoxContainer.new()
	cv.add_child(top_row)

	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_override("font", UiTheme.load_font(true))
	_name_lbl.add_theme_font_size_override("font_size", 22)
	top_row.add_child(_name_lbl)

	_rarity_lbl = Label.new()
	_rarity_lbl.add_theme_font_override("font", UiTheme.load_font(true))
	_rarity_lbl.add_theme_font_size_override("font_size", 18)
	top_row.add_child(_rarity_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.add_theme_font_size_override("font_size", 17)
	cv.add_child(_stats_lbl)

	_gear_lbl = Label.new()
	_gear_lbl.add_theme_font_size_override("font_size", 16)
	_gear_lbl.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	cv.add_child(_gear_lbl)

	_passive_lbl = Label.new()
	_passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive_lbl.add_theme_font_size_override("font_size", 16)
	_passive_lbl.add_theme_color_override("font_color", Color(0.68, 0.94, 0.82))
	cv.add_child(_passive_lbl)

	var controls_hint := Label.new()
	controls_hint.text = "การควบคุม: WASD เคลื่อนที่/กระโดด | Space โจมตีปกติ | J/K/L สกิล | N/M แพรี่ | Q ไอเทม | E แอนทริบิว | Tab สเตตัส/ซื้อของ | F โต้ตอบ"
	controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.add_theme_font_size_override("font_size", 14)
	controls_hint.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	vbox.add_child(controls_hint)

	# Online Co-op Room Panel (up to 4 players via 4-char code)
	var coop_card := PanelContainer.new()
	coop_card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.22, 0.85, 0.72, 0.85), Color(0.03, 0.08, 0.14, 0.94), 2))
	vbox.add_child(coop_card)

	var coop_v := VBoxContainer.new()
	coop_v.add_theme_constant_override("separation", 6)
	coop_card.add_child(coop_v)

	var coop_row := HBoxContainer.new()
	coop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coop_row.add_theme_constant_override("separation", 8)
	coop_v.add_child(coop_row)

	var coop_tag := Label.new()
	coop_tag.text = "🌐 เล่นหลายคน (Co-op 4 คน):"
	coop_tag.add_theme_font_size_override("font_size", 14)
	coop_tag.add_theme_color_override("font_color", Color(0.45, 0.96, 0.85))
	coop_row.add_child(coop_tag)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "ชื่อผู้เล่น"
	_name_input.text = "ผู้รอดชีวิต"
	_name_input.max_length = 18
	_name_input.custom_minimum_size = Vector2(130, 34)
	coop_row.add_child(_name_input)

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "โค้ดห้อง 4 หลัก"
	_code_input.max_length = 6
	_code_input.custom_minimum_size = Vector2(120, 34)
	coop_row.add_child(_code_input)

	_create_room_btn = Button.new()
	_create_room_btn.text = "สร้างห้อง"
	_create_room_btn.custom_minimum_size = Vector2(96, 34)
	_create_room_btn.pressed.connect(_on_create_room)
	coop_row.add_child(_create_room_btn)

	_join_room_btn = Button.new()
	_join_room_btn.text = "เข้าห้อง"
	_join_room_btn.custom_minimum_size = Vector2(84, 34)
	_join_room_btn.pressed.connect(_on_join_room)
	coop_row.add_child(_join_room_btn)

	_copy_code_btn = Button.new()
	_copy_code_btn.text = "คัดลอกรหัส"
	_copy_code_btn.custom_minimum_size = Vector2(96, 34)
	_copy_code_btn.visible = false
	_copy_code_btn.pressed.connect(func():
		if NetworkManager.room_code != "":
			DisplayServer.clipboard_set(NetworkManager.room_code)
			_coop_status_lbl.text = "✓ คัดลอกรหัสห้อง [ %s ] แล้ว! ส่งให้เพื่อนกรอกเข้าห้องได้เลย" % NetworkManager.room_code
	)
	coop_row.add_child(_copy_code_btn)

	_leave_room_btn = Button.new()
	_leave_room_btn.text = "ออกห้อง"
	_leave_room_btn.custom_minimum_size = Vector2(82, 34)
	_leave_room_btn.visible = false
	_leave_room_btn.pressed.connect(func(): NetworkManager.disconnect_room())
	coop_row.add_child(_leave_room_btn)

	_coop_status_lbl = Label.new()
	_coop_status_lbl.text = "โหมด: เล่นคนเดียว (Solo) — กด 'สร้างห้อง' เพื่อรับรหัส 4 หลัก หรือกรอกรหัสเพื่อนแล้วกด 'เข้าห้อง'"
	_coop_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coop_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_status_lbl.add_theme_font_size_override("font_size", 14)
	_coop_status_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	coop_v.add_child(_coop_status_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	_reroll_btn = Button.new()
	_reroll_btn.text = "สุ่มคุณลักษณะใหม่"
	_reroll_btn.custom_minimum_size = Vector2(220, 46)
	_reroll_btn.pressed.connect(_on_reroll)
	btn_row.add_child(_reroll_btn)

	_start_btn = Button.new()
	_start_btn.text = "เข้าสู่บทละครที่ 1 (เล่นคนเดียว)"
	_start_btn.custom_minimum_size = Vector2(260, 46)
	_start_btn.add_theme_stylebox_override("normal", UiTheme.make_button_style(Color(0.08, 0.30, 0.48, 0.98), UiTheme.COL_GOLD))
	_start_btn.pressed.connect(_on_start)
	btn_row.add_child(_start_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "💾 เล่นต่อจากเซฟ"
	_continue_btn.custom_minimum_size = Vector2(220, 46)
	_continue_btn.add_theme_stylebox_override("normal", UiTheme.make_button_style(Color(0.08, 0.38, 0.28, 0.98), Color(0.42, 0.96, 0.72)))
	_continue_btn.pressed.connect(func():
		SfxManager.play("levelup")
		continue_save_requested.emit()
	)
	btn_row.add_child(_continue_btn)
	refresh_save_button()

	NetworkManager.room_joined.connect(_on_net_room_joined)
	NetworkManager.room_updated.connect(_on_net_room_updated)
	NetworkManager.room_disconnected.connect(_on_net_room_disconnected)
	NetworkManager.room_error.connect(_on_net_room_error)

	_char_idx = randi() % GameData.CHARACTERS.size()
	_refresh_char()
	_do_roll()


func _refresh_char() -> void:
	var ch: Dictionary = GameData.CHARACTERS[_char_idx]
	GameState.selected_char_index = _char_idx
	GameState.player_name = String(ch["name"])
	_char_name_lbl.text = "%d/%d: %s\n%s" % [_char_idx + 1, GameData.CHARACTERS.size(), ch["name"], ch["desc"]]
	var tex := SpriteLoader.load_tex(String(ch["sprite"]))
	if tex != null:
		var fw := maxi(32, int(tex.get_width() / 30))
		_char_preview.texture = SpriteLoader.make_atlas(tex, 0, 0, fw, tex.get_height())
	if NetworkManager.is_online and _rolled_attr.has("id"):
		NetworkManager.send_profile_update(_name_input.text, _char_idx, String(_rolled_attr["id"]))


func _do_roll() -> void:
	_rolled_attr = GameState.roll_attribute()
	var rcol := UiTheme.rarity_color(_rolled_attr["rarity_code"])
	_name_lbl.text = "คุณลักษณะเฉพาะ: %s" % _rolled_attr["name"]
	_name_lbl.add_theme_color_override("font_color", rcol)
	_rarity_lbl.text = "[ระดับ: %s]" % _rolled_attr["rarity"]
	_rarity_lbl.add_theme_color_override("font_color", rcol)

	var st: Dictionary = _rolled_attr["stats"]
	_stats_lbl.text = "พละกำลัง (STR): %d   |   ความทนทาน (PHY): %d   |   ความว่องไว (AGI): %d   |   พลังเวท (MAG): %d" % [
		int(st["str"]), int(st["phy"]), int(st["agi"]), int(st["mag"])
	]

	var wname: String = GameData.WEAPONS[_rolled_attr["weapon"]]["name"]
	var skill_names: Array[String] = []
	for sid in _rolled_attr.get("skills", []):
		if GameData.SKILLS.has(sid):
			skill_names.append(GameData.SKILLS[sid]["name"])
	var skills_str := ", ".join(skill_names) if skill_names.size() > 0 else "ไม่มี"
	var item_parts: Array[String] = []
	for iid in _rolled_attr["items"].keys():
		item_parts.append("%s x%d" % [GameData.CONSUMABLES[iid]["name"], int(_rolled_attr["items"][iid])])
	var items_str := ", ".join(item_parts) if item_parts.size() > 0 else "ไม่มี"
	var coins_str := " | +%d เหรียญ" % int(_rolled_attr["bonus_coins"]) if int(_rolled_attr["bonus_coins"]) > 0 else ""
	_gear_lbl.text = "อาวุธ: %s | สกิลเริ่มต้น: %s\nไอเทมติดตัว: %s%s" % [wname, skills_str, items_str, coins_str]
	_passive_lbl.text = "ความสามารถติดตัว [%s]: %s" % [_rolled_attr["passive_name"], _rolled_attr["passive_desc"]]


func get_rolled_attribute_id() -> String:
	return String(_rolled_attr.get("id", "office_worker"))


func refresh_save_button() -> void:
	if _continue_btn == null:
		return
	var summary := GameState.get_save_summary()
	if summary.is_empty():
		_continue_btn.visible = false
	else:
		_continue_btn.visible = true
		var stg := int(summary.get("stage", 1))
		var cns := int(summary.get("coins", 0))
		_continue_btn.text = "💾 เล่นต่อ (ด่าน %d | %d เหรียญ)" % [stg, cns]


func _on_reroll() -> void:
	_reroll_count += 1
	SfxManager.play("system")
	_do_roll()
	if NetworkManager.is_online:
		NetworkManager.send_profile_update(_name_input.text, _char_idx, String(_rolled_attr["id"]))


func _on_create_room() -> void:
	SfxManager.play("system")
	var code := NetworkManager.generate_room_code()
	_code_input.text = code
	_coop_status_lbl.text = "⏳ กำลังสร้างห้อง [ %s ] ..." % code
	NetworkManager.connect_room(code, _name_input.text, _char_idx, get_rolled_attribute_id())


func _on_join_room() -> void:
	SfxManager.play("system")
	var code := _code_input.text.strip_edges().to_upper()
	if code.length() < 2:
		_coop_status_lbl.text = "⚠ กรุณากรอกรหัสห้อง 4 หลักก่อนกดเข้าห้อง"
		return
	_code_input.text = code
	_coop_status_lbl.text = "⏳ กำลังเชื่อมต่อเข้าห้อง [ %s ] ..." % code
	NetworkManager.connect_room(code, _name_input.text, _char_idx, get_rolled_attribute_id())


func _on_net_room_joined(code: String, _peer_id: String, _is_host: bool) -> void:
	SfxManager.play("levelup")
	_code_input.text = code
	_create_room_btn.visible = false
	_join_room_btn.visible = false
	_copy_code_btn.visible = true
	_leave_room_btn.visible = true


func _on_net_room_updated(players: Array, host_id: String, started: bool, stage_num: int) -> void:
	var names: Array[String] = []
	for p in players:
		if p is Dictionary:
			var pid := String(p.get("peer_id", ""))
			var pn := String(p.get("name", pid))
			if pid == host_id:
				pn = "★" + pn
			names.append(pn)
	_coop_status_lbl.text = "🌐 ห้อง [ %s ] (%d/4 คน): %s" % [NetworkManager.room_code, players.size(), ", ".join(names)]
	if NetworkManager.is_host:
		_start_btn.disabled = false
		_start_btn.text = "★ เริ่มลุยด่านพร้อมกัน! (%d คน)" % players.size()
	elif started:
		_start_btn.disabled = false
		_start_btn.text = "เข้าร่วมบทละครที่ %d ทันที!" % stage_num
	else:
		_start_btn.disabled = true
		_start_btn.text = "รอหัวหน้าห้องกดเริ่มเกม..."


func _on_net_room_disconnected(reason: String) -> void:
	_create_room_btn.visible = true
	_join_room_btn.visible = true
	_copy_code_btn.visible = false
	_leave_room_btn.visible = false
	_start_btn.disabled = false
	_start_btn.text = "เข้าสู่บทละครที่ 1 (เล่นคนเดียว)"
	_coop_status_lbl.text = "โหมด: เล่นคนเดียว (Solo) — %s" % reason


func _on_net_room_error(message: String) -> void:
	_coop_status_lbl.text = "⚠ %s" % message


func _on_start() -> void:
	SfxManager.play("system")
	if NetworkManager.is_online and not NetworkManager.is_host and NetworkManager.room_started:
		NetworkManager.stage_start_received.emit(NetworkManager.room_stage)
		return
	start_game_requested.emit(_rolled_attr["id"])
