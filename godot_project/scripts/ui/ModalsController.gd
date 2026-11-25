extends Control

const UiTheme = preload("res://scripts/ui/UiTheme.gd")
const GameData = preload("res://scripts/data/GameData.gd")

signal stat_upgraded
signal next_stage_requested
signal boon_picked_continue
signal route_choice_selected(target_stage: int, choice_id: String)
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
	if visible and _active_kind in ["status", "shop", "bag"]:
		close_modal()
		return
	if visible and _active_kind in ["sponsor", "result", "intro", "bug_box"]:
		return
	_show_attribute_window()


func toggle_bag_window() -> void:
	if visible and _active_kind == "bag":
		close_modal()
		return
	if visible and _active_kind in ["sponsor", "result", "intro", "bug_box"]:
		return
	_show_bag_window()


func toggle_bihyung_story() -> void:
	if visible and _active_kind == "bihyung_recap":
		close_modal()
		return
	if visible and _active_kind in ["sponsor", "result", "intro", "bug_box", "boon", "route_choice"]:
		return
	show_scenario_intro(ScenarioManager.current_stage, true)


func _make_tab_switcher(active_tab: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)

	var btn_stat := Button.new()
	btn_stat.text = "⚔ อัปสเตตัส"
	btn_stat.custom_minimum_size = Vector2(145, 36)
	btn_stat.disabled = active_tab == "status"
	btn_stat.pressed.connect(func(): _show_attribute_window())
	bar.add_child(btn_stat)

	var btn_bag := Button.new()
	btn_bag.text = "🎒 กระเป๋าเก็บของ"
	btn_bag.custom_minimum_size = Vector2(165, 36)
	btn_bag.disabled = active_tab == "bag"
	btn_bag.pressed.connect(func(): _show_bag_window())
	bar.add_child(btn_bag)

	var btn_shop := Button.new()
	btn_shop.text = "🛒 ถุงโดแกบี"
	btn_shop.custom_minimum_size = Vector2(145, 36)
	btn_shop.disabled = active_tab == "shop"
	btn_shop.pressed.connect(func(): _show_shop_window())
	bar.add_child(btn_shop)

	var btn_save := Button.new()
	btn_save.text = "💾 เซฟเกม"
	btn_save.custom_minimum_size = Vector2(115, 36)
	btn_save.pressed.connect(func():
		if GameState.save_game(ScenarioManager.current_stage):
			SfxManager.play("levelup")
			btn_save.text = "✓ เซฟแล้ว!"
			ScenarioManager.constellation_message.emit("[💾 บันทึกเกมสำเร็จ — บทละครที่ %d]" % ScenarioManager.current_stage, 0)
	)
	bar.add_child(btn_save)
	return bar


func _show_bag_window() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 540)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_make_tab_switcher("bag"))

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "[ 🎒 กระเป๋าเก็บของ — สลับอาวุธ / ไอเทม / สกิล ]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UiTheme.load_font(true))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	top.add_child(title)

	var hint_r := Label.new()
	hint_r.text = "กด [R] สลับอาวุธไว"
	hint_r.add_theme_font_size_override("font_size", 15)
	hint_r.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	top.add_child(hint_r)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 390)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	# 1. Weapons Section
	var w_hdr := Label.new()
	w_hdr.text = "⚔ คลังอาวุธ (%d ชิ้น) — กด 'สวมใส่' เพื่อสลับอาวุธได้ทันที:" % GameState.owned_weapons.size()
	w_hdr.add_theme_font_override("font", UiTheme.load_font(true))
	w_hdr.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	list.add_child(w_hdr)

	for wid in GameState.owned_weapons:
		if not GameData.WEAPONS.has(wid):
			continue
		var wd: Dictionary = GameData.WEAPONS[wid]
		var is_eq := wid == GameState.equipped_weapon
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)

		var lbl := Label.new()
		var kind_tag := "เวท" if bool(wd.get("is_magic", false)) else "กายภาพ"
		lbl.text = "• %s  [ATK %d | %s] — %s" % [wd["name"], int(wd["atk"]), kind_tag, wd.get("desc", "")]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD if is_eq else UiTheme.COL_TEXT)
		row.add_child(lbl)

		var wb := Button.new()
		wb.text = "★ สวมใส่อยู่" if is_eq else "สวมใส่"
		wb.custom_minimum_size = Vector2(115, 32)
		wb.disabled = is_eq
		wb.pressed.connect(func():
			GameState.equip_weapon(wid)
			SfxManager.play("coin")
			_show_bag_window()
		)
		row.add_child(wb)

	list.add_child(HSeparator.new())

	# 2. Consumables Section
	var c_hdr := Label.new()
	c_hdr.text = "🧪 ไอเทมในกระเป๋า (กดใช้ หรือตั้งเป็นปุ่มลัด [Q] / [V]):"
	c_hdr.add_theme_font_override("font", UiTheme.load_font(true))
	c_hdr.add_theme_color_override("font_color", Color(0.55, 0.96, 0.72))
	list.add_child(c_hdr)

	var any_item := false
	for iid in GameState.consumables.keys():
		var cnt := int(GameState.consumables[iid])
		if cnt <= 0 or not GameData.CONSUMABLES.has(iid):
			continue
		any_item = true
		var cd: Dictionary = GameData.CONSUMABLES[iid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)

		var lbl := Label.new()
		lbl.text = "• %s x%d — %s" % [cd["name"], cnt, cd.get("desc", "")]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var bq := Button.new()
		bq.text = "ตั้ง [Q]"
		bq.custom_minimum_size = Vector2(68, 30)
		bq.pressed.connect(func():
			GameState.assign_quick_slot(0, iid)
			SfxManager.play("coin")
			_show_bag_window()
		)
		row.add_child(bq)

		var bv := Button.new()
		bv.text = "ตั้ง [V]"
		bv.custom_minimum_size = Vector2(68, 30)
		bv.pressed.connect(func():
			GameState.assign_quick_slot(1, iid)
			SfxManager.play("coin")
			_show_bag_window()
		)
		row.add_child(bv)

	if not any_item:
		var empty_c := Label.new()
		empty_c.text = "  (ยังไม่มีไอเทมกดใช้ — ซื้อเพิ่มได้ที่แท็บ 'ถุงโดแกบี')"
		empty_c.add_theme_color_override("font_color", UiTheme.COL_MUTED)
		list.add_child(empty_c)

	list.add_child(HSeparator.new())

	# 3. Owned Skills Section (swap into J / K / L)
	var s_hdr := Label.new()
	s_hdr.text = "✦ สกิลที่เรียนแล้ว (%d สกิล) — เลือกใส่ช่อง [J] / [K] / [L]:" % GameState.owned_skills.size()
	s_hdr.add_theme_font_override("font", UiTheme.load_font(true))
	s_hdr.add_theme_color_override("font_color", UiTheme.COL_BORDER)
	list.add_child(s_hdr)

	var skeys := ["J", "K", "L"]
	for sid in GameState.owned_skills:
		if not GameData.SKILLS.has(sid):
			continue
		var sd: Dictionary = GameData.SKILLS[sid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)

		var cur_slot := GameState.equipped_skills.find(sid)
		var slot_tag := " [ช่อง %s]" % skeys[cur_slot] if cur_slot >= 0 else ""
		var lbl := Label.new()
		lbl.text = "• %s (%dMP)%s" % [sd["name"], int(sd["mp_cost"]), slot_tag]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD if cur_slot >= 0 else UiTheme.COL_TEXT)
		row.add_child(lbl)

		for si in 3:
			var sb := Button.new()
			sb.text = "[%s]" % skeys[si]
			sb.custom_minimum_size = Vector2(48, 30)
			sb.disabled = (cur_slot == si)
			sb.pressed.connect(func():
				GameState.equip_skill_to_slot(sid, si)
				SfxManager.play("coin")
				_show_bag_window()
			)
			row.add_child(sb)

	list.add_child(HSeparator.new())

	# 4. Key Items & Status Summary
	var k_lbl := Label.new()
	var mask_s := "✓ มีหน้ากากกันหมอกพิษ" if GameState.has_gas_mask else "✗ ยังไม่มีหน้ากากกันหมอกพิษ"
	k_lbl.text = "★ ไอเทมสำคัญ: %s   |   คู่หู: %d คน   |   พร (Boons): %d   |   เรื่องเล่า: %d" % [
		mask_s, GameState.companions.size(), GameState.owned_boons.size(), GameState.owned_fables.size()
	]
	k_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
	list.add_child(k_lbl)

	var close_btn := Button.new()
	close_btn.text = "ปิดกระเป๋า (Tab / I)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close_modal)
	v.add_child(close_btn)

	_open_panel("bag", panel)


func toggle_shop_window() -> void:
	if visible and _active_kind == "shop":
		close_modal()
		return
	if visible and _active_kind in ["sponsor", "result", "intro", "bug_box"]:
		return
	_show_shop_window()


func _make_bihyung_portrait(size_px: int = 124) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(size_px + 24, size_px + 38)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(size_px + 12, size_px + 12)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.25, 0.88, 1.0), Color(0.04, 0.09, 0.18, 0.96), 2))
	col.add_child(frame)

	var tex_rect := TextureRect.new()
	tex_rect.texture = load("res://assets/sprites/bihyung_portrait.png")
	tex_rect.custom_minimum_size = Vector2(size_px, size_px)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(tex_rect)

	var name_lbl := Label.new()
	name_lbl.text = "โดเกบิ บีฮยอง\n#BI-7623"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0))
	col.add_child(name_lbl)

	# Gentle floating bob animation
	var tw := frame.create_tween()
	tw.set_loops()
	tw.tween_property(tex_rect, "position:y", -4.0, 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tex_rect, "position:y", 4.0, 0.65).set_trans(Tween.TRANS_SINE)
	return col


func show_scenario_intro(stage_num: int = 1, is_recap: bool = false) -> void:
	var px_font := UiTheme.load_pixel_font()
	var pages: Array = GameData.get_bihyung_story_pages(stage_num, GameState.story_route)
	var page_state := {"idx": 0}

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 405)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.28, 0.86, 1.0), UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var h := Label.new()
	h.text = ScenarioManager.get_stage_title()
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", px_font)
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	v.add_child(h)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 18)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)

	mid.add_child(_make_bihyung_portrait(124))

	var speech_box := PanelContainer.new()
	speech_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech_box.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.20, 0.56, 0.82), Color(0.03, 0.06, 0.13, 0.94), 2))
	mid.add_child(speech_box)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	speech_box.add_child(sv)

	var page_hdr := Label.new()
	page_hdr.add_theme_font_override("font", px_font)
	page_hdr.add_theme_font_size_override("font_size", 18)
	page_hdr.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	sv.add_child(page_hdr)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("font", px_font)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	sv.add_child(body)

	var page_ind := Label.new()
	page_ind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page_ind.add_theme_font_size_override("font_size", 13)
	page_ind.add_theme_color_override("font_color", Color(0.62, 0.78, 0.92))
	sv.add_child(page_ind)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	v.add_child(btn_row)

	var btn_prev := Button.new()
	btn_prev.text = "◀ ย้อนกลับ"
	btn_prev.custom_minimum_size = Vector2(140, 42)
	btn_row.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.custom_minimum_size = Vector2(260, 44)
	btn_next.add_theme_font_override("font", px_font)
	btn_next.add_theme_font_size_override("font_size", 18)
	btn_next.add_theme_stylebox_override("normal", UiTheme.make_button_style(Color(0.08, 0.30, 0.46, 0.98), Color(0.35, 0.92, 1.0)))
	btn_row.add_child(btn_next)

	var btn_skip := Button.new()
	btn_skip.text = "ปิดหน้าต่าง" if is_recap else "ข้ามไปเริ่มเลย ⏭"
	btn_skip.custom_minimum_size = Vector2(160, 42)
	btn_skip.pressed.connect(close_modal)
	btn_row.add_child(btn_skip)

	var refresh_page := func():
		var idx: int = int(page_state["idx"])
		var p: Dictionary = pages[idx]
		page_hdr.text = String(p.get("header", ""))
		body.text = String(p.get("text", ""))
		page_ind.text = "หน้า %d / %d" % [idx + 1, pages.size()]
		btn_prev.disabled = idx <= 0
		if idx < pages.size() - 1:
			btn_next.text = "ฟังบีฮยองต่อ ▶"
		else:
			btn_next.text = "กลับไปลุยต่อ!" if is_recap else "รับทราบ — เริ่มบทละคร!"

	btn_prev.pressed.connect(func():
		if int(page_state["idx"]) > 0:
			page_state["idx"] = int(page_state["idx"]) - 1
			SfxManager.play("system")
			refresh_page.call()
	)
	btn_next.pressed.connect(func():
		if int(page_state["idx"]) < pages.size() - 1:
			page_state["idx"] = int(page_state["idx"]) + 1
			SfxManager.play("system")
			refresh_page.call()
		else:
			close_modal()
	)
	refresh_page.call()
	_open_panel("bihyung_recap" if is_recap else "intro", panel)


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
		prob_lbl.text = "🐉 ระดับพลังรวม: Lv.%d / เพดานบทละครที่ %d: Lv.%d  —  เกินเพดานแล้ว! 'มังกรแห่งวันสิ้นโลก' กำลังตื่นขึ้น!" % [lv_now, ScenarioManager.current_stage, lv_cap]
		prob_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.35))
	elif lv_now == lv_cap:
		prob_lbl.text = "⚠ ระดับพลังรวม: Lv.%d / เพดานบทละครที่ %d: Lv.%d  —  ถึงเพดานแล้ว! หากอัปเกิน 'มังกรแห่งวันสิ้นโลก' จะออกมาพิพากษาทันที" % [lv_now, ScenarioManager.current_stage, lv_cap]
		prob_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.25))
	else:
		prob_lbl.text = "ระดับพลังรวม: Lv.%d / เพดานบทละครที่ %d: Lv.%d (อัปเพิ่มได้อีก %d Lv ก่อนมังกรแห่งวันสิ้นโลกจะตื่น)" % [lv_now, ScenarioManager.current_stage, lv_cap, lv_cap - lv_now]
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
	var bihyung_row := HBoxContainer.new()
	bihyung_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bihyung_row.add_theme_constant_override("separation", 14)
	v.add_child(bihyung_row)

	var mini_p := TextureRect.new()
	mini_p.texture = load("res://assets/sprites/bihyung_portrait.png")
	mini_p.custom_minimum_size = Vector2(64, 64)
	mini_p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini_p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bihyung_row.add_child(mini_p)

	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.text = "บีฮยอง: \"" + sub.text + "\""
	bihyung_row.add_child(sub)

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
	var bihyung_row := HBoxContainer.new()
	bihyung_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bihyung_row.add_theme_constant_override("separation", 14)
	v.add_child(bihyung_row)

	var mini_p := TextureRect.new()
	mini_p.texture = load("res://assets/sprites/bihyung_portrait.png")
	mini_p.custom_minimum_size = Vector2(64, 64)
	mini_p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini_p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bihyung_row.add_child(mini_p)

	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.text = "บีฮยอง: \"" + sub.text + "\""
	bihyung_row.add_child(sub)

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


func show_story_route_choice(cleared_stage: int) -> void:
	var px_font := UiTheme.load_pixel_font()
	var next_s := mini(GameData.MAX_CHAPTER, cleared_stage + 1)
	var skip_s := mini(GameData.MAX_CHAPTER, cleared_stage + 2)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 480)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.32, 0.86, 1.0), UiTheme.COL_BG, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var h := Label.new()
	h.text = "[ ★ ทางแยกแห่งชะตากรรม — เลือกเส้นทางหลังบทที่ %d ★ ]" % cleared_stage
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", px_font)
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	v.add_child(h)

	var sub := Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", px_font)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))

	var options: Array = []
	if cleared_stage == 1:
		sub.text = "ประตูขบวนรถไฟ 3707 เปิดออกสู่ความมืดเหนือสะพานตงโฮ... คุณจะเลือกเดินเส้นทางไหนในโลกของนิยายเรื่องนี้?"
		options = [
			["🛡 เดินตามกลุ่มตัวเอกสู่สะพานตงโฮ (ไปบทที่ 2)", "สายผู้กอบกู้: ฟื้น HP/MP เต็ม + รับ 150 เหรียญ", 2, "route_dongho_allies", Color(0.08, 0.30, 0.42, 0.96)],
			["😈 ทำสัญญาลับกับโดแกบีบีฮยอง (ไปบทที่ 2)", "สายโกงระบบ: รับ +350 เหรียญ +4 ATK ถาวรทันที!", 2, "route_bihyung_deal", Color(0.32, 0.12, 0.36, 0.96)],
			["⚡ พุ่งลัดข้ามสะพานไปชิง Green Zone ก่อนใคร! (ข้ามไปบทที่ 3)", "เส้นทางลัดเสี่ยงตาย: ข้ามไปบทที่ 3 ทันที + รับ 400 เหรียญ", 3, "route_rush_greenzone", Color(0.34, 0.22, 0.05, 0.96)],
		]
	elif cleared_stage == 4:
		sub.text = "เบื้องหน้าของคุณคือ 'บัลลังก์สัมบูรณ์' ที่เหล่ากลุ่มดาวเฝ้าจับตามอง... คุณจะทำลายมันแบบคิมดกจา หรือจะนั่งครองอำนาจ?"
		options = [
			["🔥 ทำลาย 'บัลลังก์สัมบูรณ์' ทิ้ง! (เส้นทางราชาไร้บัลลังก์ → บทที่ 5)", "เหมือนในนิยาย! +15 ATK ถาวร + 800 เหรียญ + ปลดล็อกฉากจบลับ", 5, "route_destroy_throne", Color(0.10, 0.32, 0.46, 0.96)],
			["👑 นั่งครอง 'บัลลังก์สัมบูรณ์'! (เส้นทางทรราชแห่งโซล → บทที่ 5)", "อำนาจเบ็ดเสร็จ: +1,500 เหรียญ +10 ATK ถาวร", 5, "route_claim_throne", Color(0.42, 0.10, 0.16, 0.96)],
			["⚡ ลัดไปดักสังหาร 'หายนะแห่งคำถาม' ก่อนตื่น! (ข้ามไปบทที่ 6)", "เส้นทางลัด: ข้ามไปบทที่ 6 + รับ 550 เหรียญ + หน้ากากกันพิษฟรี", 6, "route_ambush_disaster", Color(0.32, 0.24, 0.06, 0.96)],
		]
	else:
		var next_title: String = GameData.CHAPTERS.get(next_s, {}).get("title", "บทละครที่ %d" % next_s)
		sub.text = "เหล่ากลุ่มดาวกำลังรอดูการตัดสินใจของคุณ! เส้นทางที่เลือกจะเปลี่ยนโบนัสและฉากจบในบทที่ 20"
		options = [
			["🛡 เส้นทางหลัก: มุ่งหน้าสู่ %s" % next_title, "สายผู้กอบกู้: ฟื้น HP/MP เต็ม + ชุดปฐมพยาบาล x1", next_s, "route_steady_march", Color(0.08, 0.28, 0.40, 0.96)],
			["🔥 ท้าทายกลุ่มดาวกลางแชนแนลแล้วบุก %s" % next_title, "สายราชาไร้บัลลังก์: +500 เหรียญ +5 ATK ถาวร", next_s, "route_rebel_constellations", Color(0.30, 0.14, 0.34, 0.96)],
		]
		if cleared_stage <= GameData.MAX_CHAPTER - 2:
			var skip_title: String = GameData.CHAPTERS.get(skip_s, {}).get("title", "บทละครที่ %d" % skip_s)
			options.append(["⚡ เส้นทางลัดเสี่ยงตาย: ข้ามไปบุก %s!" % skip_title, "ท้าทายชะตากรรม: ข้าม 1 บท + รับ 900 เหรียญ +8 ATK ถาวร", skip_s, "route_skip_ahead", Color(0.36, 0.22, 0.05, 0.96)])

	var bihyung_row := HBoxContainer.new()
	bihyung_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bihyung_row.add_theme_constant_override("separation", 14)
	v.add_child(bihyung_row)

	var mini_p := TextureRect.new()
	mini_p.texture = load("res://assets/sprites/bihyung_portrait.png")
	mini_p.custom_minimum_size = Vector2(64, 64)
	mini_p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini_p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bihyung_row.add_child(mini_p)

	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.text = "บีฮยอง: \"" + sub.text + "\""
	bihyung_row.add_child(sub)

	for opt in options:
		var btn := Button.new()
		btn.text = "%s\n   ↳ %s" % [opt[0], opt[1]]
		btn.custom_minimum_size = Vector2(740, 74)
		btn.add_theme_stylebox_override("normal", UiTheme.make_button_style(opt[4], UiTheme.COL_BORDER))
		var t_stage: int = int(opt[2])
		var cid: String = String(opt[3])
		btn.pressed.connect(func():
			close_modal()
			route_choice_selected.emit(t_stage, cid)
		)
		v.add_child(btn)

	_open_panel("route_choice", panel)


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
		h.text = "[ ★★★ พิชิตครบทั้ง 20 บทละครแห่งโดมกรุงโซล! ★★★ ]"
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
		var route_ending := "คุณพิชิตครบทั้ง 20 บทละครและโค่น 'มหาเทพแห่งปราสาทมืด' ลงได้สำเร็จ!"
		if GameState.story_route == "kingless":
			route_ending = "★ [ฉากจบลับ: ราชาไร้บัลลังก์ผู้ฉีกชะตากรรม] ★\nคุณทำลายบัลลังก์สัมบูรณ์ ท้าทายเหล่ากลุ่มดาว และปลดปล่อยโดมกรุงโซลด้วยสองมือของตัวเอง!"
		elif GameState.story_route == "tyrant":
			route_ending = "👑 [ฉากจบ: จักรพรรดิทรราชแห่งโดมกรุงโซล] 👑\nคุณครองบัลลังก์สัมบูรณ์และสยบมหาเทพแห่งปราสาทมืด กรุงโซลทั้งหมดก้มหัวให้แก่คุณ!"
		elif GameState.story_route == "savior":
			route_ending = "🛡 [ฉากจบ: ผู้กอบกู้แห่งสถานีรถไฟใต้ดิน] 🛡\nคุณปกป้องผู้รอดชีวิตและคู่หูจนถึงบทสรุปที่ 20 แสงสว่างกลับคืนสู่กรุงโซลอีกครั้ง!"
		end_desc = "%s\n\n" % route_ending
	elif ScenarioManager.ending_type == "chapter_clear":
		var cd_res: Dictionary = GameData.CHAPTERS.get(ScenarioManager.current_stage, {})
		end_desc = "คุณโค่น '%s' และพิชิตบทละครที่ %d สำเร็จ! (+%d เหรียญ)\n\n" % [String(cd_res.get("boss_name", "บอส")), ScenarioManager.current_stage, int(cd_res.get("reward_coins", 1500))]
	elif ScenarioManager.ending_type == "stage4_clear":
		end_desc = "คุณยึดธงสถานีครบทั้ง 2 จุดและโค่น 'ทรราชผู้ชิงบัลลังก์' ได้สำเร็จ! เส้นทางสู่บทที่ 5: บัลลังก์สัมบูรณ์เปิดออกแล้ว! (+1,200 เหรียญ)\n\n"
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

	if victory and ScenarioManager.current_stage < GameData.MAX_CHAPTER:
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
