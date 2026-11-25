extends SceneTree

var _passed := 0
var _failed := 0


func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", msg)


func _assert_eq(a, b, msg: String) -> void:
	if a == b:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: %s (got=%s, expected=%s)" % [msg, str(a), str(b)])


func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	var sm = root.get_node_or_null("ScenarioManager")
	var vfx = root.get_node_or_null("VfxManager")

	_assert_true(gs != null, "GameState autoload exists")
	_assert_true(sm != null, "ScenarioManager autoload exists")
	_assert_true(vfx != null, "VfxManager autoload exists")

	if gs == null or sm == null:
		quit(1)
		return

	# 1. VFX checks (all 20 pixelfx sheets)
	for k in ["slash", "wind_slash", "hit_spark", "dash_puff", "mana_burst", "shield_aura", "fire_bomb", "coin_sparkle", "level_up", "fireball", "lightning", "frost_nova", "dark_orb", "ground_slam", "parry", "impact_frame", "dagger_flurry", "heavy_cleave", "spin_slash", "scythe_reap"]:
		_assert_true(vfx.has_vfx(k), "VfxManager loaded '%s'" % k)

	# 1a. Verify 24 distinct classes exist
	const GameData = preload("res://scripts/data/GameData.gd")
	_assert_eq(GameData.ATTRIBUTES.size(), 24, "24 distinct classes/attributes available")
	gs.start_new_run("shield_guardian")
	_assert_true(gs.get_parry_window() > 0.30, "Shield guardian has wider parry window")
	gs.start_new_run("berserker")
	var full_atk: int = gs.get_attack_damage()
	gs.hp = 10
	var low_atk: int = gs.get_attack_damage()
	_assert_true(low_atk > full_atk, "Berserker deals more damage at low HP")
	gs.start_new_run("star_archmage")
	_assert_eq(gs.equipped_weapon, "starlight_staff", "Star Archmage starts with starlight_staff")

	# 1b. Magic class starting skills & weapon check
	gs.start_new_run("frost_mage")
	_assert_eq(gs.equipped_weapon, "frost_staff", "Frost mage starts with frost_staff")
	_assert_true("frost_nova" in gs.equipped_skills, "Frost mage starts with frost_nova skill")
	gs.start_new_run("occult_student")
	_assert_true("fireball" in gs.equipped_skills, "Occult student starts with fireball skill")
	gs.start_new_run("zero_regressor")
	_assert_eq(gs.equipped_skills.size(), 3, "Zero regressor has 3 skill slots")
	_assert_true("lightning_bolt" in gs.equipped_skills, "Zero regressor starts with lightning_bolt")

	# 2. Personal Attribute randomizer
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen_ids := {}
	for i in 40:
		var attr: Dictionary = gs.roll_attribute(rng)
		_assert_true(attr.has("id") and attr.has("name") and attr.has("rarity"), "Rolled attribute has required fields")
		seen_ids[attr["id"]] = true
	_assert_true(seen_ids.size() >= 3, "Weighted roll produces multiple attributes")

	# 3. Start run & stat upgrade coin formula
	gs.start_new_run("office_worker")
	_assert_eq(gs.coins, 50, "Office worker starts with 50 bonus coins")
	_assert_eq(gs.get_upgrade_cost("str"), 100, "Lv.1 STR upgrade costs 100 coins")
	_assert_true(not gs.upgrade_stat("str"), "Cannot upgrade STR with only 50 coins")
	_assert_eq(gs.coins, 50, "Coins unchanged on failed upgrade")
	_assert_eq(gs.stats["str"], 1, "STR unchanged on failed upgrade")

	gs.add_coins(350, "test")
	_assert_eq(gs.coins, 400, "Coins added properly")
	var prev_hp: int = gs.get_max_hp()
	_assert_true(gs.upgrade_stat("phy"), "Upgrade PHY succeeds with enough coins")
	_assert_eq(gs.get_max_hp(), prev_hp + 20, "PHY upgrade increases MaxHP by 20")

	_assert_true(gs.upgrade_stat("str"), "Upgrade STR Lv.1->2 succeeds (100 coins)")
	_assert_eq(gs.get_upgrade_cost("str"), 200, "Lv.2 STR upgrade costs 200 coins")

	# 4. Dokkaebi Bag purchase (item & skill)
	gs.add_coins(500, "test")
	_assert_true(gs.buy_skill("wind_slash"), "Can buy wind_slash skill")
	_assert_true("wind_slash" in gs.equipped_skills, "Bought skill auto-equips into open slot")
	_assert_true(gs.buy_item("steel_dagger"), "Can buy steel_dagger weapon")
	_assert_eq(gs.equipped_weapon, "steel_dagger", "Bought stronger weapon equips cleanly")

	# 5. Scenario #1: Perfect Dodge cooldown & dual-path non-double-clear
	var cleared_count := [0]
	var on_clear := func(_path: String): cleared_count[0] += 1
	sm.scenario_cleared.connect(on_clear)

	sm.start_scenario_1()
	_assert_true(sm.is_active, "Scenario 1 is active after start")
	_assert_eq(int(sm.time_remaining), 180, "Scenario 1 starts with 180s timer")

	var coins_before_dodge: int = gs.coins
	sm.trigger_perfect_dodge()
	_assert_true(gs.coins > coins_before_dodge, "Perfect dodge awards sponsor coins")
	var coins_after_first: int = gs.coins
	sm.trigger_perfect_dodge()
	_assert_eq(gs.coins, coins_after_first, "Immediate second perfect dodge respects cooldown")

	# Clear via Hidden Scenario (bug box) then ensure enemy kill does not double-clear
	sm.complete_hidden_bug_box()
	_assert_eq(cleared_count[0], 1, "Hidden bug box clears Scenario 1 once")
	_assert_true(sm.condition_met, "Scenario condition_met is true after bug box")
	_assert_true(sm.is_active, "Timer stays active so player can choose farm or exit")
	sm.register_enemy_killed("frenzy", true)
	_assert_eq(cleared_count[0], 1, "Subsequent enemy kill does NOT double-clear Scenario 1")

	# 6. Sponsor selection grants Stigma skill + No-Sponsor coins
	var coins_before_sponsor: int = gs.coins
	sm.select_sponsor("none")
	_assert_eq(gs.coins, coins_before_sponsor + 300, "Rejecting sponsor awards +300 coins")
	_assert_eq(gs.stigma_skill_id, "stigma_will", "Selecting sponsor grants its Stigma skill")
	_assert_true(gs.can_use_stigma(), "Unlocked Stigma skill is usable")
	var used_stigma: Dictionary = gs.consume_stigma()
	_assert_eq(used_stigma.get("id", ""), "stigma_will", "consume_stigma returns stigma data")

	# 6b. Secret Main Cast ending when exiting with time_remaining >= 170s (02:50)
	_assert_true(sm.can_trigger_main_cast_secret(), "Secret main cast available when remaining >= 02:50")
	var coins_before_exit: int = gs.coins
	sm.exit_train_now()
	_assert_eq(sm.ending_type, "secret_main_cast", "Exiting with >= 02:50 triggers secret_main_cast")
	_assert_eq(gs.coins, coins_before_exit + 500, "Secret main cast awards +500 bonus coins")
	_assert_true(not sm.is_active and sm.is_cleared, "Exiting train stops timer and marks cleared")

	# 6c. Farm mode -> waiting until timeout safely finishes (does NOT fail)
	sm.start_scenario_1()
	sm.register_enemy_killed("frenzy", true)
	sm.register_enemy_killed("frenzy", true)
	sm.register_enemy_killed("frenzy", true)
	sm.choose_stay_and_farm()
	_assert_true(sm.is_farming, "Farm mode active after choosing stay_and_farm")
	sm.tick(181.0)
	_assert_eq(sm.ending_type, "waited_timeout", "Timeout after condition_met finishes with waited_timeout")

	# 6d. Stage 2 (Dongho Bridge), Stage 3 (Green Zone), Stage 4 (Capture the Flag)
	sm.start_scenario(2)
	_assert_eq(sm.current_stage, 2, "Stage 2 started")
	sm.complete_stage2_gas_mask()
	_assert_true(gs.has_gas_mask, "Gas mask acquired in Stage 2")
	sm.register_enemy_killed("boss_bridge", false)
	_assert_true(sm.stage2_boss_dead, "Stage 2 boss defeat tracked")
	sm.complete_stage2_reach_station()
	_assert_eq(sm.ending_type, "stage2_clear", "Stage 2 clears at Oksu station gate")

	sm.start_scenario(3)
	_assert_eq(sm.current_stage, 3, "Stage 3 started")
	sm.set_stage3_wave(1)
	_assert_true(sm.stage3_zone_claimed and sm.stage3_wave == 1, "Stage 3 Green Zone wave 1 active")
	sm.complete_stage3_defense()
	_assert_eq(sm.ending_type, "stage3_clear", "Stage 3 clears after 3 waves")

	sm.start_scenario(4)
	_assert_eq(sm.current_stage, 4, "Stage 4 started")
	sm.register_stage4_flag_captured()
	sm.register_stage4_flag_captured()
	_assert_eq(sm.stage4_flags_captured, 2, "Both flags captured in Stage 4")
	_assert_eq(gs.flag_atk_bonus, 12, "2 captured flags grant +12 ATK bonus")
	sm.register_enemy_killed("boss_king", false)
	_assert_eq(sm.ending_type, "stage4_clear", "Defeating King Boss with 2 flags clears Stage 4")
	_assert_eq(GameData.MAX_CHAPTER, 20, "Campaign has 20 Seoul-Arc chapters")
	_assert_eq(GameData.CHAPTERS.size(), 16, "Chapters 5..20 data present")
	sm.start_scenario(20)
	sm.register_stage4_flag_captured()
	sm.register_stage4_flag_captured()
	for _k in 14:
		sm.register_enemy_killed("frenzy", false)
	sm.register_enemy_killed("boss_king", false)
	_assert_eq(sm.ending_type, "campaign_victory", "Clearing Chapter 20 finishes the 20-chapter Seoul campaign")

	# 6e. Channel Hype Rank, Star Stream Boons, and Sudden Dokkaebi Events
	gs.start_new_run("office_worker")
	_assert_eq(gs.get_hype_rank(), "D", "Initial Hype rank is D")
	gs.add_hype(95.0, 10)
	_assert_eq(gs.get_hype_rank(), "SSS", "95 hype reaches SSS rank")
	gs.on_player_hit_hype_drop()
	_assert_true(gs.hype_score < 70.0 and gs.combo_count == 0, "Taking hit drops hype and resets combo")

	var boon_choices: Array = gs.roll_boon_choices(3)
	_assert_eq(boon_choices.size(), 3, "roll_boon_choices returns 3 distinct boons")
	var hp_pre_boon: int = gs.get_max_hp()
	gs.add_boon("iron_bastion")
	_assert_eq(gs.get_max_hp(), hp_pre_boon + 60, "iron_bastion boon increases MaxHP by 60")

	sm.start_scenario(2)
	sm.start_sudden_event("untouchable")
	_assert_true(sm.sudden_event_active and sm.sudden_event_kind == "untouchable", "Sudden untouchable event starts")
	var coins_before_ev: int = gs.coins
	sm.tick(16.0)
	_assert_true(not sm.sudden_event_active and gs.coins >= coins_before_ev + 180, "Surviving untouchable event awards +180 coins")

	# 6f. Fables, Companions, and Class Outfits checks
	gs.start_new_run("star_archmage")
	_assert_eq(GameData.CLASS_OUTFITS.size(), 24, "All 24 classes have unique outfit palettes")
	_assert_true(gs.add_companion("yuna"), "Adding companion yuna succeeds")
	_assert_true(gs.has_fable("fable_saviour"), "Adding companion unlocks fable_saviour")
	_assert_true(gs.unlock_fable("fable_parry_master"), "Unlocking fable_parry_master succeeds")

	# 6g. 20 Playable Characters, 27 Skills, Stamina, Heal Cap, and Item Cooldown checks
	_assert_eq(GameData.CHARACTERS.size(), 20, "20 playable characters available (male/female/kid/elder)")
	_assert_eq(GameData.SKILLS.size(), 27, "27 total skills available (+20 new damage/CC/buff/debuff)")
	gs.start_new_run("office_worker")
	gs.add_coins(1000, "test")
	_assert_true(gs.use_stamina(28.0), "Dash consumes 28 stamina")
	_assert_true(gs.stamina < 80.0, "Stamina decreased after dash")
	_assert_true(gs.buy_item("potion_small"), "Heal buy 1/3 succeeds")
	_assert_true(gs.buy_item("potion_small"), "Heal buy 2/3 succeeds")
	_assert_true(gs.buy_item("potion_small"), "Heal buy 3/3 succeeds")
	_assert_true(not gs.buy_item("potion_small"), "4th heal buy in same stage blocked by hardcore cap")
	var used_p: Dictionary = gs.use_consumable(0)
	_assert_true(not used_p.is_empty(), "1st quick item use succeeds")
	var used_p2: Dictionary = gs.use_consumable(0)
	_assert_true(used_p2.is_empty(), "Immediate 2nd quick item blocked by 6s cooldown")

	# 7. Full Main.tscn + SubwayStage + Modals pause integration test
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	_assert_true(main_scene != null, "Main.tscn loads cleanly")
	if main_scene != null:
		_main_inst = main_scene.instantiate()
		root.add_child(_main_inst)
	else:
		_finish()


var _main_inst: Node = null
var _ran_scene_tests: bool = false


func _process(_delta: float) -> bool:
	if _ran_scene_tests or _main_inst == null:
		return false
	_ran_scene_tests = true
	var gs = root.get_node("GameState")
	var sfx = root.get_node("SfxManager")
	_assert_eq(sfx._bgm_streams.size(), 3, "All 3 looping Chiptune BGM tracks loaded")
	_main_inst._start_run_with_attribute("apocalypse_reader")
	_assert_true(_main_inst._stage != null, "SubwayStage instantiated")
	_assert_true(_main_inst._stage.player != null, "Player spawned in SubwayStage")
	_assert_true(paused, "Opening Scenario #1 intro modal pauses gameplay")
	_main_inst._modals.close_modal()
	_assert_true(not paused, "Closing intro modal unpauses gameplay")
	_main_inst._modals.toggle_attribute_window()
	_assert_true(paused, "Opening Attribute Window pauses gameplay")
	_main_inst._modals.close_modal()
	_assert_true(not paused, "Closing Attribute Window unpauses gameplay")
	_main_inst._modals.toggle_shop_window()
	_assert_true(paused, "Opening Dokkaebi Bag pauses gameplay")
	_main_inst._modals.close_modal()
	_assert_true(not paused, "Closing Dokkaebi Bag unpauses gameplay")

	# Player dash i-frame check
	var p = _main_inst._stage.player
	var hp_before: int = gs.hp
	p._start_dash(1)
	_assert_true(p.is_dashing(), "Player enters dash state")
	p.take_damage(25, -100.0)
	_assert_eq(gs.hp, hp_before, "Player takes 0 damage during dash i-frames")

	# Player Parry check
	p._dash_timer = 0.0
	p._iframe_timer = 0.0
	p._start_parry()
	_assert_true(p.is_parrying(), "Player enters parry state")
	var parries_before: int = gs.parries_landed
	p.take_damage(40, -120.0)
	_assert_eq(gs.hp, hp_before, "Parry prevents all damage")
	_assert_eq(gs.parries_landed, parries_before + 1, "Successful parry increments parries_landed")

	# Verify Stages 2, 3, and 4 instantiate cleanly inside Main.tscn
	for s_num in [2, 3, 4]:
		_main_inst._start_stage(s_num)
		_assert_eq(_main_inst._stage.stage_num, s_num, "Stage %d instantiated cleanly" % s_num)
		_main_inst._modals.close_modal()

	_main_inst.queue_free()
	_finish()
	return true


func _finish() -> void:
	print("TEST SUMMARY: passed=%d failed=%d" % [_passed, _failed])
	if _failed == 0:
		print("ALL CORE TESTS PASSED")
		quit(0)
	else:
		quit(1)
