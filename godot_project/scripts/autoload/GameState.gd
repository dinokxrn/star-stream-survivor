extends Node

const GameData = preload("res://scripts/data/GameData.gd")

signal stats_changed
signal coins_changed(new_amount: int, delta: int)
signal inventory_changed
signal skills_changed
signal hp_mp_changed
signal hype_changed(rank: String, combo: int, hype_val: float)
signal fable_unlocked(fable_data: Dictionary)

var player_name: String = "คัง มินซู"
var selected_char_index: int = 0
var current_attribute_id: String = "office_worker"
var current_attribute: Dictionary = {}

var stats: Dictionary = {"str": 1, "phy": 1, "agi": 1, "mag": 1}
var coins: int = 0
var hp: int = 100
var mp: int = 55
var stamina: float = 100.0
const MAX_STAMINA: float = 100.0
var item_cooldown: float = 0.0
var stage_heals_bought: int = 0
const MAX_HEALS_PER_STAGE: int = 3
var shield_hp: int = 0
var shield_timer: float = 0.0

# Active Buff timers
var buff_atk_timer: float = 0.0 # +40% ATK
var buff_haste_timer: float = 0.0 # +45% Move & 2x Stamina regen
var buff_iron_timer: float = 0.0 # -50% damage taken
var buff_arcane_timer: float = 0.0 # +45% magic skill damage

var owned_weapons: Array[String] = []
var equipped_weapon: String = "umbrella"

var consumables: Dictionary = {}
var quick_slots: Array[String] = ["potion_small", "mana_stone"]

var owned_skills: Array[String] = []
var equipped_skills: Array[String] = ["desperate_slash", "", ""]
var skill_cooldowns: Dictionary = {}

var selected_sponsor_id: String = ""
var stigma_skill_id: String = ""
var stigma_cooldown: float = 0.0
var has_gas_mask: bool = false
var met_main_cast: bool = false
var flag_atk_bonus: int = 0
var owned_boons: Array[String] = []
var owned_fables: Array[String] = []
var companions: Array[String] = []
var hype_score: float = 0.0 # 0..100
var combo_count: int = 0
var _hype_decay_delay: float = 0.0
var _bastion_timer: float = 12.0
var parries_landed: int = 0
var total_coins_earned: int = 0
var perfect_dodges: int = 0
var enemies_defeated: int = 0


func _ready() -> void:
	start_new_run("office_worker")


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	for sid in skill_cooldowns.keys():
		if skill_cooldowns[sid] > 0.0:
			skill_cooldowns[sid] = max(0.0, skill_cooldowns[sid] - delta)
	if stigma_cooldown > 0.0:
		stigma_cooldown = maxf(0.0, stigma_cooldown - delta)
	if item_cooldown > 0.0:
		item_cooldown = maxf(0.0, item_cooldown - delta)
	if buff_atk_timer > 0.0:
		buff_atk_timer = maxf(0.0, buff_atk_timer - delta)
	if buff_haste_timer > 0.0:
		buff_haste_timer = maxf(0.0, buff_haste_timer - delta)
	if buff_iron_timer > 0.0:
		buff_iron_timer = maxf(0.0, buff_iron_timer - delta)
	if buff_arcane_timer > 0.0:
		buff_arcane_timer = maxf(0.0, buff_arcane_timer - delta)
	# Stamina regeneration
	if stamina < MAX_STAMINA:
		var s_regen := (26.0 + float(stats["agi"]) * 2.5) * (2.0 if buff_haste_timer > 0.0 else 1.0)
		stamina = minf(MAX_STAMINA, stamina + s_regen * delta)
	if shield_timer > 0.0:
		shield_timer = max(0.0, shield_timer - delta)
		if shield_timer <= 0.0:
			shield_hp = 0
			hp_mp_changed.emit()
	# Iron Bastion Boon: auto-shield every 12s
	if has_boon("iron_bastion"):
		_bastion_timer -= delta
		if _bastion_timer <= 0.0:
			_bastion_timer = 12.0
			shield_hp = maxi(shield_hp, 40)
			shield_timer = maxf(shield_timer, 6.0)
			hp_mp_changed.emit()
	# Channel Hype decay
	if _hype_decay_delay > 0.0:
		_hype_decay_delay = maxf(0.0, _hype_decay_delay - delta)
	elif hype_score > 0.0:
		hype_score = maxf(0.0, hype_score - 6.5 * delta)
		if hype_score <= 0.0:
			combo_count = 0
		hype_changed.emit(get_hype_rank(), combo_count, hype_score)
	# Passive MP regen
	var max_mp := get_max_mp()
	if mp < max_mp:
		var regen := (2.4 + float(stats["mag"]) * 0.75) * delta
		if current_attribute_id == "star_archmage":
			regen *= 2.0
		elif current_attribute_id in ["occult_student", "zero_regressor", "frost_mage", "pyromancer", "necro_train"]:
			regen *= 1.35
		if has_fable("fable_sss_star"):
			regen *= 1.40
		_mp_accum += regen
		if _mp_accum >= 1.0:
			var add := int(_mp_accum)
			_mp_accum -= float(add)
			mp = min(max_mp, mp + add)
			hp_mp_changed.emit()

var _mp_accum: float = 0.0


func roll_attribute(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var total_weight := 0
	for attr in GameData.ATTRIBUTES.values():
		total_weight += int(attr["weight"])
	var pick := r.randi_range(1, total_weight)
	var acc := 0
	for attr in GameData.ATTRIBUTES.values():
		acc += int(attr["weight"])
		if pick <= acc:
			return attr.duplicate(true)
	return GameData.ATTRIBUTES["office_worker"].duplicate(true)


func start_new_run(attr_id: String) -> void:
	if not GameData.ATTRIBUTES.has(attr_id):
		attr_id = "office_worker"
	current_attribute_id = attr_id
	current_attribute = GameData.ATTRIBUTES[attr_id].duplicate(true)
	stats = current_attribute["stats"].duplicate(true)

	coins = int(current_attribute.get("bonus_coins", 0))
	total_coins_earned = coins
	perfect_dodges = 0
	enemies_defeated = 0
	selected_sponsor_id = ""
	stigma_skill_id = ""
	stigma_cooldown = 0.0
	has_gas_mask = false
	met_main_cast = false
	flag_atk_bonus = 0
	owned_boons = []
	owned_fables = []
	companions = []
	hype_score = 0.0
	combo_count = 0
	_hype_decay_delay = 0.0
	_bastion_timer = 12.0
	parries_landed = 0
	shield_hp = 0
	shield_timer = 0.0

	var w: String = current_attribute.get("weapon", "umbrella")
	owned_weapons = [w]
	equipped_weapon = w

	consumables = {}
	for item_id in current_attribute.get("items", {}).keys():
		consumables[item_id] = int(current_attribute["items"][item_id])
	_refresh_quick_slots()

	var start_skills: Array = current_attribute.get("skills", ["desperate_slash"])
	owned_skills = []
	equipped_skills = ["", "", ""]
	for i in start_skills.size():
		var sid: String = String(start_skills[i])
		if GameData.SKILLS.has(sid):
			owned_skills.append(sid)
			if i < 3:
				equipped_skills[i] = sid
	skill_cooldowns = {}

	hp = get_max_hp()
	mp = get_max_mp()
	stamina = MAX_STAMINA
	item_cooldown = 0.0
	stage_heals_bought = 0
	buff_atk_timer = 0.0
	buff_haste_timer = 0.0
	buff_iron_timer = 0.0
	buff_arcane_timer = 0.0
	_mp_accum = 0.0

	stats_changed.emit()
	coins_changed.emit(coins, 0)
	inventory_changed.emit()
	skills_changed.emit()
	hp_mp_changed.emit()


func _refresh_quick_slots() -> void:
	var avail: Array[String] = []
	for k in consumables.keys():
		if int(consumables[k]) > 0:
			avail.append(k)
	if quick_slots.size() < 2:
		quick_slots = ["", ""]
	for i in 2:
		if quick_slots[i] == "" or int(consumables.get(quick_slots[i], 0)) <= 0:
			for candidate in avail:
				if not (candidate in quick_slots):
					quick_slots[i] = candidate
					break


func get_max_hp() -> int:
	return 80 + int(stats["phy"]) * 20 + (60 if has_boon("iron_bastion") else 0) + (40 if has_fable("fable_pacifist") else 0)


func has_fable(fable_id: String) -> bool:
	return fable_id in owned_fables


func unlock_fable(fable_id: String) -> bool:
	if not GameData.FABLES.has(fable_id) or has_fable(fable_id):
		return false
	owned_fables.append(fable_id)
	var fdata: Dictionary = GameData.FABLES[fable_id]
	if fable_id == "fable_main_cast":
		for k in stats.keys():
			stats[k] = int(stats[k]) + 1
	elif fable_id == "fable_pacifist":
		hp = mini(get_max_hp(), hp + 40)
		mp = mini(get_max_mp(), mp + 30)
	stats_changed.emit()
	hp_mp_changed.emit()
	fable_unlocked.emit(fdata)
	return true


func add_companion(comp_id: String) -> bool:
	if comp_id in companions:
		return false
	companions.append(comp_id)
	unlock_fable("fable_saviour")
	return true


func has_boon(boon_id: String) -> bool:
	return boon_id in owned_boons


func add_boon(boon_id: String) -> void:
	if not GameData.BOONS.has(boon_id) or has_boon(boon_id):
		return
	owned_boons.append(boon_id)
	if boon_id == "iron_bastion":
		hp = mini(get_max_hp(), hp + 60)
		hp_mp_changed.emit()
	stats_changed.emit()


func roll_boon_choices(count: int = 3) -> Array[Dictionary]:
	var pool: Array = []
	for bid in GameData.BOONS.keys():
		if not has_boon(bid):
			pool.append(GameData.BOONS[bid])
	pool.shuffle()
	var out: Array[Dictionary] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	return out


func add_hype(amount: float, add_combo: int = 1) -> void:
	hype_score = clampf(hype_score + amount, 0.0, 100.0)
	combo_count += add_combo
	_hype_decay_delay = 4.8 if has_fable("fable_sss_star") else 3.5
	if get_hype_rank() == "SSS":
		unlock_fable("fable_sss_star")
	hype_changed.emit(get_hype_rank(), combo_count, hype_score)


func on_player_hit_hype_drop() -> void:
	hype_score = maxf(0.0, hype_score - 35.0)
	combo_count = 0
	hype_changed.emit(get_hype_rank(), combo_count, hype_score)


func get_hype_rank() -> String:
	if hype_score >= 90.0:
		return "SSS"
	if hype_score >= 72.0:
		return "S"
	if hype_score >= 52.0:
		return "A"
	if hype_score >= 32.0:
		return "B"
	if hype_score >= 14.0:
		return "C"
	return "D"


func get_hype_damage_mult() -> float:
	match get_hype_rank():
		"SSS": return 1.35
		"S": return 1.25
		"A": return 1.15
		"B": return 1.08
		"C": return 1.04
		_: return 1.0


func get_hype_coin_mult() -> float:
	var m := 1.0
	match get_hype_rank():
		"SSS": m = 1.8
		"S": m = 1.5
		"A": m = 1.3
		"B": m = 1.15
		"C": m = 1.05
	if has_boon("coin_greed"):
		m *= 1.5
	if has_fable("fable_main_cast"):
		m *= 1.2
	return m


func reduce_all_cooldowns(factor: float) -> void:
	for sid in skill_cooldowns.keys():
		skill_cooldowns[sid] = float(skill_cooldowns[sid]) * factor
	stigma_cooldown *= factor


func get_max_mp() -> int:
	return 40 + int(stats["mag"]) * 15 + (30 if has_fable("fable_pacifist") else 0)


func get_weapon_data() -> Dictionary:
	return GameData.WEAPONS.get(equipped_weapon, GameData.WEAPONS["umbrella"])


func get_attack_damage() -> int:
	var wdata := get_weapon_data()
	var is_magic: bool = bool(wdata.get("is_magic", false))
	var scale_stat: int = int(stats["mag"]) if is_magic else int(stats["str"])
	var greed_atk: int = (coins / 200) * 3 if has_boon("coin_greed") else 0
	var fable_atk: int = 8 if has_fable("fable_parry_master") else 0
	var base: int = int(wdata["atk"]) + scale_stat * 3 + flag_atk_bonus + greed_atk + fable_atk
	if current_attribute_id == "kendo_alumni" and not is_magic:
		base = int(round(float(base) * 1.2))
	if current_attribute_id == "berserker":
		var missing_ratio := 1.0 - (float(hp) / float(maxi(1, get_max_hp())))
		base = int(round(float(base) * (1.0 + missing_ratio * 0.80)))
	if current_attribute_id == "tempest_blademaster" and randf() < 0.35:
		base = int(round(float(base) * 1.65))
	elif current_attribute_id in ["underground_boxer", "zero_regressor", "club_archer"] and randf() < 0.25:
		base = int(round(float(base) * 1.6))
	var mult := get_hype_damage_mult() * (1.35 if has_boon("glass_cannon") else 1.0) * (1.15 if has_fable("fable_giant_slayer") else 1.0) * (1.40 if buff_atk_timer > 0.0 else 1.0)
	return int(round(float(base) * mult))


func use_stamina(cost: float) -> bool:
	if stamina < cost:
		return false
	stamina = maxf(0.0, stamina - cost)
	return true


func equip_skill_to_slot(skill_id: String, slot_idx: int) -> void:
	if not (skill_id in owned_skills) or slot_idx < 0 or slot_idx >= 3:
		return
	for i in 3:
		if equipped_skills[i] == skill_id:
			equipped_skills[i] = ""
	equipped_skills[slot_idx] = skill_id
	skills_changed.emit()


func get_char_sprite_path() -> String:
	var idx := clampi(selected_char_index, 0, GameData.CHARACTERS.size() - 1)
	return String(GameData.CHARACTERS[idx]["sprite"])


func get_parry_window() -> float:
	return 0.38 if current_attribute_id == "shield_guardian" else 0.24


func get_skill_damage(skill_id: String) -> int:
	var s: Dictionary = GameData.SKILLS.get(skill_id, {})
	var mult := float(s.get("power_mult", 1.5))
	var is_magic: bool = bool(s.get("is_magic", false))
	var base := float(get_attack_damage()) * mult + float(stats["mag"]) * (6.0 if is_magic else 3.5)
	if is_magic and current_attribute_id == "thunder_caster":
		base *= 1.2
	if is_magic and buff_arcane_timer > 0.0:
		base *= 1.45
	return int(round(base))


func get_move_speed() -> float:
	var spd := 118.0 + float(stats["agi"]) * 7.5
	if buff_haste_timer > 0.0:
		spd *= 1.45
	return spd


func get_dash_cooldown() -> float:
	var cd := maxf(0.35, 0.72 - float(stats["agi"]) * 0.04)
	if current_attribute_id == "morning_runner":
		cd *= 0.75
	return cd


func get_upgrade_cost(stat_name: String) -> int:
	if not stats.has(stat_name):
		return 999999
	return 100 * int(stats[stat_name])


func upgrade_stat(stat_name: String) -> bool:
	if not stats.has(stat_name):
		return false
	var cost := get_upgrade_cost(stat_name)
	if not spend_coins(cost):
		return false
	var old_max_hp := get_max_hp()
	var old_max_mp := get_max_mp()
	stats[stat_name] = int(stats[stat_name]) + 1
	var hp_gain := get_max_hp() - old_max_hp
	var mp_gain := get_max_mp() - old_max_mp
	if hp_gain > 0:
		hp = min(get_max_hp(), hp + hp_gain)
	if mp_gain > 0:
		mp = min(get_max_mp(), mp + mp_gain)
	stats_changed.emit()
	hp_mp_changed.emit()
	return true


func add_coins(amount: int, _reason: String = "") -> void:
	if amount <= 0:
		return
	coins += amount
	total_coins_earned += amount
	coins_changed.emit(coins, amount)


func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins, -amount)
	return true


func add_weapon(weapon_id: String, auto_equip: bool = false) -> void:
	if not GameData.WEAPONS.has(weapon_id):
		return
	if not (weapon_id in owned_weapons):
		owned_weapons.append(weapon_id)
	if auto_equip:
		equipped_weapon = weapon_id
	inventory_changed.emit()
	stats_changed.emit()


func equip_weapon(weapon_id: String) -> bool:
	if not (weapon_id in owned_weapons):
		return false
	equipped_weapon = weapon_id
	inventory_changed.emit()
	stats_changed.emit()
	return true


func add_consumable(item_id: String, count: int = 1) -> void:
	if not GameData.CONSUMABLES.has(item_id):
		return
	consumables[item_id] = int(consumables.get(item_id, 0)) + count
	_refresh_quick_slots()
	inventory_changed.emit()


func buy_item(item_id: String) -> bool:
	if item_id == "gas_mask":
		if has_gas_mask:
			return false
		if not spend_coins(120):
			return false
		has_gas_mask = true
		inventory_changed.emit()
		return true
	if GameData.WEAPONS.has(item_id):
		if item_id in owned_weapons:
			return false
		var price := int(GameData.WEAPONS[item_id]["price"])
		if not spend_coins(price):
			return false
		add_weapon(item_id, true)
		return true
	if GameData.CONSUMABLES.has(item_id):
		var cdata: Dictionary = GameData.CONSUMABLES[item_id]
		if cdata["kind"] == "heal_hp" and stage_heals_bought >= MAX_HEALS_PER_STAGE:
			return false
		var price := int(cdata["price"])
		if not spend_coins(price):
			return false
		if cdata["kind"] == "heal_hp":
			stage_heals_bought += 1
		add_consumable(item_id, 1)
		return true
	return false


func buy_skill(skill_id: String) -> bool:
	if not GameData.SKILLS.has(skill_id) or (skill_id in owned_skills):
		return false
	var price := int(GameData.SKILLS[skill_id]["price"])
	if not spend_coins(price):
		return false
	owned_skills.append(skill_id)
	for i in equipped_skills.size():
		if equipped_skills[i] == "":
			equipped_skills[i] = skill_id
			break
	skills_changed.emit()
	return true


func can_use_skill(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= equipped_skills.size():
		return false
	var sid := equipped_skills[slot_idx]
	if sid == "" or not GameData.SKILLS.has(sid):
		return false
	var cd := float(skill_cooldowns.get(sid, 0.0))
	var mp_cost := int(GameData.SKILLS[sid]["mp_cost"])
	return cd <= 0.0 and mp >= mp_cost


func consume_skill(slot_idx: int) -> Dictionary:
	if not can_use_skill(slot_idx):
		return {}
	var sid := equipped_skills[slot_idx]
	var data: Dictionary = GameData.SKILLS[sid]
	mp -= int(data["mp_cost"])
	skill_cooldowns[sid] = float(data["cooldown"])
	if sid == "magic_barrier":
		shield_hp = 50 + int(stats["mag"]) * 9
		shield_timer = 5.5
	if current_attribute_id == "starlight_priest":
		hp = mini(get_max_hp(), hp + 12)
	hp_mp_changed.emit()
	return data


func can_use_stigma() -> bool:
	if stigma_skill_id == "" or not GameData.STIGMA_SKILLS.has(stigma_skill_id):
		return false
	if stigma_cooldown > 0.0:
		return false
	var mp_cost: int = int(GameData.STIGMA_SKILLS[stigma_skill_id]["mp_cost"])
	return mp >= mp_cost


func consume_stigma() -> Dictionary:
	if not can_use_stigma():
		return {}
	var data: Dictionary = GameData.STIGMA_SKILLS[stigma_skill_id]
	mp -= int(data["mp_cost"])
	stigma_cooldown = float(data["cooldown"])
	if stigma_skill_id == "stigma_flame":
		hp = mini(get_max_hp(), hp + 25)
	elif stigma_skill_id == "stigma_will":
		mp = mini(get_max_mp(), mp + 30)
		shield_hp = 55 + int(stats["phy"]) * 8
		shield_timer = 5.0
	hp_mp_changed.emit()
	return data


func get_stigma_damage() -> int:
	if stigma_skill_id == "" or not GameData.STIGMA_SKILLS.has(stigma_skill_id):
		return 30
	var mult := float(GameData.STIGMA_SKILLS[stigma_skill_id]["power_mult"])
	var base := float(get_attack_damage()) * mult + float(stats["mag"]) * 6.0 + float(stats["str"]) * 3.0
	return int(round(base))


func use_consumable(slot_idx: int) -> Dictionary:
	if item_cooldown > 0.0:
		return {}
	if slot_idx < 0 or slot_idx >= quick_slots.size():
		return {}
	var item_id := quick_slots[slot_idx]
	if item_id == "" or int(consumables.get(item_id, 0)) <= 0:
		return {}
	var data: Dictionary = GameData.CONSUMABLES[item_id]
	consumables[item_id] = int(consumables[item_id]) - 1
	item_cooldown = 6.0
	var kind: String = data["kind"]
	var power: int = int(data["power"])
	if kind == "heal_hp":
		if current_attribute_id == "field_medic":
			power = int(round(float(power) * 1.4))
		hp = min(get_max_hp(), hp + power)
	elif kind == "heal_mp":
		mp = min(get_max_mp(), mp + power)
	_refresh_quick_slots()
	inventory_changed.emit()
	hp_mp_changed.emit()
	return data


func apply_damage(raw_damage: int) -> int:
	var dmg_val: float = float(raw_damage)
	if current_attribute_id == "station_guard":
		dmg_val *= 0.85
	elif current_attribute_id == "shield_guardian":
		dmg_val *= 0.80
	if has_boon("glass_cannon"):
		dmg_val *= 1.15
	if has_fable("fable_saviour"):
		dmg_val *= 0.90
	if buff_iron_timer > 0.0:
		dmg_val *= 0.50
	var reduced: int = maxi(1, int(round(dmg_val)) - int(stats["phy"]) / 2)
	if shield_hp > 0:
		var absorbed: int = mini(shield_hp, reduced)
		shield_hp -= absorbed
		reduced -= absorbed
	hp = maxi(0, hp - reduced)
	hp_mp_changed.emit()
	return reduced


const SAVE_PATH: String = "user://star_stream_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(stage_num: int) -> bool:
	var payload := {
		"version": 1,
		"stage": clampi(stage_num, 1, 4),
		"player_name": player_name,
		"selected_char_index": selected_char_index,
		"current_attribute_id": current_attribute_id,
		"stats": stats.duplicate(),
		"coins": coins,
		"hp": maxi(1, hp),
		"mp": mp,
		"owned_weapons": Array(owned_weapons),
		"equipped_weapon": equipped_weapon,
		"consumables": consumables.duplicate(),
		"quick_slots": Array(quick_slots),
		"owned_skills": Array(owned_skills),
		"equipped_skills": Array(equipped_skills),
		"selected_sponsor_id": selected_sponsor_id,
		"stigma_skill_id": stigma_skill_id,
		"has_gas_mask": has_gas_mask,
		"met_main_cast": met_main_cast,
		"flag_atk_bonus": flag_atk_bonus,
		"owned_boons": Array(owned_boons),
		"owned_fables": Array(owned_fables),
		"companions": Array(companions),
		"total_coins_earned": total_coins_earned,
		"enemies_defeated": enemies_defeated,
		"parries_landed": parries_landed,
		"perfect_dodges": perfect_dodges,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	return true


func get_save_summary() -> Dictionary:
	if not has_save():
		return {}
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {}
	return parsed


func load_game() -> int:
	var data := get_save_summary()
	if data.is_empty():
		return 0
	var attr_id := String(data.get("current_attribute_id", "office_worker"))
	start_new_run(attr_id)
	player_name = String(data.get("player_name", player_name))
	selected_char_index = clampi(int(data.get("selected_char_index", 0)), 0, GameData.CHARACTERS.size() - 1)
	var st: Variant = data.get("stats", {})
	if st is Dictionary:
		for k in ["str", "phy", "agi", "mag"]:
			if st.has(k):
				stats[k] = int(st[k])
	coins = int(data.get("coins", 0))
	hp = clampi(int(data.get("hp", get_max_hp())), 1, get_max_hp())
	mp = clampi(int(data.get("mp", get_max_mp())), 0, get_max_mp())
	owned_weapons.clear()
	for w in data.get("owned_weapons", []):
		if GameData.WEAPONS.has(String(w)):
			owned_weapons.append(String(w))
	if owned_weapons.is_empty():
		owned_weapons.append("umbrella")
	equipped_weapon = String(data.get("equipped_weapon", owned_weapons[0]))
	if not GameData.WEAPONS.has(equipped_weapon):
		equipped_weapon = owned_weapons[0]
	consumables.clear()
	var cons: Variant = data.get("consumables", {})
	if cons is Dictionary:
		for k in cons.keys():
			consumables[String(k)] = int(cons[k])
	quick_slots.clear()
	for q in data.get("quick_slots", ["potion_small", "mana_stone"]):
		quick_slots.append(String(q))
	owned_skills.clear()
	for s in data.get("owned_skills", []):
		if GameData.SKILLS.has(String(s)):
			owned_skills.append(String(s))
	equipped_skills.clear()
	for es in data.get("equipped_skills", ["", "", ""]):
		equipped_skills.append(String(es))
	while equipped_skills.size() < 3:
		equipped_skills.append("")
	selected_sponsor_id = String(data.get("selected_sponsor_id", ""))
	stigma_skill_id = String(data.get("stigma_skill_id", ""))
	has_gas_mask = bool(data.get("has_gas_mask", false))
	met_main_cast = bool(data.get("met_main_cast", false))
	flag_atk_bonus = int(data.get("flag_atk_bonus", 0))
	owned_boons.clear()
	for b in data.get("owned_boons", []):
		owned_boons.append(String(b))
	owned_fables.clear()
	for fb in data.get("owned_fables", []):
		owned_fables.append(String(fb))
	companions.clear()
	for cp in data.get("companions", []):
		companions.append(String(cp))
	total_coins_earned = int(data.get("total_coins_earned", 0))
	enemies_defeated = int(data.get("enemies_defeated", 0))
	parries_landed = int(data.get("parries_landed", 0))
	perfect_dodges = int(data.get("perfect_dodges", 0))
	stats_changed.emit()
	hp_mp_changed.emit()
	inventory_changed.emit()
	skills_changed.emit()
	coins_changed.emit(coins, 0)
	return clampi(int(data.get("stage", 1)), 1, 4)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
