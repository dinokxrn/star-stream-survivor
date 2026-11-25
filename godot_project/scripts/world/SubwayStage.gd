extends Node2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const UiTheme = preload("res://scripts/ui/UiTheme.gd")
const PlayerScript = preload("res://scripts/entities/Player.gd")
const RemotePlayerScript = preload("res://scripts/entities/RemotePlayer.gd")
const EnemyScript = preload("res://scripts/entities/Enemy.gd")
const CompanionScript = preload("res://scripts/entities/Companion.gd")
const InteractableScript = preload("res://scripts/world/Interactable.gd")

signal request_bug_box_choice
signal intro_finished
signal player_died_signal
signal hazard_status_changed(warning_text: String)

const CAR_WIDTH: int = 540
const NUM_CARS: int = 3
const STAGE_WIDTH: int = CAR_WIDTH * NUM_CARS # 1620 px
const FLOOR_Y: float = 212.0

var stage_num: int = 1
var player: CharacterBody2D
var camera: Camera2D
var _dokkaebi: Sprite2D = null
var _dokkaebi_time: float = 0.0
var _shake_strength: float = 0.0
var _shake_timer: float = 0.0
var _flicker_overlay: ColorRect
var _car2_guards_alive: int = 3
var _farm_spawn_timer: float = 9.0
var _sudden_event_cd: float = 26.0

# Stage 2 Toxic Fog
const FOG_MIN_X: float = 460.0
const FOG_MAX_X: float = 1120.0
var _hazard_tick: float = 0.0

# Stage 3 Green Zone
const GREEN_ZONE_X: float = 760.0
const GREEN_ZONE_RADIUS: float = 155.0
var _green_zone_rect: ColorRect = null
var _stage3_wave_alive: int = 0
var _stage3_next_wave_delay: float = 0.0

# Online Co-op sync state
var _remote_players: Dictionary = {}
var _next_enemy_seq: int = 0
var _net_player_tick: float = 0.0
var _net_enemy_tick: float = 0.0

# Probability Storm Penalty (exceeding scenario level cap)
var _prob_drain_tick: float = 0.0
var _prob_bind_cd: float = 4.0
var _prob_bind_timer: float = 0.0
var _prob_warned: bool = false


func build_stage(p_stage_num: int = 1) -> void:
	stage_num = clampi(p_stage_num, 1, 4)

	# 1. Stage-specific pixel-art background
	var bg_map := {
		1: "res://assets/sprites/subway_bg.png",
		2: "res://assets/sprites/stage2_bridge.png",
		3: "res://assets/sprites/stage3_station.png",
		4: "res://assets/sprites/stage4_throne.png",
	}
	var bg_tex := SpriteLoader.load_tex(String(bg_map[stage_num]))
	for i in NUM_CARS:
		var sp := Sprite2D.new()
		sp.texture = bg_tex
		sp.centered = false
		sp.position = Vector2(i * CAR_WIDTH, 0)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index = -10
		add_child(sp)

		if stage_num == 1:
			var lbl := Label.new()
			lbl.text = "ตู้ %d / 3707" % (i + 1)
			lbl.position = Vector2(i * CAR_WIDTH + 225, 48)
			lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.55, 0.8, 0.95, 0.85))
			lbl.z_index = -5
			add_child(lbl)

	_flicker_overlay = ColorRect.new()
	_flicker_overlay.size = Vector2(STAGE_WIDTH, 270)
	_flicker_overlay.color = Color(0.02, 0.05, 0.12, 0.05)
	_flicker_overlay.z_index = 20
	add_child(_flicker_overlay)

	# 2. Floor, walls, and jumpable platforms
	_add_solid_rect(Vector2(STAGE_WIDTH * 0.5, FLOOR_Y + 28), Vector2(STAGE_WIDTH + 40, 56))
	_add_solid_rect(Vector2(-12, 135), Vector2(24, 270))
	_add_solid_rect(Vector2(STAGE_WIDTH + 12, 135), Vector2(24, 270))

	var props_tex := SpriteLoader.load_tex("res://assets/sprites/props.png")
	for ox in [210, 460, 740, 1020, 1290]:
		_add_oneway_luggage(Vector2(ox, FLOOR_Y - 16), props_tex)

	# 3. Player + Camera
	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.position = Vector2(88, FLOOR_Y)
	add_child(player)
	player.player_died.connect(func(): player_died_signal.emit())
	player.request_shake.connect(trigger_screen_shake)
	player.hit_enemy.connect(_on_local_player_hit_enemy)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.45, 1.45)
	camera.limit_left = 0
	camera.limit_right = STAGE_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = 260
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	player.add_child(camera)

	# 4. Build specific scenario encounters & spawn unlocked Companions
	match stage_num:
		1:
			_build_stage_1()
			SfxManager.play_bgm("bgm_subway")
		2:
			_build_stage_2()
			SfxManager.play_bgm("bgm_battle")
		3:
			_build_stage_3()
			SfxManager.play_bgm("bgm_battle")
		4:
			_build_stage_4()
			SfxManager.play_bgm("bgm_boss")

	for cid in GameState.companions:
		_spawn_companion(cid, player.global_position + Vector2(-26.0, 0))

	_setup_coop_network()
	intro_finished.emit()


func _exit_tree() -> void:
	if NetworkManager.room_updated.is_connected(_on_net_room_updated):
		NetworkManager.room_updated.disconnect(_on_net_room_updated)
	if NetworkManager.peer_state_received.is_connected(_on_net_peer_state):
		NetworkManager.peer_state_received.disconnect(_on_net_peer_state)
	if NetworkManager.peer_fx_received.is_connected(_on_net_peer_fx):
		NetworkManager.peer_fx_received.disconnect(_on_net_peer_fx)
	if NetworkManager.enemy_hit_received.is_connected(_on_net_enemy_hit):
		NetworkManager.enemy_hit_received.disconnect(_on_net_enemy_hit)
	if NetworkManager.enemy_sync_received.is_connected(_on_net_enemy_sync):
		NetworkManager.enemy_sync_received.disconnect(_on_net_enemy_sync)
	if NetworkManager.player_hit_received.is_connected(_on_net_player_hit):
		NetworkManager.player_hit_received.disconnect(_on_net_player_hit)
	if NetworkManager.scenario_sync_received.is_connected(_on_net_scenario_sync):
		NetworkManager.scenario_sync_received.disconnect(_on_net_scenario_sync)
	if NetworkManager.revive_received.is_connected(_on_net_revive):
		NetworkManager.revive_received.disconnect(_on_net_revive)
	if NetworkManager.toast_received.is_connected(_on_net_toast):
		NetworkManager.toast_received.disconnect(_on_net_toast)


func _setup_coop_network() -> void:
	if not NetworkManager.room_updated.is_connected(_on_net_room_updated):
		NetworkManager.room_updated.connect(_on_net_room_updated)
		NetworkManager.peer_state_received.connect(_on_net_peer_state)
		NetworkManager.peer_fx_received.connect(_on_net_peer_fx)
		NetworkManager.enemy_hit_received.connect(_on_net_enemy_hit)
		NetworkManager.enemy_sync_received.connect(_on_net_enemy_sync)
		NetworkManager.player_hit_received.connect(_on_net_player_hit)
		NetworkManager.scenario_sync_received.connect(_on_net_scenario_sync)
		NetworkManager.revive_received.connect(_on_net_revive)
		NetworkManager.toast_received.connect(_on_net_toast)
	if NetworkManager.is_online:
		_sync_remote_roster(NetworkManager.room_players)
		if NetworkManager.is_host:
			_broadcast_host_enemies()


func _on_local_player_hit_enemy(enemy: Node, _dmg: int) -> void:
	if NetworkManager.is_online and enemy != null and is_instance_valid(enemy) and player != null:
		NetworkManager.send_player_fx("hit_spark", enemy.global_position + Vector2(0, -14), player.facing, 0.42)


func _sync_remote_roster(players: Array) -> void:
	var seen: Dictionary = {}
	for p in players:
		if not (p is Dictionary):
			continue
		var pid := String(p.get("peer_id", ""))
		if pid == "" or pid == NetworkManager.my_peer_id:
			continue
		seen[pid] = true
		if not _remote_players.has(pid) or not is_instance_valid(_remote_players[pid]):
			var rp := Node2D.new()
			rp.set_script(RemotePlayerScript)
			add_child(rp)
			rp.setup(
				pid,
				String(p.get("name", pid)),
				int(p.get("char_idx", 0)),
				String(p.get("attr_id", "office_worker")),
				Vector2(108.0 + float(_remote_players.size()) * 18.0, FLOOR_Y)
			)
			_remote_players[pid] = rp
	for pid in _remote_players.keys():
		if not seen.has(pid):
			var node: Node = _remote_players[pid]
			if is_instance_valid(node):
				node.queue_free()
			_remote_players.erase(pid)


func _on_net_room_updated(players: Array, _host_id: String, _started: bool, _stage_num: int) -> void:
	_sync_remote_roster(players)
	if NetworkManager.is_online and NetworkManager.is_host:
		_broadcast_host_enemies()


func _on_net_peer_state(data: Dictionary) -> void:
	var pid := String(data.get("peer_id", ""))
	if pid == "" or pid == NetworkManager.my_peer_id:
		return
	if not _remote_players.has(pid) or not is_instance_valid(_remote_players[pid]):
		var rp := Node2D.new()
		rp.set_script(RemotePlayerScript)
		add_child(rp)
		rp.setup(
			pid,
			String(data.get("name", pid)),
			int(data.get("char_idx", 0)),
			String(data.get("attr_id", "office_worker")),
			Vector2(float(data.get("x", 96.0)), float(data.get("y", FLOOR_Y)))
		)
		_remote_players[pid] = rp
	_remote_players[pid].apply_net_state(data)


func _on_net_peer_fx(data: Dictionary) -> void:
	var vfx_name := String(data.get("vfx", "hit_spark"))
	var pos := Vector2(float(data.get("x", 0.0)), float(data.get("y", FLOOR_Y - 14.0)))
	var flip := int(data.get("facing", 1)) < 0
	var sc := float(data.get("scale", 0.45))
	VfxManager.spawn_vfx(vfx_name, self, pos, flip, sc)


func _on_net_enemy_hit(data: Dictionary) -> void:
	var eid := String(data.get("eid", ""))
	var dmg := int(data.get("dmg", 0))
	var kx := float(data.get("knock_x", 0.0))
	if eid == "" or dmg <= 0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and String(e.net_id) == eid:
			if NetworkManager.is_host:
				e.take_damage(dmg, kx, false, true)
			if player != null and is_instance_valid(player):
				player.spawn_floating_text_at(e.global_position + Vector2(0, -28), "เพื่อน -%d" % dmg, Color(0.45, 0.96, 1.0))
			break


func _spawn_net_puppet_enemy(entry: Dictionary) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.set_script(EnemyScript)
	e.net_id = String(entry.get("eid", ""))
	e.is_net_puppet = true
	var pos := Vector2(float(entry.get("x", 320.0)), float(entry.get("y", FLOOR_Y)))
	e._net_target_pos = pos
	add_child(e)
	e.setup(String(entry.get("arch", "frenzy")), pos)
	if bool(entry.get("elite", false)):
		e.make_elite(bool(entry.get("golden", false)))
	e.apply_net_sync(pos.x, pos.y, int(entry.get("hp", e.max_hp)), int(entry.get("max_hp", e.max_hp)), int(entry.get("facing", -1)), String(entry.get("state", "idle")))
	return e


func _on_net_enemy_sync(enemies_arr: Array) -> void:
	if NetworkManager.is_host:
		return
	var by_id: Dictionary = {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and String(e.net_id) != "":
			by_id[String(e.net_id)] = e
	var seen: Dictionary = {}
	for entry in enemies_arr:
		if not (entry is Dictionary):
			continue
		var eid := String(entry.get("eid", ""))
		if eid == "":
			continue
		seen[eid] = true
		if by_id.has(eid):
			var enemy_node: Node = by_id[eid]
			if is_instance_valid(enemy_node):
				enemy_node.is_net_puppet = true
				enemy_node.apply_net_sync(
					float(entry.get("x", enemy_node.position.x)),
					float(entry.get("y", enemy_node.position.y)),
					int(entry.get("hp", enemy_node.hp)),
					int(entry.get("max_hp", enemy_node.max_hp)),
					int(entry.get("facing", enemy_node.facing)),
					String(entry.get("state", "idle"))
				)
		else:
			_spawn_net_puppet_enemy(entry)
	for eid in by_id.keys():
		if not seen.has(eid):
			var dead_node: Node = by_id[eid]
			if is_instance_valid(dead_node):
				dead_node.die_from_network()


func _on_net_player_hit(data: Dictionary) -> void:
	if String(data.get("target_peer", "")) == NetworkManager.my_peer_id and player != null and is_instance_valid(player):
		player.take_damage(int(data.get("dmg", 10)), float(data.get("knock_x", 0.0)), null, bool(data.get("unparryable", false)))


func _on_net_scenario_sync(data: Dictionary) -> void:
	if NetworkManager.is_host:
		return
	var killed_arch := String(data.get("killed_arch", ""))
	if killed_arch != "":
		ScenarioManager.register_enemy_killed(killed_arch, true)
		if bool(data.get("was_elite", false)):
			ScenarioManager.register_elite_killed(bool(data.get("was_golden", false)))


func _broadcast_host_enemies() -> void:
	if not NetworkManager.is_online or not NetworkManager.is_host:
		return
	var payload: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and String(e.net_id) != "" and e.hp > 0:
			payload.append({
				"eid": String(e.net_id),
				"arch": String(e.archetype),
				"x": snappedf(e.position.x, 0.5),
				"y": snappedf(e.position.y, 0.5),
				"hp": e.hp,
				"max_hp": e.max_hp,
				"facing": e.facing,
				"state": String(e._state),
				"elite": bool(e.is_elite),
				"golden": bool(e.is_golden_elite),
			})
	NetworkManager.send_enemy_sync(payload)


func _on_net_revive(_from_peer: String, target_peer: String) -> void:
	if target_peer == NetworkManager.my_peer_id and player != null and GameState.hp <= 0:
		player.revive_coop(0.55)
		ScenarioManager.constellation_message.emit("[เพื่อนร่วมทีมช่วยชุบชีวิตคุณกลับมาแล้ว!]", 0)


func _on_net_toast(text: String) -> void:
	if text != "":
		ScenarioManager.constellation_message.emit(text, 0)


func _spawn_companion(comp_id: String, pos: Vector2) -> void:
	for existing in get_tree().get_nodes_in_group("companions"):
		if existing.comp_id == comp_id:
			return
	var c := CharacterBody2D.new()
	c.set_script(CompanionScript)
	add_child(c)
	c.setup(comp_id, pos)


func _build_stage_1() -> void:
	var dok_tex := SpriteLoader.load_tex("res://assets/sprites/dokkaebi.png")
	_dokkaebi = Sprite2D.new()
	_dokkaebi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if dok_tex != null:
		_dokkaebi.texture = SpriteLoader.make_atlas(dok_tex, 0, 0, 24, 24)
	_dokkaebi.position = Vector2(185, 118)
	_dokkaebi.z_index = 15
	add_child(_dokkaebi)

	_add_interactable("weapon", "[F] เก็บท่อเหล็ก", Vector2(142, FLOOR_Y))
	_add_interactable("npc_rescue", "[F] ช่วยผู้โดยสาร (เควสรอง)", Vector2(820, FLOOR_Y))
	_add_interactable("bug_box", "[F] สำรวจกระเป๋าเด็กน้อย", Vector2(1545, FLOOR_Y))

	var opener := _spawn_enemy("frenzy", Vector2(265, FLOOR_Y))
	opener.max_hp = 95
	opener.hp = 95
	_spawn_enemy("charger", Vector2(390, FLOOR_Y))
	_spawn_enemy("thrower", Vector2(495, FLOOR_Y))

	_car2_guards_alive = 3
	for pair in [["frenzy", 690], ["charger", 880], ["mage", 980]]:
		var g := _spawn_enemy(String(pair[0]), Vector2(float(pair[1]), FLOOR_Y))
		g.enemy_died.connect(_on_car2_guard_died)

	var s1_el := _spawn_enemy("brute", Vector2(1170, FLOOR_Y))
	s1_el.make_elite(false)
	_spawn_enemy("mage", Vector2(1310, FLOOR_Y))
	_spawn_enemy("boss", Vector2(1440, FLOOR_Y))


func _build_stage_2() -> void:
	# Toxic Fog visual overlay over the middle of Dongho Bridge
	var fog := ColorRect.new()
	fog.position = Vector2(FOG_MIN_X, 60)
	fog.size = Vector2(FOG_MAX_X - FOG_MIN_X, 165)
	fog.color = Color(0.15, 0.72, 0.32, 0.24)
	fog.z_index = 18
	add_child(fog)

	var fog_lbl := Label.new()
	fog_lbl.text = "☠ เขตหมอกพิษ (ใช้หน้ากากกันพิษ)"
	fog_lbl.position = Vector2(FOG_MIN_X + 210, 82)
	fog_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	fog_lbl.add_theme_font_size_override("font_size", 11)
	fog_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	fog_lbl.z_index = 19
	add_child(fog_lbl)

	_add_interactable("gas_mask_crate", "[F] เก็บหน้ากากกันหมอกพิษ (เควสรอง)", Vector2(315, FLOOR_Y))
	_add_interactable("station_exit", "[F] เข้าสู่สถานีโอกซู (จบบทที่ 2)", Vector2(1540, FLOOR_Y))

	_spawn_enemy("frenzy", Vector2(380, FLOOR_Y))
	_spawn_enemy("charger", Vector2(470, FLOOR_Y))
	_spawn_enemy("thrower", Vector2(610, FLOOR_Y))
	var el2a := _spawn_enemy("mage", Vector2(760, FLOOR_Y))
	el2a.make_elite(false)
	_spawn_enemy("charger", Vector2(890, FLOOR_Y))
	var el2b := _spawn_enemy("brute", Vector2(1040, FLOOR_Y))
	el2b.make_elite(false)
	_spawn_enemy("mage", Vector2(1210, FLOOR_Y))
	_spawn_enemy("boss_bridge", Vector2(1370, FLOOR_Y))


func _build_stage_3() -> void:
	# Glowing Green Zone safe circle in the middle of the dark station
	_green_zone_rect = ColorRect.new()
	_green_zone_rect.position = Vector2(GREEN_ZONE_X - GREEN_ZONE_RADIUS, 70)
	_green_zone_rect.size = Vector2(GREEN_ZONE_RADIUS * 2.0, 146)
	_green_zone_rect.color = Color(0.14, 0.85, 0.42, 0.18)
	_green_zone_rect.z_index = -2
	add_child(_green_zone_rect)

	var gz_lbl := Label.new()
	gz_lbl.text = "★ GREEN ZONE ★"
	gz_lbl.position = Vector2(GREEN_ZONE_X - 42, 76)
	gz_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	gz_lbl.add_theme_font_size_override("font_size", 11)
	gz_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
	gz_lbl.z_index = -1
	add_child(gz_lbl)

	player.position = Vector2(GREEN_ZONE_X - 60, FLOOR_Y)
	_add_interactable("green_zone", "[F] ยึดเขต Green Zone (เริ่ม 3 เวฟ)", Vector2(GREEN_ZONE_X, FLOOR_Y))
	_add_interactable("npc_rescue", "[F] ช่วยผู้รอดชีวิตในความมืด (เควสรอง)", Vector2(1260, FLOOR_Y))


func _build_stage_4() -> void:
	_add_interactable("king_flag", "[F] ยึดธงสถานีฝั่งซ้าย (1/2)", Vector2(360, FLOOR_Y))
	_add_interactable("king_flag", "[F] ยึดธงสถานีฝั่งขวา (2/2)", Vector2(1140, FLOOR_Y))

	var el4a := _spawn_enemy("brute", Vector2(320, FLOOR_Y))
	el4a.make_elite(false)
	_spawn_enemy("mage", Vector2(460, FLOOR_Y))
	_spawn_enemy("charger", Vector2(780, FLOOR_Y))
	_spawn_enemy("thrower", Vector2(960, FLOOR_Y))
	var el4b := _spawn_enemy("mage", Vector2(1180, FLOOR_Y))
	el4b.make_elite(false)
	_spawn_enemy("boss_king", Vector2(1420, FLOOR_Y))


func _add_interactable(kind: String, prompt: String, pos: Vector2) -> Area2D:
	var n := Area2D.new()
	n.set_script(InteractableScript)
	add_child(n)
	n.setup(kind, prompt, pos)
	n.interacted.connect(_on_interactable)
	return n


func _add_solid_rect(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _add_oneway_luggage(pos: Vector2, props_tex: Texture2D) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 6)
	col.shape = shape
	col.position = Vector2(0, 2)
	col.one_way_collision = true
	body.add_child(col)
	if props_tex != null:
		var sp := Sprite2D.new()
		sp.texture = SpriteLoader.make_atlas(props_tex, 48, 0, 24, 24)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(0, 4)
		body.add_child(sp)
	add_child(body)


func _spawn_enemy(archetype: String, pos: Vector2) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.set_script(EnemyScript)
	_next_enemy_seq += 1
	e.net_id = "s%d_e%d" % [stage_num, _next_enemy_seq]
	if NetworkManager.is_online and not NetworkManager.is_host:
		e.is_net_puppet = true
		e._net_target_pos = pos
	add_child(e)
	e.setup(archetype, pos)
	e.request_summon.connect(_on_boss_summon)
	if NetworkManager.is_online and NetworkManager.is_host:
		e.enemy_died.connect(func(dead_e: Node, arch: String):
			NetworkManager.send_scenario_sync_dict({
				"stage": stage_num,
				"killed_arch": arch,
				"was_elite": bool(dead_e.is_elite),
				"was_golden": bool(dead_e.is_golden_elite),
			})
			call_deferred("_broadcast_host_enemies")
		)
	return e


func _on_boss_summon(arch: String, pos: Vector2) -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= 7:
		return
	var clamped_x := clampf(pos.x, 70.0, STAGE_WIDTH - 70.0)
	var m := _spawn_enemy(arch, Vector2(clamped_x, FLOOR_Y))
	m.aggro_range = 420.0
	VfxManager.spawn_vfx("dash_puff", self, Vector2(clamped_x, FLOOR_Y - 14), false, 0.44)


func _spawn_stage3_wave(wave_num: int) -> void:
	ScenarioManager.set_stage3_wave(wave_num)
	var spawns: Array = []
	match wave_num:
		1:
			spawns = [["frenzy", GREEN_ZONE_X - 200, false], ["charger", GREEN_ZONE_X + 200, false], ["thrower", GREEN_ZONE_X + 260, false], ["frenzy", GREEN_ZONE_X - 260, false]]
		2:
			spawns = [["brute", GREEN_ZONE_X - 210, false], ["mage", GREEN_ZONE_X + 220, false], ["charger", GREEN_ZONE_X - 280, false], ["thrower", GREEN_ZONE_X + 280, false]]
		3:
			spawns = [["charger", GREEN_ZONE_X - 210, true], ["mage", GREEN_ZONE_X + 210, false], ["brute", GREEN_ZONE_X + 270, false], ["frenzy", GREEN_ZONE_X - 270, false]]
		4:
			spawns = [["brute", GREEN_ZONE_X - 210, true], ["mage", GREEN_ZONE_X + 210, true], ["thrower", GREEN_ZONE_X - 280, false], ["charger", GREEN_ZONE_X + 280, false]]
		_:
			spawns = [["mage", GREEN_ZONE_X - 230, true], ["charger", GREEN_ZONE_X + 250, true], ["boss_station", GREEN_ZONE_X + 190, false]]
	_stage3_wave_alive = spawns.size()
	for entry in spawns:
		var e := _spawn_enemy(String(entry[0]), Vector2(float(entry[1]), FLOOR_Y))
		if bool(entry[2]):
			e.make_elite(false)
		e.aggro_range = 460.0
		e.enemy_died.connect(_on_stage3_wave_enemy_died)


func _on_stage3_wave_enemy_died(_enemy: Node, _arch: String) -> void:
	_stage3_wave_alive = maxi(0, _stage3_wave_alive - 1)
	if _stage3_wave_alive == 0:
		if ScenarioManager.stage3_wave < ScenarioManager.STAGE_3_TOTAL_WAVES:
			_stage3_next_wave_delay = 2.0
		else:
			ScenarioManager.complete_stage3_defense()


func _on_car2_guard_died(_enemy: Node, _arch: String) -> void:
	_car2_guards_alive = maxi(0, _car2_guards_alive - 1)


func _on_interactable(kind: String, node: Node) -> void:
	match kind:
		"weapon":
			GameState.add_weapon("iron_pipe", true)
			SfxManager.play("coin")
			player.spawn_floating_text("ได้ท่อเหล็ก!", Color(0.5, 0.9, 1.0))
			node.mark_used()
		"npc_rescue":
			if stage_num == 1 and _car2_guards_alive > 0:
				player.spawn_floating_text("จัดการศัตรูในตู้ 2 ก่อน!", Color(1.0, 0.78, 0.25))
			else:
				ScenarioManager.complete_sub_rescue()
				SfxManager.play("levelup")
				player.spawn_floating_text("คู่หูเข้าร่วมทีม!", Color(0.35, 0.95, 0.55))
				var new_cid := "yuna" if stage_num == 1 else "jaehoon"
				_spawn_companion(new_cid, node.global_position)
				VfxManager.spawn_vfx("level_up", self, node.global_position, false, 0.45)
				node.mark_used()
		"bug_box":
			request_bug_box_choice.emit()
		"gas_mask_crate":
			ScenarioManager.complete_stage2_gas_mask()
			SfxManager.play("levelup")
			player.spawn_floating_text("ได้หน้ากากกันพิษ!", Color(0.45, 1.0, 0.65))
			node.mark_used()
		"station_exit":
			if not ScenarioManager.stage2_boss_dead or ScenarioManager.stage2_kills < ScenarioManager.STAGE_2_KILLS_REQUIRED:
				player.spawn_floating_text("โค่นบอส+อสูรให้ครบ %d ตัวก่อน!" % ScenarioManager.STAGE_2_KILLS_REQUIRED, Color(1.0, 0.45, 0.35))
			else:
				ScenarioManager.complete_stage2_reach_station()
				node.mark_used()
		"green_zone":
			node.mark_used()
			SfxManager.play("system")
			VfxManager.spawn_vfx("level_up", self, Vector2(GREEN_ZONE_X, FLOOR_Y), false, 0.55)
			_spawn_stage3_wave(1)
		"king_flag":
			# Must clear guardians near this flag before capturing!
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.archetype.begins_with("boss") and absf(e.global_position.x - node.global_position.x) < 150.0:
					player.spawn_floating_text("กำจัดผู้เฝ้าธงรอบๆ ก่อน!", Color(1.0, 0.55, 0.25))
					return
			node.mark_used()
			SfxManager.play("levelup")
			VfxManager.spawn_vfx("level_up", self, node.global_position, false, 0.50)
			player.spawn_floating_text("ยึดธงสำเร็จ! +ATK", Color(1.0, 0.85, 0.2))
			ScenarioManager.register_stage4_flag_captured()
			# Counter-attack ambush wave!
			var amb_x := clampf(node.global_position.x + 160.0, 80.0, STAGE_WIDTH - 80.0)
			var amb := _spawn_enemy("charger", Vector2(amb_x, FLOOR_Y))
			amb.make_elite(false)
			amb.aggro_range = 450.0


func trigger_screen_shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_timer = maxf(_shake_timer, duration)


func _process(delta: float) -> void:
	_dokkaebi_time += delta
	if NetworkManager.is_online and player != null and is_instance_valid(player):
		_net_player_tick += delta
		if _net_player_tick >= 0.065:
			_net_player_tick = 0.0
			NetworkManager.send_player_state(
				player.global_position,
				player.velocity,
				player.facing,
				player.get_current_anim(),
				GameState.hp,
				GameState.max_hp,
				player.is_dashing(),
				player.is_parrying()
			)
		if Input.is_action_just_pressed("interact") and GameState.hp > 0:
			for rp in _remote_players.values():
				if is_instance_valid(rp) and rp.is_downed and rp.global_position.distance_to(player.global_position) <= 58.0:
					NetworkManager.send_revive(rp.peer_id)
					SfxManager.play("levelup")
					player.spawn_floating_text("ชุบชีวิตเพื่อน!", Color(0.35, 1.0, 0.65))
					break
		if NetworkManager.is_host:
			_net_enemy_tick += delta
			if _net_enemy_tick >= 0.08:
				_net_enemy_tick = 0.0
				_broadcast_host_enemies()
	if _dokkaebi != null:
		_dokkaebi.position.y = 114.0 + sin(_dokkaebi_time * 3.2) * 5.0
	if _flicker_overlay != null:
		var fl := 0.06 if stage_num == 1 else (0.14 if stage_num == 3 else 0.04)
		if ScenarioManager.blackout_active:
			fl = 0.62
		elif stage_num == 1 and fmod(_dokkaebi_time, 4.7) > 4.55:
			fl = 0.22
		_flicker_overlay.color.a = fl

	# Sudden Dokkaebi Events scheduler (keeps every run unpredictable!)
	if ScenarioManager.is_active and not ScenarioManager.is_cleared and not ScenarioManager.sudden_event_active and player != null:
		_sudden_event_cd -= delta
		if _sudden_event_cd <= 0.0:
			_sudden_event_cd = 32.0
			var kinds := ["untouchable", "elite_hunt", "blackout"]
			var pick: String = kinds[randi() % kinds.size()]
			ScenarioManager.start_sudden_event(pick)
			if pick == "elite_hunt":
				var ex := clampf(player.global_position.x + (155.0 if player.global_position.x < STAGE_WIDTH - 220 else -155.0), 80.0, STAGE_WIDTH - 80.0)
				var ge := _spawn_enemy("charger" if randf() > 0.5 else "mage", Vector2(ex, FLOOR_Y))
				ge.make_elite(true)
				ge.aggro_range = 450.0
				VfxManager.spawn_vfx("level_up", self, Vector2(ex, FLOOR_Y), false, 0.45)
	if _shake_timer > 0.0 and camera != null:
		_shake_timer -= delta
		camera.offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
		if _shake_timer <= 0.0:
			camera.offset = Vector2.ZERO
			_shake_strength = 0.0

	# Probability Storm Penalty when total stat level exceeds Scenario cap!
	if player != null and is_instance_valid(player) and ScenarioManager.is_active and GameState.hp > 0:
		var over_lv := GameState.get_probability_overflow(stage_num)
		if over_lv > 0:
			var cur_lv := GameState.get_total_level()
			var cap_lv := GameState.get_stage_level_cap(stage_num)
			hazard_status_changed.emit("⚡ [พายุแห่งความเป็นไปได้!] เลเวลเกินเพดาน (Lv.%d/%d) — โดนตรึง & เลือดลดต่อเนื่อง!" % [cur_lv, cap_lv])
			if not _prob_warned:
				_prob_warned = true
				var msg := "[⚡ กำแพงที่สี่สั่นสะเทือน! พายุแห่งความเป็นไปได้กำลังลงทัณฑ์ผู้ฝ่าฝืนเพดานบทละคร!]" if GameState.current_attribute_id == "apocalypse_reader" else "[⚡ คำเตือนจาก Star Stream! เลเวลของคุณเกินเพดานความเป็นไปได้ของบทละครนี้!]"
				ScenarioManager.constellation_message.emit(msg, 0)
			# Continuous HP drain scaling with overflow
			_prob_drain_tick += delta
			if _prob_drain_tick >= 1.15:
				_prob_drain_tick = 0.0
				var drain := 5 + over_lv * 3
				GameState.hp = maxi(0, GameState.hp - drain)
				GameState.hp_mp_changed.emit()
				SfxManager.play("hurt")
				VfxManager.spawn_vfx("dark_orb", self, player.global_position + Vector2(0, -16), false, 0.35)
				player.spawn_floating_text("⚡ ความเป็นไปได้ -%d" % drain, Color(0.95, 0.25, 0.98))
				if GameState.hp <= 0:
					player.player_died.emit()
			# Periodic Probability Bind (locks movement!)
			if _prob_bind_timer > 0.0:
				_prob_bind_timer -= delta
				player.controls_locked = true
				if _prob_bind_timer <= 0.0:
					player.controls_locked = false
			else:
				_prob_bind_cd -= delta
				if _prob_bind_cd <= 0.0:
					_prob_bind_cd = maxf(3.2, 5.2 - float(over_lv) * 0.25)
					_prob_bind_timer = 1.65
					player.controls_locked = true
					SfxManager.play("skill")
					VfxManager.spawn_vfx("lightning", self, player.global_position + Vector2(0, -18), false, 0.72)
					trigger_screen_shake(5.5, 0.24)
					player.spawn_floating_text("⚡ ถูกความเป็นไปได้ตรึง! ขยับไม่ได้!", Color(1.0, 0.32, 0.95))
		else:
			if _prob_bind_timer > 0.0:
				_prob_bind_timer = 0.0
				player.controls_locked = false
			if _prob_warned:
				_prob_warned = false
				hazard_status_changed.emit("")
			_prob_drain_tick = 0.0

	# Stage 1 Farm mode periodic reinforcements
	if stage_num == 1 and ScenarioManager.is_farming and player != null:
		_farm_spawn_timer -= delta
		if _farm_spawn_timer <= 0.0:
			_farm_spawn_timer = 13.0
			if get_tree().get_nodes_in_group("enemies").size() < 6:
				var pool := ["frenzy", "charger", "thrower", "mage", "brute"]
				var pick: String = pool[randi() % pool.size()]
				var sx := clampf(player.global_position.x + (190.0 if randf() > 0.5 else -190.0), 80.0, STAGE_WIDTH - 80.0)
				_spawn_enemy(pick, Vector2(sx, FLOOR_Y))
				ScenarioManager.constellation_message.emit("[ผู้รอดชีวิตคลุ้มคลั่งกลุ่มใหม่บุกเข้ามาในตู้รถไฟ!]", 0)

	# Stage 2 Toxic Fog Hazard
	if stage_num == 2 and player != null and ScenarioManager.is_active:
		var in_fog := player.global_position.x >= FOG_MIN_X and player.global_position.x <= FOG_MAX_X
		if in_fog and not GameState.has_gas_mask:
			hazard_status_changed.emit("⚠ อยู่ในเขตหมอกพิษ! (หาหน้ากากกันพิษหรือซื้อในถุงโดแกบี [B])")
			_hazard_tick += delta
			if _hazard_tick >= 1.2:
				_hazard_tick = 0.0
				player.take_damage(6, 0.0)
		else:
			_hazard_tick = 0.0
			hazard_status_changed.emit("")

	# Stage 3 Green Zone Waves & Darkness Hazard
	if stage_num == 3 and player != null and ScenarioManager.is_active:
		if _stage3_next_wave_delay > 0.0:
			_stage3_next_wave_delay -= delta
			if _stage3_next_wave_delay <= 0.0:
				_spawn_stage3_wave(ScenarioManager.stage3_wave + 1)
		if ScenarioManager.stage3_zone_claimed:
			var out_of_zone := absf(player.global_position.x - GREEN_ZONE_X) > GREEN_ZONE_RADIUS
			if out_of_zone:
				hazard_status_changed.emit("⚠ คุณอยู่นอกเขต Green Zone! ความมืดกำลังกัดกิน HP!")
				_hazard_tick += delta
				if _hazard_tick >= 1.1:
					_hazard_tick = 0.0
					player.take_damage(7, 0.0)
			else:
				_hazard_tick = 0.0
				hazard_status_changed.emit("")
