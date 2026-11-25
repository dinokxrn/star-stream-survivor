extends Control

const UiTheme = preload("res://scripts/ui/UiTheme.gd")
const GameData = preload("res://scripts/data/GameData.gd")

var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _sta_bar: ProgressBar
var _hp_lbl: Label
var _mp_lbl: Label
var _buff_lbl: Label
var _coin_lbl: Label
var _attr_lbl: Label
var _timer_lbl: Label
var _sc_title_lbl: Label
var _obj_lbl: Label
var _hazard_lbl: Label
var _hype_lbl: Label
var _sudden_lbl: Label
var _coop_lbl: Label
var _vol_lbl: Button
var _save_btn: Button
var _feed_box: VBoxContainer
var _skill_labels: Array[Label] = []
var _stigma_label: Label
var _item_labels: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.create_theme()

	# Top-left: Player Status & Coins
	var tl := PanelContainer.new()
	tl.position = Vector2(16, 14)
	tl.custom_minimum_size = Vector2(380, 152)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)

	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", 5)
	tl.add_child(tlv)

	var header_row := HBoxContainer.new()
	tlv.add_child(header_row)

	_attr_lbl = Label.new()
	_attr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attr_lbl.add_theme_font_override("font", UiTheme.load_font(true))
	_attr_lbl.add_theme_font_size_override("font_size", 15)
	header_row.add_child(_attr_lbl)

	_coin_lbl = Label.new()
	_coin_lbl.add_theme_font_override("font", UiTheme.load_font(true))
	_coin_lbl.add_theme_font_size_override("font_size", 17)
	_coin_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	header_row.add_child(_coin_lbl)

	_hp_bar = _make_bar(Color(0.88, 0.22, 0.28))
	tlv.add_child(_hp_bar)
	_hp_lbl = Label.new()
	_hp_lbl.add_theme_font_size_override("font_size", 13)
	tlv.add_child(_hp_lbl)

	_mp_bar = _make_bar(Color(0.18, 0.62, 0.96))
	tlv.add_child(_mp_bar)
	_mp_lbl = Label.new()
	_mp_lbl.add_theme_font_size_override("font_size", 13)
	tlv.add_child(_mp_lbl)

	_sta_bar = _make_bar(Color(0.95, 0.78, 0.20))
	_sta_bar.max_value = GameState.MAX_STAMINA
	_sta_bar.custom_minimum_size = Vector2(280, 7)
	tlv.add_child(_sta_bar)

	_buff_lbl = Label.new()
	_buff_lbl.add_theme_font_size_override("font_size", 12)
	_buff_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
	tlv.add_child(_buff_lbl)

	# Channel Hype Rank badge below top-left panel
	var hype_panel := PanelContainer.new()
	hype_panel.position = Vector2(16, 178)
	hype_panel.custom_minimum_size = Vector2(380, 40)
	hype_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hype_panel)
	_hype_lbl = Label.new()
	_hype_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	_hype_lbl.add_theme_font_size_override("font_size", 15)
	_hype_lbl.text = "แชนแนล RANK: D  |  COMBO x0"
	hype_panel.add_child(_hype_lbl)

	# Top-right: Active Scenario & Star Stream Feed (Pixel Font)
	var px_font := UiTheme.load_pixel_font()
	var tr := PanelContainer.new()
	tr.position = Vector2(856, 14)
	tr.custom_minimum_size = Vector2(408, 120)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var trv := VBoxContainer.new()
	trv.add_theme_constant_override("separation", 6)
	tr.add_child(trv)

	var sc_top := HBoxContainer.new()
	trv.add_child(sc_top)

	_sc_title_lbl = Label.new()
	_sc_title_lbl.text = "[ บทละครหลัก #1: พิสูจน์คุณค่า ]"
	_sc_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sc_title_lbl.add_theme_font_override("font", px_font)
	_sc_title_lbl.add_theme_font_size_override("font_size", 18)
	_sc_title_lbl.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	sc_top.add_child(_sc_title_lbl)

	_timer_lbl = Label.new()
	_timer_lbl.add_theme_font_override("font", px_font)
	_timer_lbl.add_theme_font_size_override("font_size", 20)
	_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	sc_top.add_child(_timer_lbl)

	_obj_lbl = Label.new()
	_obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_lbl.add_theme_font_override("font", px_font)
	_obj_lbl.add_theme_font_size_override("font_size", 16)
	trv.add_child(_obj_lbl)

	# Center-top hazard warning label (Toxic Fog / Darkness)
	_hazard_lbl = Label.new()
	_hazard_lbl.position = Vector2(360, 18)
	_hazard_lbl.custom_minimum_size = Vector2(480, 32)
	_hazard_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hazard_lbl.add_theme_font_override("font", px_font)
	_hazard_lbl.add_theme_font_size_override("font_size", 18)
	_hazard_lbl.add_theme_color_override("font_color", Color(1.0, 0.32, 0.32))
	_hazard_lbl.visible = false
	add_child(_hazard_lbl)

	# Sudden Dokkaebi Event Banner
	_sudden_lbl = Label.new()
	_sudden_lbl.position = Vector2(350, 52)
	_sudden_lbl.custom_minimum_size = Vector2(500, 32)

	# Top-center Utility Bar: Volume Controls (- / Mute / +) + Save Game button
	var util_row := HBoxContainer.new()
	util_row.position = Vector2(418, 12)
	util_row.add_theme_constant_override("separation", 6)
	util_row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(util_row)

	var btn_vdown := Button.new()
	btn_vdown.text = "🔉 -"
	btn_vdown.custom_minimum_size = Vector2(54, 30)
	btn_vdown.focus_mode = Control.FOCUS_NONE
	btn_vdown.pressed.connect(func(): SfxManager.change_volume(-0.15))
	util_row.add_child(btn_vdown)

	_vol_lbl = Button.new()
	_vol_lbl.text = "🔊 %d%%" % SfxManager.get_volume_percent()
	_vol_lbl.custom_minimum_size = Vector2(88, 30)
	_vol_lbl.focus_mode = Control.FOCUS_NONE
	_vol_lbl.pressed.connect(func(): SfxManager.toggle_master_mute())
	util_row.add_child(_vol_lbl)

	var btn_vup := Button.new()
	btn_vup.text = "🔊 +"
	btn_vup.custom_minimum_size = Vector2(54, 30)
	btn_vup.focus_mode = Control.FOCUS_NONE
	btn_vup.pressed.connect(func(): SfxManager.change_volume(0.15))
	util_row.add_child(btn_vup)

	_save_btn = Button.new()
	_save_btn.text = "💾 เซฟ"
	_save_btn.custom_minimum_size = Vector2(78, 30)
	_save_btn.focus_mode = Control.FOCUS_NONE
	_save_btn.pressed.connect(func():
		if GameState.save_game(ScenarioManager.current_stage):
			SfxManager.play("levelup")
			_save_btn.text = "✓ เซฟแล้ว"
			ScenarioManager.constellation_message.emit("[💾 บันทึกความคืบหน้าเกมสำเร็จ!]", 0)
			var tw := create_tween()
			tw.tween_interval(2.0)
			tw.tween_callback(func():
				if is_instance_valid(_save_btn):
					_save_btn.text = "💾 เซฟ"
			)
	)
	util_row.add_child(_save_btn)

	SfxManager.volume_changed.connect(func(pct: int, muted: bool):
		if is_instance_valid(_vol_lbl):
			_vol_lbl.text = "🔇 ปิด" if (muted or pct <= 0) else "🔊 %d%%" % pct
	)

	# Online Co-op Room Badge (top-center below utility bar)
	_coop_lbl = Label.new()
	_coop_lbl.position = Vector2(430, 84)
	_coop_lbl.custom_minimum_size = Vector2(420, 24)
	_coop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coop_lbl.add_theme_font_override("font", px_font)
	_coop_lbl.add_theme_font_size_override("font_size", 14)
	_coop_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.85))
	_coop_lbl.visible = false
	add_child(_coop_lbl)
	_sudden_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sudden_lbl.add_theme_font_override("font", px_font)
	_sudden_lbl.add_theme_font_size_override("font_size", 17)
	_sudden_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_sudden_lbl.visible = false
	add_child(_sudden_lbl)

	# Star Stream Constellation feed below scenario box
	_feed_box = VBoxContainer.new()
	_feed_box.position = Vector2(812, 142)
	_feed_box.custom_minimum_size = Vector2(452, 150)
	_feed_box.add_theme_constant_override("separation", 6)
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed_box)

	# Bottom-center: Skill bar + Quick items + Hotkeys (properly centered & never overflows 1280px!)
	var bot := PanelContainer.new()
	bot.position = Vector2(40, 624)
	bot.size = Vector2(1200, 82)
	bot.custom_minimum_size = Vector2(1200, 82)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bot.add_child(bv)

	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 14)
	bv.add_child(slots_row)

	for i in 3:
		var sl := Label.new()
		sl.add_theme_font_size_override("font_size", 14)
		slots_row.add_child(sl)
		_skill_labels.append(sl)

	_stigma_label = Label.new()
	_stigma_label.add_theme_font_size_override("font_size", 14)
	_stigma_label.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	slots_row.add_child(_stigma_label)

	var sep := Label.new()
	sep.text = " | "
	sep.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	slots_row.add_child(sep)

	for i in 2:
		var il := Label.new()
		il.add_theme_font_size_override("font_size", 14)
		il.add_theme_color_override("font_color", Color(0.7, 0.96, 0.78))
		slots_row.add_child(il)
		_item_labels.append(il)

	var hint := Label.new()
	hint.text = "[WASD] เดิน/กระโดด  •  [คลิกซ้าย/U] โจมตี  •  [J/K/L] สกิล  •  [N/M] แพรี่  •  [Q] ไอเทม  •  [E] แอนทริบิว  •  [Tab] สเตตัส/ซื้อของ  •  [F] โต้ตอบ"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	bv.add_child(hint)

	GameState.stats_changed.connect(refresh)
	GameState.coins_changed.connect(func(_n, _d): refresh())
	GameState.hp_mp_changed.connect(refresh)
	GameState.inventory_changed.connect(refresh)
	GameState.skills_changed.connect(refresh)
	GameState.hype_changed.connect(_on_hype_changed)
	ScenarioManager.scenario_updated.connect(refresh)
	ScenarioManager.constellation_message.connect(_push_feed)
	refresh()


func _make_bar(fill_col: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(280, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.20)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


func _process(_delta: float) -> void:
	if visible:
		_sta_bar.value = GameState.stamina
		var bparts: Array[String] = []
		if GameState.buff_atk_timer > 0.0: bparts.append("⚔ATK+(%.0fs)" % GameState.buff_atk_timer)
		if GameState.buff_haste_timer > 0.0: bparts.append("⚡HASTE(%.0fs)" % GameState.buff_haste_timer)
		if GameState.buff_iron_timer > 0.0: bparts.append("🛡IRON(%.0fs)" % GameState.buff_iron_timer)
		if GameState.buff_arcane_timer > 0.0: bparts.append("✦MAG+(%.0fs)" % GameState.buff_arcane_timer)
		_buff_lbl.text = "STA %d/%d  %s" % [int(GameState.stamina), int(GameState.MAX_STAMINA), " ".join(bparts)]
		_refresh_skill_cooldowns()


func _on_hype_changed(rank: String, combo: int, _val: float) -> void:
	var col := Color(0.75, 0.82, 0.90)
	if rank == "SSS":
		col = UiTheme.COL_GOLD
	elif rank == "S":
		col = UiTheme.COL_BORDER
	elif rank == "A":
		col = Color(0.35, 0.96, 0.58)
	_hype_lbl.text = "★ แชนแนล RANK: %s  |  COMBO x%d  |  เหรียญ x%.1f" % [rank, combo, GameState.get_hype_coin_mult()]
	_hype_lbl.add_theme_color_override("font_color", col)


func set_hazard_warning(text: String) -> void:
	_hazard_lbl.text = text
	_hazard_lbl.visible = text != ""


func refresh() -> void:
	var max_hp := GameState.get_max_hp()
	var max_mp := GameState.get_max_mp()
	_hp_bar.max_value = max_hp
	_hp_bar.value = GameState.hp
	var sh_str := " (+โล่ %d)" % GameState.shield_hp if GameState.shield_hp > 0 else ""
	_hp_lbl.text = "HP: %d / %d%s   |   อาวุธ: %s" % [GameState.hp, max_hp, sh_str, GameState.get_weapon_data()["name"]]

	_mp_bar.max_value = max_mp
	_mp_bar.value = GameState.mp
	_mp_lbl.text = "MP: %d / %d   |   STR %d  PHY %d  AGI %d  MAG %d" % [
		GameState.mp, max_mp, GameState.stats["str"], GameState.stats["phy"], GameState.stats["agi"], GameState.stats["mag"]
	]

	_coin_lbl.text = "%d เหรียญ" % GameState.coins
	_attr_lbl.text = GameState.current_attribute.get("name", "ผู้รอดชีวิต")

	_sc_title_lbl.text = ScenarioManager.get_stage_title()
	var mins := int(ScenarioManager.time_remaining) / 60
	var secs := int(ScenarioManager.time_remaining) % 60
	_timer_lbl.text = "%02d:%02d" % [mins, secs]

	if ScenarioManager.sudden_event_active:
		_sudden_lbl.text = "⚡ %s (%.0fs)" % [ScenarioManager.sudden_event_text, ScenarioManager.sudden_event_timer]
		_sudden_lbl.visible = true
	else:
		_sudden_lbl.visible = false

	match ScenarioManager.current_stage:
		1:
			var sub_txt := "✓ เควสรองตู้ 2 สำเร็จ" if ScenarioManager.sub_rescue_done else "• เควสรอง: ช่วยผู้โดยสารในตู้ 2"
			if ScenarioManager.condition_met:
				_obj_lbl.text = "✓ ผ่านเงื่อนไขบทละครแล้ว! อยู่ฟาร์มได้จนหมดเวลา หรือกด [G] ออกจากรถไฟ\n%s" % sub_txt
			else:
				_obj_lbl.text = "• โค่นศัตรู (%d/%d) หรือหากล่องแมลงตู้ 3 (จบไว ≥02:35 = อีเวนต์ลับ!)\n%s" % [ScenarioManager.stage1_kills, ScenarioManager.STAGE_1_KILLS_REQUIRED, sub_txt]
		2:
			var mask_txt := "✓ มีหน้ากากกันพิษแล้ว" if GameState.has_gas_mask else "• เควสรอง: หา/ซื้อหน้ากากกันหมอกพิษ"
			var boss_txt := "✓ โค่นอสูรสะพานแล้ว (%d/%d) — ไปกด [F] ที่ประตูสถานี!" % [ScenarioManager.stage2_kills, ScenarioManager.STAGE_2_KILLS_REQUIRED] if (ScenarioManager.stage2_boss_dead and ScenarioManager.stage2_kills >= ScenarioManager.STAGE_2_KILLS_REQUIRED) else "• กวาดล้างสะพาน (%d/%d) + โค่นอสูรสะพานตงโฮ" % [ScenarioManager.stage2_kills, ScenarioManager.STAGE_2_KILLS_REQUIRED]
			_obj_lbl.text = "%s\n%s" % [boss_txt, mask_txt]
		3:
			var w_txt := "กด [F] ที่เสา Green Zone กลางฉากเพื่อเริ่มป้องกัน 5 เวฟ" if not ScenarioManager.stage3_zone_claimed else "• ป้องกันเขต Green Zone: เวฟ %d / %d (อย่าออกนอกวง!)" % [ScenarioManager.stage3_wave, ScenarioManager.STAGE_3_TOTAL_WAVES]
			var r_txt := "✓ ช่วยผู้รอดชีวิตในความมืดแล้ว" if ScenarioManager.stage3_sub_rescue_done else "• เควสรอง: วิ่งฝ่าความมืดช่วยผู้รอดชีวิตด้านขวา"
			_obj_lbl.text = "%s\n%s" % [w_txt, r_txt]
		4:
			var f_txt := "• กำจัดผู้เฝ้าธงแล้วยึดธง (%d / 2)" % ScenarioManager.stage4_flags_captured
			var k_txt := "✓ โค่นทรราชผู้ชิงบัลลังก์ (3 เฟส) แล้ว!" if ScenarioManager.stage4_boss_dead else "• โค่นบอสใหญ่ 3 เฟส: ทรราชผู้ชิงบัลลังก์"
			_obj_lbl.text = "%s\n%s" % [f_txt, k_txt]

	var keys := ["Q", "V"]
	if _coop_lbl != null:
		if NetworkManager.is_online:
			var role_tag := " ★หัวหน้าห้อง" if NetworkManager.is_host else ""
			_coop_lbl.text = "🌐 Co-op ห้อง: %s  |  ผู้เล่น %d/4%s" % [NetworkManager.room_code, NetworkManager.room_players.size(), role_tag]
			_coop_lbl.visible = true
		else:
			_coop_lbl.visible = false
	for i in 2:
		var iid := GameState.quick_slots[i] if i < GameState.quick_slots.size() else ""
		var cnt := int(GameState.consumables.get(iid, 0))
		if iid != "" and cnt > 0:
			_item_labels[i].text = "[%s] %s (%d)" % [keys[i], GameData.CONSUMABLES[iid]["name"], cnt]
		else:
			_item_labels[i].text = "[%s] ว่าง" % keys[i]
	_refresh_skill_cooldowns()


func _refresh_skill_cooldowns() -> void:
	var skeys := ["J", "K", "L"]
	for i in 3:
		var sid := GameState.equipped_skills[i]
		if sid == "":
			_skill_labels[i].text = "[%s] (ซื้อเพิ่มใน Tab)" % skeys[i]
			_skill_labels[i].add_theme_color_override("font_color", Color(0.45, 0.52, 0.62))
		else:
			var sdata: Dictionary = GameData.SKILLS[sid]
			var cd := float(GameState.skill_cooldowns.get(sid, 0.0))
			if cd > 0.05:
				_skill_labels[i].text = "[%s] %s (%.1fs)" % [skeys[i], sdata["name"], cd]
				_skill_labels[i].add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
			else:
				_skill_labels[i].text = "[%s] %s (%dMP)" % [skeys[i], sdata["name"], int(sdata["mp_cost"])]
				_skill_labels[i].add_theme_color_override("font_color", UiTheme.COL_BORDER)

	if GameState.stigma_skill_id == "":
		_stigma_label.text = "[E] แอนทริบิว (ล็อก)"
		_stigma_label.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
	else:
		var st: Dictionary = GameData.STIGMA_SKILLS[GameState.stigma_skill_id]
		if GameState.stigma_cooldown > 0.05:
			_stigma_label.text = "[E] %s (%.1fs)" % [st["name"].replace("สติกมา: ", "").replace("ทักษะเฉพาะ: ", ""), GameState.stigma_cooldown]
			_stigma_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
		else:
			_stigma_label.text = "[E] ★%s (%dMP)" % [st["name"].replace("สติกมา: ", "").replace("ทักษะเฉพาะ: ", ""), int(st["mp_cost"])]
			_stigma_label.add_theme_color_override("font_color", UiTheme.COL_GOLD)


func _push_feed(text: String, coin_bonus: int) -> void:
	var p := PanelContainer.new()
	var bcol := UiTheme.COL_GOLD if coin_bonus > 0 else UiTheme.COL_BORDER
	p.add_theme_stylebox_override("panel", UiTheme.make_panel_style(bcol, Color(0.03, 0.08, 0.16, 0.85), 1))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD if coin_bonus > 0 else UiTheme.COL_TEXT)
	p.add_child(lbl)
	_feed_box.add_child(p)
	if _feed_box.get_child_count() > 3:
		_feed_box.get_child(0).queue_free()

	var tw := create_tween()
	tw.tween_interval(4.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)
