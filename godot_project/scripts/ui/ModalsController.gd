extends Control

const UiTheme = preload("res://scripts/ui/UiTheme.gd")
const GameData = preload("res://scripts/data/GameData.gd")

signal stat_upgraded
signal next_stage_requested
signal boon_picked_continue
signal restart_stage_requested
signal reroll_new_game_requested
signal modal_state_changed(is_open: bool)

var _overlay: ColorRect
var _center: CenterContainer
var _active_panel: Control = null
var _active_kind: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.create_theme()
	visible = false

	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.01, 0.03, 0.07, 0.72)
	add_child(_overlay)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)


func is_modal_open() -> bool:
	return visible


func close_modal() -> void:
	if _active_panel != null:
		_active_panel.queue_free()
		_active_panel = null
	_active_kind = ""
	visible = false
	get_tree().paused = false
	modal_state_changed.emit(false)


func _open_panel(kind: String, panel: Control) -> void:
	if _active_panel != null:
		_active_panel.queue_free()
	_active_panel = panel
	_active_kind = kind
	_center.add_child(panel)
	visible = true
	if not NetworkManager.is_online:
		get_tree().paused = true
	modal_state_changed.emit(true)
	SfxManager.play("system")


func toggle_attribute_window() -> void:
	if visible and _active_kind in ["status", "shop"]:
		close_modal()
		return
	if visible and _active_kind in ["sponsor", "result", "intro", "bug_box"]:
		return
	_show_attribute_window()


func _make_tab_switcher(active_tab: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)

	var btn_stat := Button.new()
	btn_stat.text = "⚔ อัปสเตตัส & อาวุธ"
	btn_stat.custom_minimum_size = Vector2(200, 36)
	btn_stat.disabled = active_tab == "status"
	btn_stat.pressed.connect(func(): _show_attribute_window())
	bar.add_child(btn_stat)

	var btn_shop := Button.new()
	btn_shop.text = "🛒 ถุงโดแกบี (ซื้อของ/สกิล)"
	btn_shop.custom_minimum_size = Vector2(220, 36)
	btn_shop.disabled = active_tab == "shop"
	btn_shop.pressed.connect(func(): _show_shop_window())
	bar.add_child(btn_shop)

	var btn_save := Button.new()
	btn_save.text = "💾 เซฟเกม"
	btn_save.custom_minimum_size = Vector2(130, 36)
	btn_save.pressed.connect(func():
		if GameState.save_game(ScenarioManager.current_stage):
			SfxManager.play("levelup")
			btn_save.text = "✓ เซฟแล้ว!"
			ScenarioManager.constellation_message.emit("[💾 บันทึกเกมสำเร็จ — บทละครที่ %d]" % ScenarioManager.current_stage, 0)
	)
	bar.add_child(btn_save)
	return bar


func toggle_shop_window() -> void:
	if visible and _active_kind == "shop":
		close_modal()
		return
	if visible and _active_kind in ["sponsor", "result", "intro", "bug_box"]:
		return
	_show_shop_window()


func show_scenario_intro(stage_num: int = 1) -> void:
	var px_font := UiTheme.load_pixel_font()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 370)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BORDER, UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var h := Label.new()
	h.text = ScenarioManager.get_stage_title()
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", px_font)
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	v.add_child(h)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", px_font)
	body.add_theme_font_size_override("font_size", 18)
	match stage_num:
		1:
			body.text = (
				"โดแกบี: \"บริการฟรีของระบบดาวเคราะห์ 8612 สิ้นสุดลงแล้ว! ยินดีต้อนรับสู่บทละครแรก!\"\n\n"
				+ "• เงื่อนไขเคลียร์: กำจัดสิ่งมีชีวิตอย่างน้อย 1 ตัว\n"
				+ "• เวลาจำกัด: 3 นาที (180 วิ)   |   รางวัล: 300 เหรียญ\n\n"
				+ "เคล็ดลับ: จบไวให้เวลายังเหลือ ≥ 02:50 แล้วกดออกทันทีเพื่อพบกลุ่มตัวเอก หรือสำรวจตู้ 3 หากล่องแมลง!"
			)
		2:
			body.text = (
				"คุณก้าวออกจากขบวนรถไฟสู่ 'สะพานตงโฮ' ใต้ท้องฟ้าสีเลือด...\n\n"
				+ "• เงื่อนไขเคลียร์: ฝ่าเขตหมอกพิษ โค่น 'อสูรสะพานตงโฮ' และกด [F] เข้าประตูสถานีโอกซู\n"
				+ "• เควสรอง: เก็บ 'หน้ากากกันหมอกพิษ' จากลังบนสะพาน หรือซื้อจากถุงโดแกบี [B]\n"
				+ "• เวลาจำกัด: 3 นาที 30 วิ   |   รางวัล: 500 เหรียญ"
			)
		3:
			body.text = (
				"สถานีโอกซูถูกปกคลุมด้วยความมืดมิด มีเพียงวงแสงสีเขียว 'Green Zone' อยู่กลางชานชาลา!\n\n"
				+ "• เงื่อนไขเคลียร์: กด [F] ที่เสา Green Zone และเอาชีวิตรอดต้านอสูร 3 เวฟ + บอสประจำสถานี\n"
				+ "• คำเตือน: หากออกนอกวง Green Zone ระหว่างเวฟ ความมืดจะกัดกิน HP ต่อเนื่อง!\n"
				+ "• เควสรอง: วิ่งฝ่าความมืดออกไปด้านขวาเพื่อช่วยผู้รอดชีวิต (+200 เหรียญ)   |   รางวัล: 700 เหรียญ"
			)
		_:
			body.text = (
				"บทละครใหญ่เปิดฉาก! เหล่าผู้ท้าชิงต่างมารวมตัวกันที่โถงสถานีเพื่อชิงตำแหน่ง 'ราชา'!\n\n"
				+ "• เงื่อนไขเคลียร์: ยึดธงสถานีทั้ง 2 จุด (กด [F]) และโค่นบอสใหญ่ 'ทรราชผู้ชิงบัลลังก์'\n"
				+ "• โบนัสธง: ทุกธงที่ยึดได้จะเพิ่มพลังโจมตี +6 และมอบ 200 เหรียญทันที\n"
				+ "• เวลาจำกัด: 4 นาที   |   รางวัล: 1,200 เหรียญ + ฉายาราชาแห่งตู้ 3707!"
			)
	v.add_child(body)

	var btn := Button.new()
	btn.text = "รับทราบ — เริ่มบทละคร!"
	btn.add_theme_font_override("font", px_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(280, 46)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(close_modal)
	v.add_child(btn)
	_open_panel("intro", panel)


func _show_attribute_window() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 480)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_make_tab_switcher("status"))

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "[ หน้าต่างข้อมูลตัวละคร — อัปสเตตัสด้วยเหรียญ ]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UiTheme.load_font(true))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	top.add_child(title)

	var coins := Label.new()
	coins.text = "เหรียญคงเหลือ: %d" % GameState.coins
	coins.add_theme_font_override("font", UiTheme.load_font(true))
	coins.add_theme_font_size_override("font_size", 18)
	coins.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	top.add_child(coins)

	var attr_info := Label.new()
	var comp_names: Array[String] = []
	for cid in GameState.companions:
		comp_names.append("ซอ ยูนา" if cid == "yuna" else "พัค แจฮุน")
	var comp_str := ", ".join(comp_names) if comp_names.size() > 0 else "ยังไม่มี"
	var fable_names: Array[String] = []
	for fid in GameState.owned_fables:
		if GameData.FABLES.has(fid):
			fable_names.append(GameData.FABLES[fid]["name"].replace("เรื่องเล่า: ", ""))
	var fable_str := ", ".join(fable_names) if fable_names.size() > 0 else "ยังไม่มี"
	attr_info.text = "อาชีพ: %s [%s] — %s\nคู่หูร่วมทีม: %s   |   เรื่องเล่า (Fables): %s" % [
		GameState.current_attribute.get("name", ""),
		GameState.current_attribute.get("rarity", ""),
		GameState.current_attribute.get("passive_desc", ""),
		comp_str,
		fable_str,
	]
	attr_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attr_info.add_theme_color_override("font_color", Color(0.7, 0.94, 0.84))
	v.add_child(attr_info)

	var lv_now := GameState.get_total_level()
	var lv_cap := GameState.get_stage_level_cap(ScenarioManager.current_stage)
	var lv_over := GameState.get_probability_overflow(ScenarioManager.current_stage)
	var prob_lbl := Label.new()
	if lv_over > 0:
		prob_lbl.text = "⚡ ระดับพลังรวม: Lv.%d / เพดานบทละครที่ %d: Lv.%d  —  เกินเพดาน (+%d)! พายุความเป็นไปได้กำลังลงโทษ (ขยับไม่ได้ + เลือดลดต่อเนื่อง)!" % [lv_now, ScenarioManager.current_stage, lv_cap, lv_over]
		prob_lbl.add_theme_color_override("font_color", Color(1.0, 0.32, 0.65))
	elif lv_now == lv_cap:
		prob_lbl.text = "⚠ ระดับพลังรวม: Lv.%d / เพดานบทละครที่ %d: Lv.%d  —  ถึงเพดานแล้ว! อัปเกินจะโดนบทลงโทษแห่งความเป็นไปได้" % [lv_now, ScenarioManager.current_stage, lv_cap]
		prob_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.25))
	else:
		prob_lbl.text = "ระดับพลังรวม: Lv.%d / เพดานความเป็นไปได้บทละครที่ %d: Lv.%d (อัปเพิ่มได้อีก %d Lv อย่างปลอดภัย)" % [lv_now, ScenarioManager.current_stage, lv_cap, lv_cap - lv_now]
		prob_lbl.add_theme_color_override("font_color", Color(0.58, 0.92, 1.0))
	prob_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prob_lbl.add_theme_font_size_override("font_size", 14)
	v.add_child(prob_lbl)

	v.add_child(HSeparator.new())

	var stat_meta := [
		["str", "พละกำลัง (STR)", "เพิ่มพลังโจมตี (+3 ATK / Lv)"],
		["phy", "ความทนทาน (PHY)", "เพิ่ม HP สูงสุด (+20 HP / Lv) & ลดดาเมจ"],
		["agi", "ความว่องไว (AGI)", "เพิ่มความเร็วเดิน & ลดคูลดาวน์ Dash"],
		["mag", "พลังเวท (MAG)", "เพิ่ม MP สูงสุด (+15 MP / Lv) & แรงสกิล"],
	]
	for sm in stat_meta:
		var key: String = sm[0]
		var lv: int = int(GameState.stats[key])
		var cost: int = GameState.get_upgrade_cost(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s  Lv.%d  —  %s" % [sm[1], lv, sm[2]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "+ อัป (%d เหรียญ)" % cost
		btn.disabled = GameState.coins < cost
		btn.pressed.connect(func():
			if GameState.upgrade_stat(key):
				stat_upgraded.emit()
				_show_attribute_window()
		)
		row.add_child(btn)

	v.add_child(HSeparator.new())

	var w_lbl := Label.new()
	w_lbl.text = "อาวุธที่ครอบครอง (คลิกเพื่อสวมใส่):"
	w_lbl.add_theme_font_override("font", UiTheme.load_font(true))
	v.add_child(w_lbl)

	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 8)
	v.add_child(w_row)
	for wid in GameState.owned_weapons:
		var wd: Dictionary = GameData.WEAPONS[wid]
		var wb := Button.new()
		var eq := " [ใส่อยู่]" if wid == GameState.equipped_weapon else ""
		wb.text = "%s (ATK %d)%s" % [wd["name"], int(wd["atk"]), eq]
		wb.disabled = wid == GameState.equipped_weapon
		wb.pressed.connect(func():
			GameState.equip_weapon(wid)
			SfxManager.play("coin")
			_show_attribute_window()
		)
		w_row.add_child(wb)

	var close_btn := Button.new()
	close_btn.text = "ปิดหน้าต่าง (Tab)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close_modal)
	v.add_child(close_btn)

	_open_panel("status", panel)


func _show_shop_window() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 520)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_make_tab_switcher("shop"))

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "[ ถุงโดแกบี — ร้านค้า Star Stream ]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UiTheme.load_font(true))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	top.add_child(title)

	var coins := Label.new()
	coins.text = "เหรียญของคุณ: %d" % GameState.coins
	coins.add_theme_font_override("font", UiTheme.load_font(true))
	coins.add_theme_font_size_override("font_size", 18)
	coins.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	top.add_child(coins)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 390)
	v.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Skills section (all 26 purchasable skills across Damage, Control, Buff, Debuff)
	_add_shop_header(list, "สกิลโจมตี & เวทมนตร์ (Damage Skills)")
	for sid in ["wind_slash", "fireball", "lightning_bolt", "frost_nova", "mana_burst", "meteor_drop", "void_lance", "blade_storm", "shadow_reap", "sonic_pierce", "chain_zap"]:
		_add_skill_shop_row(list, sid)

	_add_shop_header(list, "สกิลควบคุมศัตรู (Control / CC Skills)")
	for sid in ["gravity_well", "flash_bang", "ice_prison", "shockwave_push", "earth_bind"]:
		_add_skill_shop_row(list, sid)

	_add_shop_header(list, "สกิลบัพเสริมพลัง (Buff Skills)")
	for sid in ["magic_barrier", "battle_cry", "haste_aura", "iron_skin", "arcane_surge", "second_wind"]:
		_add_skill_shop_row(list, sid)

	_add_shop_header(list, "สกิลดีบัพศัตรู (Debuff Skills)")
	for sid in ["armor_break", "curse_weaken", "venom_cloud", "mark_of_death"]:
		_add_skill_shop_row(list, sid)

	# Weapons section
	_add_shop_header(list, "อาวุธ & คทาเวท (Weapons & Staves)")
	for wid in ["steel_dagger", "steel_spear", "twin_daggers", "heavy_axe", "recurve_bow", "tactical_pistol", "shadow_scythe", "apprentice_wand", "volt_staff", "frost_staff", "inferno_staff", "necro_staff", "crystal_blade", "obsidian_katana", "starlight_staff"]:
		var wd: Dictionary = GameData.WEAPONS[wid]
		var owned: bool = wid in GameState.owned_weapons
		_add_shop_row(
			list,
			"%s (ATK %d) — %s" % [wd["name"], int(wd["atk"]), wd["desc"]],
			"มีแล้ว" if owned else "ซื้อ (%d เหรียญ)" % int(wd["price"]),
			owned or GameState.coins < int(wd["price"]),
			func():
				if GameState.buy_item(wid):
					SfxManager.play("coin")
					_show_shop_window()
		)

	# Scenario gear
	_add_shop_header(list, "อุปกรณ์เฉพาะบทละคร (Scenario Gear)")
	_add_shop_row(
		list,
		"หน้ากากกันหมอกพิษ — ป้องกันดาเมจหมอกพิษในบทที่ 2 (สะพานตงโฮ) 100%",
		"มีแล้ว" if GameState.has_gas_mask else "ซื้อ (120 เหรียญ)",
		GameState.has_gas_mask or GameState.coins < 120,
		func():
			if GameState.buy_item("gas_mask"):
				SfxManager.play("levelup")
				_show_shop_window()
	)

	# Consumables section (Hardcore limit: 3 heal purchases per stage!)
	var heals_left := maxi(0, GameState.MAX_HEALS_PER_STAGE - GameState.stage_heals_bought)
	_add_shop_header(list, "ไอเทมกดใช้ (Consumables — ซื้อยาฟื้น HP ได้อีก %d/%d ชิ้นในบทนี้)" % [heals_left, GameState.MAX_HEALS_PER_STAGE])
	for cid in ["potion_small", "medkit", "mana_stone", "fire_bomb"]:
		var cd: Dictionary = GameData.CONSUMABLES[cid]
		var have := int(GameState.consumables.get(cid, 0))
		var capped: bool = String(cd["kind"]) == "heal_hp" and heals_left <= 0
		_add_shop_row(
			list,
			"%s (มี %d) — %s" % [cd["name"], have, cd["desc"]],
			"ครบโควต้าบทนี้" if capped else "ซื้อ (%d เหรียญ)" % int(cd["price"]),
			capped or GameState.coins < int(cd["price"]),
			func():
				if GameState.buy_item(cid):
					SfxManager.play("coin")
					_show_shop_window()
		)

	var close_btn := Button.new()
	close_btn.text = "ปิดถุงโดแกบี (B)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close_modal)
	v.add_child(close_btn)

	_open_panel("shop", panel)


func _add_skill_shop_row(parent: VBoxContainer, sid: String) -> void:
	var sd: Dictionary = GameData.SKILLS[sid]
	var owned: bool = sid in GameState.owned_skills
	_add_shop_row(
		parent,
		"%s (%dMP) — %s" % [sd["name"], int(sd["mp_cost"]), sd["desc"]],
		"ซื้อแล้ว" if owned else "ซื้อ (%d เหรียญ)" % int(sd["price"]),
		owned or GameState.coins < int(sd["price"]),
		func():
			if GameState.buy_skill(sid):
				SfxManager.play("levelup")
				_show_shop_window()
	)


func _add_shop_header(parent: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.load_font(true))
	l.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	parent.add_child(l)


func _add_shop_row(parent: VBoxContainer, label_txt: String, btn_txt: String, disabled: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := Label.new()
	l.text = label_txt
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	row.add_child(l)
	var b := Button.new()
	b.text = btn_txt
	b.disabled = disabled
	b.custom_minimum_size = Vector2(165, 36)
	b.pressed.connect(cb)
	row.add_child(b)


func show_bug_box_choice() -> void:
	var px_font := UiTheme.load_pixel_font()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 300)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.2, 0.9, 0.5), UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var h := Label.new()
	h.text = "[ ค้นพบสิ่งมีชีวิตขนาดเล็ก: กล่องแมลงของเด็กน้อย ]"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", px_font)
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", Color(0.35, 0.96, 0.58))
	v.add_child(h)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", px_font)
	body.add_theme_font_size_override("font_size", 18)
	body.text = "ข้างในกระเป๋าเป้มีกล่องพลาสติกใสที่ขังตั๊กแตนไว้ 1 ตัว... เงื่อนไขของบทละครหลักคือ 'กำจัดสิ่งมีชีวิตอย่างน้อย 1 ตัว' ไม่ได้บังคับว่าต้องเป็นมนุษย์!"
	v.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)

	var b_yes := Button.new()
	b_yes.text = "กำจัดแมลงในกล่อง (เคลียร์บทละคร + บทละครลับ!)"
	b_yes.pressed.connect(func():
		close_modal()
		ScenarioManager.complete_hidden_bug_box()
	)
	row.add_child(b_yes)

	var b_no := Button.new()
	b_no.text = "เก็บไว้ก่อน"
	b_no.pressed.connect(close_modal)
	row.add_child(b_no)

	_open_panel("bug_box", panel)


func show_sponsor_selection() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 480)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_GOLD, UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var h := Label.new()
	h.text = "[ การเลือกผู้สนับสนุน (Sponsor Selection) ]"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", UiTheme.load_pixel_font())
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	v.add_child(h)

	var sub := Label.new()
	sub.text = "คุณผ่านบทละครหลักที่ 1 แล้ว! กลุ่มดาวต่อไปนี้กำลังยื่นข้อเสนอเป็นผู้สนับสนุนของคุณ:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UiTheme.load_pixel_font())
	sub.add_theme_font_size_override("font_size", 18)
	v.add_child(sub)

	for sp_id in ["moonlight", "moonless_shadow", "eternal_flame", "none"]:
		var sp: Dictionary = GameData.SPONSORS[sp_id]
		var btn := Button.new()
		btn.text = "%s  —  %s" % [sp["name"], sp["bonus_desc"]]
		btn.custom_minimum_size = Vector2(680, 56)
		btn.pressed.connect(func():
			ScenarioManager.select_sponsor(sp_id)
			show_post_clear_choice()
		)
		v.add_child(btn)

	_open_panel("sponsor", panel)


func show_boon_selection() -> void:
	var px_font := UiTheme.load_pixel_font()
	var choices := GameState.roll_boon_choices(3)
	if choices.is_empty():
		boon_picked_continue.emit()
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 440)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_GOLD, UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var h := Label.new()
	h.text = "[ ★ พรแห่ง Star Stream — เลือกการ์ดบัฟถาวร 1 จาก 3 ★ ]"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", px_font)
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	v.add_child(h)

	var sub := Label.new()
	sub.text = "กลุ่มดาวประทับใจผลงานของคุณ! เลือกความสามารถพิเศษติดตัว 1 อย่างก่อนเข้าสู่บทละครถัดไป:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	for boon in choices:
		var bid: String = boon["id"]
		var btn := Button.new()
		btn.text = "★ %s\n%s" % [boon["name"], boon["desc"]]
		btn.custom_minimum_size = Vector2(700, 74)
		btn.pressed.connect(func():
			GameState.add_boon(bid)
			SfxManager.play("levelup")
			close_modal()
			boon_picked_continue.emit()
		)
		v.add_child(btn)

	_open_panel("boon", panel)


func show_post_clear_choice() -> void:
	var px_font := UiTheme.load_pixel_font()
	var can_secret := ScenarioManager.can_trigger_main_cast_secret()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 360)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_GOLD if can_secret else UiTheme.COL_BORDER, UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var mins := int(ScenarioManager.time_remaining) / 60
	var secs := int(ScenarioManager.time_remaining) % 60
	var h := Label.new()
	h.text = "[ ผ่านเงื่อนไขบทละครที่ 1 แล้ว! — เวลาคงเหลือ %02d:%02d ]" % [mins, secs]
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", px_font)
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", UiTheme.COL_GOLD if can_secret else UiTheme.COL_BORDER)
	v.add_child(h)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", px_font)
	body.add_theme_font_size_override("font_size", 17)
	var secret_hint := ""
	if can_secret:
		secret_hint = "\n★ [เงื่อนไขพิเศษทำงาน!] คุณจบไวมาก (เวลาเหลือ ≥ 02:50)! หาก 'ออกไปนอกรถไฟเลย' ตอนนี้ คุณจะตามทันและได้พบกับกลุ่มตัวเอกที่ตู้ 3807! (+500 เหรียญ)"
	else:
		secret_hint = "\n(เคล็ดลับลับ: หากจบเงื่อนไขตอนเวลายังเหลือ ≥ 02:50 แล้วกดออกทันที จะได้พบกับกลุ่มตัวเอก!)"
	body.text = (
		"คุณได้รับสกิลพิเศษจากผู้สนับสนุนแล้ว (กดปุ่ม [R] เพื่อใช้งาน!)\n"
		+ "คุณต้องการ 'ออกไปนอกรถไฟทันที' หรือ 'อยู่รอ/ฟาร์มเหรียญในขบวนต่อจนกว่าจะหมดเวลา'?"
		+ secret_hint
	)
	v.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)

	var b_exit := Button.new()
	b_exit.text = "★ ออกไปนอกรถไฟเลย (เจอกลุ่มตัวเอก!)" if can_secret else "ออกไปนอกรถไฟเลย"
	b_exit.custom_minimum_size = Vector2(300, 48)
	if can_secret:
		b_exit.add_theme_stylebox_override("normal", UiTheme.make_button_style(Color(0.28, 0.20, 0.04, 0.98), UiTheme.COL_GOLD))
	b_exit.pressed.connect(func():
		close_modal()
		ScenarioManager.exit_train_now()
	)
	row.add_child(b_exit)

	var b_farm := Button.new()
	b_farm.text = "อยู่รอ / ฟาร์มต่อจนหมดเวลา"
	b_farm.custom_minimum_size = Vector2(260, 48)
	b_farm.pressed.connect(func():
		close_modal()
		ScenarioManager.choose_stay_and_farm()
	)
	row.add_child(b_farm)

	_open_panel("post_choice", panel)


func show_result_modal(victory: bool, fail_reason: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 400)
	var bcol := UiTheme.COL_GOLD if victory else Color(0.95, 0.25, 0.3)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(bcol, UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var is_secret_cast := victory and ScenarioManager.ending_type == "secret_main_cast"
	var is_campaign_win := victory and ScenarioManager.ending_type == "campaign_victory"
	var h := Label.new()
	if is_campaign_win:
		h.text = "[ ★ พิชิตครบ 4 บทละคร: ราชาแห่งตู้ 3707! ★ ]"
	elif is_secret_cast:
		h.text = "[ ★ อีเวนต์พิเศษ: พบเจอกลุ่มตัวเอกที่ตู้ 3807! ★ ]"
	elif victory:
		h.text = "[ บทละครหลัก #%d เสร็จสมบูรณ์! ]" % ScenarioManager.current_stage
	else:
		h.text = "[ บทละครหลัก #%d ล้มเหลว ]" % ScenarioManager.current_stage
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", UiTheme.load_pixel_font())
	h.add_theme_font_size_override("font_size", 24 if (is_secret_cast or is_campaign_win) else 26)
	h.add_theme_color_override("font_color", bcol)
	v.add_child(h)

	var path_name := "บทละครลับ (ไม่ฆ่าคน — กล่องแมลง)" if ScenarioManager.clear_path == "hidden_pacifist" else "เส้นทางต่อสู้"
	var sp_name: String = GameData.SPONSORS.get(GameState.selected_sponsor_id, {}).get("name", "-")
	var end_desc := ""
	if ScenarioManager.ending_type == "campaign_victory":
		end_desc = "คุณยึดธงสถานีครบทั้ง 2 จุดและโค่น 'ทรราชผู้ชิงบัลลังก์' ลงได้สำเร็จ! เหล่ากลุ่มดาวทั่วห้วงดาราต่างจับจ้องมาที่คุณในฐานะ 'ราชาแห่งตู้ 3707'!\n\n"
	elif ScenarioManager.ending_type == "stage2_clear":
		end_desc = "คุณฝ่าหมอกพิษและโค่นอสูรบนสะพานตงโฮมาถึงสถานีโอกซูได้สำเร็จ! (+500 เหรียญ)\n\n"
	elif ScenarioManager.ending_type == "stage3_clear":
		end_desc = "คุณปกป้องเขต Green Zone ฝ่าอสูรทั้ง 3 เวฟและโค่นผู้พิทักษ์รัตติกาลได้สำเร็จ! (+700 เหรียญ)\n\n"
	elif ScenarioManager.ending_type == "secret_main_cast":
		end_desc = "คุณพุ่งออกจากตู้ 3707 ทันเวลาที่เหลือมากกว่า 02:50 และได้พบกับชายหนุ่มถือสมาร์ทโฟนและกลุ่มผู้รอดชีวิตจากตู้ 3807! (+500 เหรียญ + โบนัสในบทที่ 2)\n\n"
	elif ScenarioManager.ending_type == "waited_timeout":
		end_desc = "คุณอยู่ฟาร์มเหรียญและฝึกสติกมาจนหมดเวลา 00:00 ก่อนก้าวออกจากขบวนรถไฟอย่างแข็งแกร่ง\n\n"
	elif ScenarioManager.ending_type == "early_exit":
		end_desc = "คุณตัดสินใจก้าวออกจากขบวนรถไฟใต้ดินทันทีเพื่อมุ่งหน้าสู่บทละครถัดไป\n\n"

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	if victory:
		body.text = (
			end_desc
			+ "คุณลักษณะเฉพาะ: %s [%s]   |   กลุ่มดาว: %s\n"
			+ "เหรียญสะสมรวม: %d เหรียญ (คงเหลือ %d)\n"
			+ "ศัตรูที่กำจัด: %d ตัว   |   Perfect Dodge: %d ครั้ง   |   เวลาบทนี้: %.1f วินาที"
		) % [
			GameState.current_attribute.get("name", ""),
			GameState.current_attribute.get("rarity", ""),
			sp_name,
			GameState.total_coins_earned,
			GameState.coins,
			GameState.enemies_defeated,
			GameState.perfect_dodges,
			ScenarioManager.elapsed_time,
		]
	else:
		body.text = "สาเหตุ: %s\n\nลองใช้วิธีพุ่งหลบ (Shift) เพื่อรับเหรียญสปอนเซอร์จากกลุ่มดาว และอัปสเตตัส (Tab) หรือซื้อของในถุงโดแกบี (B) ดูนะครับ!" % fail_reason
	v.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)

	if victory and ScenarioManager.current_stage < 4:
		var b_next := Button.new()
		b_next.text = "★ เข้าสู่บทละครที่ %d →" % (ScenarioManager.current_stage + 1)
		b_next.custom_minimum_size = Vector2(240, 48)
		b_next.add_theme_stylebox_override("normal", UiTheme.make_button_style(Color(0.28, 0.20, 0.04, 0.98), UiTheme.COL_GOLD))
		b_next.pressed.connect(func():
			close_modal()
			next_stage_requested.emit()
		)
		row.add_child(b_next)

	var b_retry := Button.new()
	b_retry.text = "เล่นบทที่ %d ซ้ำ" % ScenarioManager.current_stage
	b_retry.custom_minimum_size = Vector2(180, 44)
	b_retry.pressed.connect(func():
		close_modal()
		restart_stage_requested.emit()
	)
	row.add_child(b_retry)

	var b_new := Button.new()
	b_new.text = "เริ่มใหม่ / สุ่มอาชีพ"
	b_new.custom_minimum_size = Vector2(200, 44)
	b_new.pressed.connect(func():
		close_modal()
		reroll_new_game_requested.emit()
	)
	row.add_child(b_new)

	_open_panel("result", panel)
