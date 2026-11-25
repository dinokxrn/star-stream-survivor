extends Node

const GameData = preload("res://scripts/data/GameData.gd")

signal scenario_updated
signal constellation_message(text: String, coin_bonus: int)
signal scenario_condition_met(path_type: String)
signal scenario_cleared(path_type: String)
signal scenario_exited(ending_type: String)
signal scenario_failed(reason: String)

const SCENARIO_1_DURATION: float = 180.0
const STAGE_1_KILLS_REQUIRED: int = 3
const SECRET_MAIN_CAST_MIN_REMAINING: float = 155.0 # >= 02:35 remaining (beat 3 enemies in <= 25s!)
const PERFECT_DODGE_SPONSOR_COOLDOWN: float = 3.5

var current_stage: int = 1 # 1..4
var is_active: bool = false
var condition_met: bool = false
var is_cleared: bool = false
var is_farming: bool = false
var clear_path: String = ""
var ending_type: String = ""
var clear_time_remaining: float = 0.0
var time_remaining: float = SCENARIO_1_DURATION
var elapsed_time: float = 0.0

# Stage-specific progress flags
var stage1_kills: int = 0
var sub_rescue_done: bool = false
var hidden_bug_done: bool = false
var stage2_boss_dead: bool = false
var stage2_kills: int = 0
const STAGE_2_KILLS_REQUIRED: int = 6
var stage3_zone_claimed: bool = false
var stage3_wave: int = 0
const STAGE_3_TOTAL_WAVES: int = 5
var stage3_sub_rescue_done: bool = false
var stage4_flags_captured: int = 0
var stage4_boss_dead: bool = false

# Generic Chapter 5..20 progress
var chapter_kills: int = 0
var chapter_kills_req: int = 8
var chapter_flags: int = 0
var chapter_flags_req: int = 0
var chapter_boss_dead: bool = false

# Sudden Dokkaebi Events
var sudden_event_active: bool = false
var sudden_event_kind: String = "" # untouchable, elite_hunt, blackout
var sudden_event_timer: float = 0.0
var sudden_event_text: String = ""
var blackout_active: bool = false

var _dodge_sponsor_cd: float = 0.0

const CONSTELLATION_NAMES: Array[String] = [
	"ผู้เฝ้ามองในเงามืด",
	"นักดาบแห่งแสงจันทร์",
	"ผู้พิทักษ์เปลวไฟนิรันดร์",
	"นักเดินทางแห่งห้วงดารา",
]

const STAGE_TITLES: Dictionary = {
	1: "[ บทละครหลัก #1: พิสูจน์คุณค่า ]",
	2: "[ บทละครหลัก #2: พบปะ — สะพานตงโฮ ]",
	3: "[ บทละครหลัก #3: เขตสีเขียว — สถานีโอกซู ]",
	4: "[ บทละครหลัก #4: ศึกชิงธง — ปราการแห่งราชา ]",
}


func _ready() -> void:
	GameState.fable_unlocked.connect(_on_fable_unlocked)


func _on_fable_unlocked(fdata: Dictionary) -> void:
	constellation_message.emit("[★ ปลดล็อก%s (%s)! %s]" % [fdata["name"], fdata["rarity"], fdata["desc"]], 0)


func get_stage_title() -> String:
	if GameData.CHAPTERS.has(current_stage):
		return String(GameData.CHAPTERS[current_stage]["title"])
	return String(STAGE_TITLES.get(current_stage, STAGE_TITLES[1]))


func get_chapter_data(stage_num: int = -1) -> Dictionary:
	var s := current_stage if stage_num < 0 else stage_num
	return GameData.CHAPTERS.get(s, {})


func start_scenario_1() -> void:
	start_scenario(1)


func start_scenario(stage_num: int) -> void:
	current_stage = clampi(stage_num, 1, GameData.MAX_CHAPTER)
	is_active = true
	condition_met = false
	is_cleared = false
	is_farming = false
	clear_path = ""
	ending_type = ""
	clear_time_remaining = 0.0
	elapsed_time = 0.0
	_dodge_sponsor_cd = 0.0
	sudden_event_active = false
	sudden_event_kind = ""
	sudden_event_timer = 0.0
	sudden_event_text = ""
	blackout_active = false

	if current_stage == 1:
		time_remaining = SCENARIO_1_DURATION
		stage1_kills = 0
		sub_rescue_done = false
		hidden_bug_done = false
		constellation_message.emit("[แชนแนล #BI-7623 เปิดใช้งานแล้ว! โค่นศัตรูอย่างน้อย 3 ตัว หรือหากล่องแมลงในตู้ 3!]", 0)
	elif current_stage == 2:
		time_remaining = 220.0
		stage2_boss_dead = false
		stage2_kills = 0
		GameState.stage_heals_bought = 0
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + int(round(float(GameState.get_max_hp()) * 0.40)))
		GameState.mp = GameState.get_max_mp()
		GameState.hp_mp_changed.emit()
		if GameState.met_main_cast:
			GameState.add_consumable("potion_small", 1)
			constellation_message.emit("[กลุ่มตัวเอกจากตู้ 3807 โยนน้ำยารักษาและเตือนคุณเรื่องหมอกพิษบนสะพานตงโฮ!]", 0)
		else:
			constellation_message.emit("[บทละครหลัก #2 เริ่มต้น! กวาดล้างอสูรบนสะพาน (6 ตัว) + โค่นบอส แล้วเข้าสถานีโอกซู]", 0)
	elif current_stage == 3:
		time_remaining = 260.0
		stage3_zone_claimed = false
		stage3_wave = 0
		stage3_sub_rescue_done = false
		GameState.stage_heals_bought = 0
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + int(round(float(GameState.get_max_hp()) * 0.40)))
		GameState.mp = GameState.get_max_mp()
		GameState.hp_mp_changed.emit()
		constellation_message.emit("[บทละครหลัก #3 เริ่มต้น! กด [F] ยึดเขต Green Zone และเอาชีวิตรอดให้ครบ 5 เวฟสุดโหด!]", 0)
	elif current_stage == 4:
		time_remaining = 300.0
		stage4_flags_captured = 0
		stage4_boss_dead = false
		GameState.stage_heals_bought = 0
		GameState.flag_atk_bonus = 0
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + int(round(float(GameState.get_max_hp()) * 0.40)))
		GameState.mp = GameState.get_max_mp()
		GameState.hp_mp_changed.emit()
		constellation_message.emit("[บทละครหลัก #4 เริ่มต้น! กำจัดผู้เฝ้าธงเพื่อยึดธง 2 จุด และโค่นทรราช 3 เฟส!]", 0)
	elif GameData.CHAPTERS.has(current_stage):
		var cd: Dictionary = GameData.CHAPTERS[current_stage]
		time_remaining = float(cd.get("time_limit", 300.0))
		chapter_kills = 0
		chapter_kills_req = int(cd.get("kills_req", 8))
		chapter_flags = 0
		chapter_flags_req = int(cd.get("flags_req", 0))
		chapter_boss_dead = false
		GameState.stage_heals_bought = 0
		GameState.flag_atk_bonus = 0
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + int(round(float(GameState.get_max_hp()) * 0.45)))
		GameState.mp = GameState.get_max_mp()
		GameState.hp_mp_changed.emit()
		constellation_message.emit("[%s เริ่มต้น! โค่น '%s'!]" % [cd["title"], cd["boss_name"]], 0)

	scenario_updated.emit()


func tick(delta: float) -> void:
	if _dodge_sponsor_cd > 0.0:
		_dodge_sponsor_cd = maxf(0.0, _dodge_sponsor_cd - delta)
	if not is_active or is_cleared:
		return
	elapsed_time += delta
	time_remaining = maxf(0.0, time_remaining - delta)
	if sudden_event_active:
		sudden_event_timer = maxf(0.0, sudden_event_timer - delta)
		if sudden_event_timer <= 0.0:
			_finish_sudden_event_timeout()
	scenario_updated.emit()
	if time_remaining <= 0.0:
		is_active = false
		if current_stage == 1 and condition_met:
			is_cleared = true
			is_farming = false
			ending_type = "waited_timeout"
			scenario_exited.emit(ending_type)
		else:
			scenario_failed.emit("หมดเวลา%s" % get_stage_title())


func trigger_perfect_dodge() -> void:
	if not is_active or is_cleared:
		return
	GameState.perfect_dodges += 1
	if _dodge_sponsor_cd > 0.0:
		return
	_dodge_sponsor_cd = PERFECT_DODGE_SPONSOR_COOLDOWN
	var bonus := 20 + (current_stage - 1) * 5
	if GameState.current_attribute_id == "morning_runner":
		bonus = int(round(float(bonus) * 1.5))
	elif GameState.current_attribute_id == "apocalypse_reader":
		bonus = int(round(float(bonus) * 1.3))
	GameState.add_coins(bonus, "perfect_dodge")
	var cname: String = CONSTELLATION_NAMES[GameState.perfect_dodges % CONSTELLATION_NAMES.size()]
	constellation_message.emit("[กลุ่มดาว '%s' ชื่นชมการหลบหลีกของคุณ และสนับสนุน %d เหรียญ!]" % [cname, bonus], bonus)


func register_enemy_killed(enemy_type: String, is_human: bool) -> void:
	GameState.enemies_defeated += 1
	if GameState.current_attribute_id == "necro_train":
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + 18)
		GameState.mp = mini(GameState.get_max_mp(), GameState.mp + 15)
		GameState.hp_mp_changed.emit()
	var drop := 35
	if enemy_type == "charger" or enemy_type == "thrower":
		drop = 55
	elif enemy_type == "mage":
		drop = 70
	elif enemy_type == "brute":
		drop = 95
	elif enemy_type == "boss":
		drop = 180
	elif enemy_type == "boss_bridge":
		drop = 240
	elif enemy_type == "boss_station":
		drop = 300
	elif enemy_type == "boss_king":
		drop = 450
	if GameState.current_attribute_id == "apocalypse_reader":
		drop = int(round(float(drop) * 1.3))
	drop = int(round(float(drop) * GameState.get_hype_coin_mult()))
	GameState.add_coins(drop, "kill_" + enemy_type)

	if enemy_type.begins_with("boss"):
		GameState.unlock_fable("fable_giant_slayer")
	if current_stage == 1:
		stage1_kills += 1
		if enemy_type == "boss":
			constellation_message.emit("[กลุ่มดาว 'นักดาบแห่งแสงจันทร์' ทึ่งในฝีมือของคุณ! สนับสนุน 100 เหรียญ]", 100)
			GameState.add_coins(100, "boss_sponsor")
		if is_active and not condition_met and is_human and (stage1_kills >= STAGE_1_KILLS_REQUIRED or enemy_type == "boss"):
			_mark_condition_met("combat_boss" if enemy_type == "boss" else "combat", 300)
		scenario_updated.emit()
	elif current_stage == 2:
		stage2_kills += 1
		if enemy_type == "boss_bridge":
			stage2_boss_dead = true
			constellation_message.emit("[โค่นอสูรสะพานตงโฮสำเร็จ! กวาดล้างให้ครบ 6 ตัวแล้วไปกด [F] ที่ประตูสถานีโอกซู]", 0)
		scenario_updated.emit()
	elif current_stage == 4:
		if enemy_type == "boss_king":
			stage4_boss_dead = true
			_try_finish_stage_4()
	elif current_stage >= 5:
		chapter_kills += 1
		if enemy_type.begins_with("boss"):
			chapter_boss_dead = true
		scenario_updated.emit()
		_try_finish_dynamic_chapter()


func complete_sub_rescue() -> void:
	if current_stage == 1:
		if sub_rescue_done:
			return
		sub_rescue_done = true
		GameState.add_coins(150, "sub_rescue")
		GameState.add_consumable("potion_small", 1)
		GameState.add_companion("yuna")
		constellation_message.emit("[บทละครรองสำเร็จ! 'ซอ ยูนา' เข้าร่วมทีมคอยช่วยสู้และฮีลคุณ! (+150 เหรียญ)]", 150)
	elif current_stage == 3:
		if stage3_sub_rescue_done:
			return
		stage3_sub_rescue_done = true
		GameState.add_coins(200, "stage3_rescue")
		GameState.add_consumable("medkit", 1)
		GameState.add_companion("jaehoon")
		constellation_message.emit("[บทละครรองสำเร็จ! 'พัค แจฮุน' เข้าร่วมทีมเป็นแนวหน้าช่วยสู้! (+200 เหรียญ)]", 200)
	scenario_updated.emit()


func complete_stage2_gas_mask() -> void:
	if GameState.has_gas_mask:
		return
	GameState.has_gas_mask = true
	GameState.inventory_changed.emit()
	GameState.add_coins(150, "sub_gas_mask")
	constellation_message.emit("[บทละครรอง 'เตรียมรับมือหมอกพิษ' สำเร็จ! ได้รับหน้ากากกันพิษ + 150 เหรียญ]", 150)
	scenario_updated.emit()


func complete_stage2_reach_station() -> void:
	if current_stage != 2 or is_cleared:
		return
	is_cleared = true
	is_active = false
	condition_met = true
	clear_path = "stage2_bridge"
	ending_type = "stage2_clear"
	GameState.add_coins(500, "stage2_clear")
	scenario_updated.emit()
	scenario_exited.emit("stage2_clear")


func set_stage3_wave(wave_num: int) -> void:
	stage3_zone_claimed = true
	stage3_wave = wave_num
	constellation_message.emit("[เขต Green Zone — เวฟที่ %d / %d เริ่มต้น! อย่าออกนอกวงแสงสีเขียว!]" % [wave_num, STAGE_3_TOTAL_WAVES], 0)
	scenario_updated.emit()


func complete_stage3_defense() -> void:
	if current_stage != 3 or is_cleared:
		return
	is_cleared = true
	is_active = false
	condition_met = true
	clear_path = "stage3_green_zone"
	ending_type = "stage3_clear"
	GameState.add_coins(700, "stage3_clear")
	scenario_updated.emit()
	scenario_exited.emit("stage3_clear")


func register_stage4_flag_captured() -> void:
	if is_cleared:
		return
	if current_stage == 4:
		stage4_flags_captured += 1
		GameState.flag_atk_bonus += 6
		GameState.add_coins(200, "stage4_flag")
		GameState.stats_changed.emit()
		constellation_message.emit("[ยึดธงสถานีสำเร็จ (%d/2)! พลังโจมตีเพิ่ม +6 และรับ 200 เหรียญ]" % stage4_flags_captured, 200)
		scenario_updated.emit()
		_try_finish_stage_4()
	elif current_stage >= 5 and chapter_flags_req > 0:
		chapter_flags += 1
		GameState.flag_atk_bonus += 8
		var fbonus := 250 + current_stage * 20
		GameState.add_coins(fbonus, "chapter_flag")
		GameState.stats_changed.emit()
		constellation_message.emit("[ทำลายผนึก/ยึดธงสำเร็จ (%d/%d)! +8 ATK & +%d เหรียญ]" % [chapter_flags, chapter_flags_req, fbonus], fbonus)
		scenario_updated.emit()
		_try_finish_dynamic_chapter()


func _try_finish_stage_4() -> void:
	if current_stage != 4 or is_cleared:
		return
	if stage4_flags_captured >= 2 and stage4_boss_dead:
		is_cleared = true
		is_active = false
		condition_met = true
		clear_path = "stage4_king"
		ending_type = "stage4_clear"
		GameState.add_coins(1200, "stage4_clear")
		constellation_message.emit("[★ บทละครหลัก #4 เสร็จสมบูรณ์! ปลดล็อกบทที่ 5: บัลลังก์สัมบูรณ์! (+1,200 เหรียญ)]", 1200)
		scenario_updated.emit()
		scenario_exited.emit("stage4_clear")


func _try_finish_dynamic_chapter() -> void:
	if current_stage < 5 or is_cleared:
		return
	if chapter_boss_dead and chapter_kills >= chapter_kills_req and chapter_flags >= chapter_flags_req:
		is_cleared = true
		is_active = false
		condition_met = true
		clear_path = "chapter_%d" % current_stage
		var is_final := (current_stage >= GameData.MAX_CHAPTER)
		ending_type = "campaign_victory" if is_final else "chapter_clear"
		var cd: Dictionary = GameData.CHAPTERS.get(current_stage, {})
		var rew := int(cd.get("reward_coins", 1500))
		GameState.add_coins(rew, "chapter_%d_clear" % current_stage)
		if is_final:
			constellation_message.emit("[★★★ พิชิตครบทั้ง 20 บทละครแห่งโดมกรุงโซล! คุณคือผู้พิชิตบทละครที่แท้จริง! (+%d เหรียญ) ★★★]" % rew, rew)
		else:
			constellation_message.emit("[★ บทละครหลัก #%d เสร็จสมบูรณ์! (+%d เหรียญ)]" % [current_stage, rew], rew)
		scenario_updated.emit()
		scenario_exited.emit(ending_type)


func complete_hidden_bug_box() -> void:
	if current_stage != 1 or not is_active or condition_met:
		return
	hidden_bug_done = true
	GameState.add_coins(250, "hidden_scenario")
	GameState.unlock_fable("fable_pacifist")
	var unlocked := GameState.unlock_attribute_skills()
	var skill_note := " + ปลดล็อกสกิลอาชีพ: %s" % ", ".join(unlocked) if not unlocked.is_empty() else ""
	constellation_message.emit("[บทละครลับ 'ผู้ไม่ยอมจำนนต่อความบ้าคลั่ง' สำเร็จ! กลุ่มดาวประทับใจและมอบ 250 เหรียญ%s]" % skill_note, 250)
	_mark_condition_met("hidden_pacifist", 300)


func _mark_condition_met(path_type: String, reward_coins: int) -> void:
	if condition_met:
		return
	condition_met = true
	clear_path = path_type
	clear_time_remaining = time_remaining
	GameState.add_coins(reward_coins, "scenario_1_clear")
	scenario_updated.emit()
	scenario_condition_met.emit(path_type)
	scenario_cleared.emit(path_type)


func can_trigger_main_cast_secret() -> bool:
	return current_stage == 1 and condition_met and time_remaining >= SECRET_MAIN_CAST_MIN_REMAINING


func choose_stay_and_farm() -> void:
	if not condition_met or is_cleared:
		return
	is_farming = true
	constellation_message.emit("[คุณเลือกอยู่ฟาร์มในขบวนต่อ! กด [R] ใช้สติกมา หรือกด [G] ออกจากรถไฟได้ทุกเมื่อ]", 0)
	scenario_updated.emit()


func exit_train_now() -> void:
	if current_stage != 1 or not condition_met or is_cleared:
		return
	is_cleared = true
	is_active = false
	is_farming = false
	if time_remaining >= SECRET_MAIN_CAST_MIN_REMAINING:
		ending_type = "secret_main_cast"
		GameState.met_main_cast = true
		GameState.unlock_fable("fable_main_cast")
		GameState.add_coins(500, "secret_main_cast")
		var unlocked := GameState.unlock_attribute_skills()
		var skill_note := " + ปลดล็อกสกิล: %s" % ", ".join(unlocked) if not unlocked.is_empty() else ""
		constellation_message.emit("[อีเวนต์พิเศษ! คุณออกจากขบวนทันเวลา 02:50 และได้พบกับกลุ่มตัวเอกที่ตู้ 3807! (+500 เหรียญ%s)]" % skill_note, 500)
	else:
		ending_type = "early_exit"
	scenario_updated.emit()
	scenario_exited.emit(ending_type)


func select_sponsor(sponsor_id: String) -> void:
	if not GameData.SPONSORS.has(sponsor_id):
		return
	GameState.selected_sponsor_id = sponsor_id
	var sp: Dictionary = GameData.SPONSORS[sponsor_id]
	var bonus := int(sp.get("bonus_coins", 0))
	if bonus > 0:
		GameState.add_coins(bonus, "sponsor_reject")
	if sponsor_id == "moonlight":
		GameState.stats["str"] += 1
	elif sponsor_id == "moonless_shadow":
		GameState.stats["agi"] += 1
	elif sponsor_id == "eternal_flame":
		GameState.stats["phy"] += 1
		GameState.stats["mag"] += 1
	GameState.stigma_skill_id = String(sp.get("stigma_skill_id", ""))
	GameState.stigma_cooldown = 0.0
	var unlocked := GameState.unlock_attribute_skills()
	GameState.stats_changed.emit()
	GameState.skills_changed.emit()
	var extra_note := " | ปลุกสกิลอาชีพ: %s" % ", ".join(unlocked) if not unlocked.is_empty() else ""
	constellation_message.emit("[ได้รับสติกมาใหม่: %s — กด [E] เพื่อใช้งาน!%s]" % [sp["stigma"], extra_note], bonus)


func trigger_parry_reward() -> void:
	if not is_active or is_cleared:
		return
	var bonus := int(round(35.0 * GameState.get_hype_coin_mult()))
	GameState.add_coins(bonus, "parry")
	constellation_message.emit("[★ PARRY สมบูรณ์แบบ! กลุ่มดาวคลั่งไคล้และโยนให้ +%d เหรียญ!]" % bonus, bonus)


func start_sudden_event(kind: String) -> void:
	if sudden_event_active or not is_active or is_cleared:
		return
	sudden_event_active = true
	sudden_event_kind = kind
	blackout_active = (kind == "blackout")
	if kind == "untouchable":
		sudden_event_timer = 15.0
		sudden_event_text = "อีเวนต์โดแกบี: ห้ามโดนตี 15 วิ (+180 เหรียญ)"
		constellation_message.emit("[อีเวนต์ฉับพลันจากโดแกบี! ห้ามโดนโจมตี 15 วินาที รับ 180 เหรียญ!]", 0)
	elif kind == "elite_hunt":
		sudden_event_timer = 25.0
		sudden_event_text = "อีเวนต์โดแกบี: ล่าศัตรู GOLD ELITE ใน 25 วิ (+260 เหรียญ)"
		constellation_message.emit("[อีเวนต์ฉับพลัน! ศัตรู GOLD ELITE โผล่มาแล้ว กำจัดใน 25 วิ รับ 260 เหรียญ!]", 0)
	else:
		sudden_event_timer = 7.0
		sudden_event_text = "อีเวนต์โดแกบี: ไฟดับฉับพลัน! เอาชีวิตรอด 7 วิ (+120 เหรียญ)"
		constellation_message.emit("[อีเวนต์ฉับพลัน! ไฟดับทั้งพื้นที่ 7 วิ ศัตรูคลุ้มคลั่งไวขึ้น!]", 0)
	scenario_updated.emit()


func notify_player_took_damage() -> void:
	if sudden_event_active and sudden_event_kind == "untouchable":
		sudden_event_active = false
		sudden_event_kind = ""
		sudden_event_text = ""
		constellation_message.emit("[อีเวนต์ห้ามโดนตีล้มเหลว! กลุ่มดาวหัวเราะเยาะคุณ]", 0)
		scenario_updated.emit()


func register_elite_killed(is_golden: bool) -> void:
	var extra := 160 if is_golden else 90
	extra = int(round(float(extra) * GameState.get_hype_coin_mult()))
	GameState.add_coins(extra, "elite_kill")
	if is_golden and sudden_event_active and sudden_event_kind == "elite_hunt":
		sudden_event_active = false
		sudden_event_kind = ""
		sudden_event_text = ""
		GameState.add_coins(260, "sudden_elite_clear")
		GameState.add_consumable("medkit", 1)
		constellation_message.emit("[★ ล่า GOLD ELITE สำเร็จ! รับ 260 เหรียญ + ชุดปฐมพยาบาล!]", 260)
		scenario_updated.emit()


func _finish_sudden_event_timeout() -> void:
	var kind := sudden_event_kind
	sudden_event_active = false
	sudden_event_kind = ""
	sudden_event_text = ""
	blackout_active = false
	if kind == "untouchable":
		GameState.add_coins(180, "sudden_untouchable")
		GameState.add_hype(25.0, 2)
		constellation_message.emit("[★ ผ่านบททดสอบห้ามโดนตี! รับ 180 เหรียญ + HYPE พุ่ง!]", 180)
	elif kind == "blackout":
		GameState.add_coins(120, "sudden_blackout")
		constellation_message.emit("[★ รอดจากความมืดไฟดับ! รับ 120 เหรียญ]", 120)
	elif kind == "elite_hunt":
		constellation_message.emit("[หมดเวลาล่า GOLD ELITE!]", 0)
	scenario_updated.emit()
