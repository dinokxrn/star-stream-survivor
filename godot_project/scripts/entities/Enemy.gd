extends CharacterBody2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const ProjectileScript = preload("res://scripts/world/Projectile.gd")
const SkyHazardScript = preload("res://scripts/world/SkyHazard.gd")

signal enemy_died(enemy: Node, archetype: String)
signal request_summon(archetype: String, pos: Vector2)

const GRAVITY: float = 760.0

var net_id: String = ""
var is_net_puppet: bool = false
var _net_target_pos: Vector2 = Vector2.ZERO
var archetype: String = "frenzy"
var is_elite: bool = false
var is_golden_elite: bool = false
var max_hp: int = 110
var hp: int = 110
var move_speed: float = 96.0
var attack_damage: int = 19
var aggro_range: float = 235.0
var attack_range: float = 32.0
var preferred_min_range: float = 0.0
var facing: int = -1

var _state: String = "idle" # idle, chase, windup, strike, recover, hurt, stunned
var _state_timer: float = 0.0
var _attack_cd: float = 0.0
var _did_hit_this_strike: bool = false
var _slow_timer: float = 0.0
var _stun_timer: float = 0.0
var _armor_break_timer: float = 0.0
var _weaken_timer: float = 0.0
var _poison_timer: float = 0.0
var _poison_tick: float = 0.0
var _death_mark_timer: float = 0.0
var _poise: int = 3
var _max_poise: int = 3
var _next_unparryable: bool = false
var _gap_close_cd: float = 2.0
var _boss_phase2: bool = false
var _boss_phase3: bool = false
var _boss_pattern: int = 0
var _double_lunge_left: int = 0

var _sprite: AnimatedSprite2D
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect
var _telegraph_label: Label
var _elite_label: Label = null


func setup(p_archetype: String, pos: Vector2) -> void:
	archetype = p_archetype
	position = pos
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1

	match archetype:
		"frenzy":
			max_hp = 165
			move_speed = 108.0
			attack_damage = 26
			attack_range = 34.0
			aggro_range = 260.0
		"charger":
			max_hp = 245
			move_speed = 118.0
			attack_damage = 34
			attack_range = 115.0
			aggro_range = 275.0
		"thrower":
			max_hp = 175
			move_speed = 88.0
			attack_damage = 30
			attack_range = 185.0
			preferred_min_range = 88.0
			aggro_range = 280.0
		"mage":
			max_hp = 205
			move_speed = 82.0
			attack_damage = 32
			attack_range = 205.0
			preferred_min_range = 98.0
			aggro_range = 290.0
		"brute":
			max_hp = 420
			move_speed = 76.0
			attack_damage = 44
			attack_range = 54.0
			aggro_range = 260.0
		"boss":
			max_hp = 980
			move_speed = 112.0
			attack_damage = 42
			attack_range = 155.0
			aggro_range = 330.0
		"boss_bridge":
			max_hp = 1450
			move_speed = 118.0
			attack_damage = 48
			attack_range = 165.0
			aggro_range = 340.0
		"boss_station":
			max_hp = 1850
			move_speed = 124.0
			attack_damage = 54
			attack_range = 170.0
			aggro_range = 350.0
		"boss_king":
			max_hp = 3400
			move_speed = 134.0
			attack_damage = 66
			attack_range = 195.0
			aggro_range = 390.0
	# Scale regular enemies strongly across chapters so later stages stay intense!
	if not archetype.begins_with("boss") and ScenarioManager.current_stage > 1:
		var stage_scale := 1.0 + float(ScenarioManager.current_stage - 1) * 0.35
		max_hp = int(round(float(max_hp) * stage_scale))
		attack_damage = int(round(float(attack_damage) * (1.0 + float(ScenarioManager.current_stage - 1) * 0.22)))
	hp = max_hp

	var is_boss := archetype.begins_with("boss")
	_max_poise = 10 if is_boss else (7 if archetype == "brute" else 4)
	_poise = _max_poise
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 30) if (archetype == "brute" or is_boss) else Vector2(14, 26)
	col.shape = shape
	col.position = Vector2(0, -15 if (archetype == "brute" or is_boss) else -13)
	add_child(col)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -19)
	if is_boss:
		var sc := 1.40 if archetype == "boss_king" else 1.26
		_sprite.scale = Vector2(sc, sc)
		_sprite.position = Vector2(0, -25)
	elif archetype == "brute":
		_sprite.scale = Vector2(1.16, 1.16)
		_sprite.position = Vector2(0, -22)
	_sprite.sprite_frames = _build_frames()
	add_child(_sprite)
	_sprite.play("idle")

	var bar_w := 52.0 if is_boss else (30.0 if archetype == "brute" else 24.0)
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(bar_w, 4 if is_boss else 3)
	_hp_bar_bg.position = Vector2(-bar_w * 0.5, -50 if is_boss else -36)
	_hp_bar_bg.color = Color(0.08, 0.08, 0.12, 0.90)
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size = _hp_bar_bg.size
	_hp_bar_fill.position = _hp_bar_bg.position
	_hp_bar_fill.color = Color(0.98, 0.78, 0.15) if archetype == "boss_king" else (Color(0.96, 0.22, 0.36) if is_boss else (Color(0.75, 0.38, 1.0) if archetype == "mage" else Color(0.95, 0.38, 0.28)))
	add_child(_hp_bar_fill)

	_telegraph_label = Label.new()
	_telegraph_label.text = "!"
	_telegraph_label.visible = false
	_telegraph_label.position = Vector2(-4, -62 if is_boss else -48)
	_telegraph_label.add_theme_font_size_override("font_size", 12)
	_telegraph_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.25))
	add_child(_telegraph_label)


func make_elite(golden: bool = false) -> void:
	is_elite = true
	is_golden_elite = golden
	max_hp = int(round(float(max_hp) * 2.15))
	hp = max_hp
	move_speed *= 1.30
	attack_damage = int(round(float(attack_damage) * 1.42))
	_sprite.scale *= 1.15
	_hp_bar_fill.color = Color(1.0, 0.85, 0.2) if golden else Color(0.85, 0.35, 1.0)
	_elite_label = Label.new()
	_elite_label.text = "★ GOLD ELITE" if golden else "★ ELITE"
	_elite_label.position = Vector2(-24, -48)
	_elite_label.add_theme_font_size_override("font_size", 8)
	_elite_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22) if golden else Color(0.88, 0.55, 1.0))
	add_child(_elite_label)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var sprite_key := "boss" if archetype.begins_with("boss") else archetype
	var tex_path := "res://assets/sprites/enemy_%s.png" % sprite_key
	var tex := SpriteLoader.load_tex(tex_path)
	if tex == null:
		return sf
	var defs := {
		"idle": [0, 1],
		"run": [2, 3],
		"attack": [4],
		"hurt": [5],
	}
	for anim in defs.keys():
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 7.0)
		sf.set_animation_loop(anim, anim in ["idle", "run"])
		for idx in defs[anim]:
			sf.add_frame(anim, SpriteLoader.make_atlas(tex, int(idx) * 32, 0, 32, 40))
	return sf


func apply_slow(duration: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)


func apply_debuff(kind: String, duration: float) -> void:
	match kind:
		"armor_break": _armor_break_timer = maxf(_armor_break_timer, duration)
		"weaken": _weaken_timer = maxf(_weaken_timer, duration)
		"poison": _poison_timer = maxf(_poison_timer, duration)
		"death_mark":
			_death_mark_timer = maxf(_death_mark_timer, duration)
			_slow_timer = maxf(_slow_timer, duration)


func pull_toward(target_x: float, strength: float = 0.65) -> void:
	global_position.x = lerpf(global_position.x, target_x, strength)


func apply_stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	_state = "stunned"
	_telegraph_label.text = "STUN"
	_telegraph_label.visible = true
	_telegraph_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	velocity.x = -float(facing) * 90.0


func is_attacking_danger() -> bool:
	return _state == "strike" or (_state == "windup" and _state_timer < 0.18)


func _physics_process(delta: float) -> void:
	if is_net_puppet:
		if position.distance_to(_net_target_pos) > 130.0:
			position = _net_target_pos
		else:
			position = position.lerp(_net_target_pos, minf(1.0, delta * 14.0))
		if _sprite != null:
			_sprite.flip_h = facing < 0
		_update_anim()
		return

	if _slow_timer > 0.0:
		_slow_timer = maxf(0.0, _slow_timer - delta)
	if _armor_break_timer > 0.0:
		_armor_break_timer = maxf(0.0, _armor_break_timer - delta)
	if _weaken_timer > 0.0:
		_weaken_timer = maxf(0.0, _weaken_timer - delta)
	if _death_mark_timer > 0.0:
		_death_mark_timer = maxf(0.0, _death_mark_timer - delta)
	if _poison_timer > 0.0:
		_poison_timer = maxf(0.0, _poison_timer - delta)
		_poison_tick += delta
		if _poison_tick >= 0.9:
			_poison_tick = 0.0
			take_damage(maxi(8, int(float(max_hp) * 0.04)), 0.0, false)
	if _gap_close_cd > 0.0:
		_gap_close_cd = maxf(0.0, _gap_close_cd - delta)
	var speed_mult := 0.45 if _slow_timer > 0.0 else (1.28 if _boss_phase2 else 1.0)
	if ScenarioManager.blackout_active:
		speed_mult *= 1.18

	if _attack_cd > 0.0:
		_attack_cd -= delta * (0.55 if _slow_timer > 0.0 else (1.35 if _boss_phase2 else 1.0))
	velocity.y += GRAVITY * delta

	var player := _find_nearest_target()
	if player == null or not is_instance_valid(player):
		velocity.x = 0.0
		move_and_slide()
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = absf(dx)
	var is_boss := archetype.begins_with("boss")

	match _state:
		"stunned":
			_stun_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)
			if _stun_timer <= 0.0:
				_telegraph_label.text = "!"
				_telegraph_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.25))
				_telegraph_label.visible = false
				_state = "chase"
		"hurt":
			_state_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
			if _state_timer <= 0.0:
				_state = "chase"
		"windup":
			_state_timer -= delta * (0.65 if _slow_timer > 0.0 else 1.0)
			velocity.x = 0.0
			_telegraph_label.text = "⚠ RED" if _next_unparryable else "!"
			_telegraph_label.visible = true
			var flash_col := Color(1.7, 0.2, 0.2) if _next_unparryable else (Color(0.85, 0.45, 1.45) if archetype == "mage" else Color(1.5, 0.6, 0.6))
			_sprite.modulate = flash_col if int(_state_timer * 22.0) % 2 == 0 else Color.WHITE
			if _state_timer <= 0.0:
				_telegraph_label.visible = false
				_telegraph_label.text = "!"
				_sprite.modulate = _base_tint()
				_execute_strike(player)
		"strike":
			_state_timer -= delta
			if not _did_hit_this_strike and (archetype in ["frenzy", "charger"] or is_boss):
				var hit_dist := 42.0 if is_boss else 30.0
				if global_position.distance_to(player.global_position) <= hit_dist:
					_did_hit_this_strike = true
					var eff_dmg := int(round(float(attack_damage) * (0.60 if _weaken_timer > 0.0 else 1.0)))
					_hit_target(player, eff_dmg, float(facing) * 175.0, _next_unparryable)
			if _state_timer <= 0.0:
				_next_unparryable = false
				if _double_lunge_left > 0:
					_double_lunge_left -= 1
					facing = 1 if (player.global_position.x - global_position.x) >= 0.0 else -1
					_sprite.flip_h = facing < 0
					_state = "windup"
					_state_timer = 0.22
				else:
					_state = "recover"
					_state_timer = 0.20 if _boss_phase2 else (0.26 if is_boss else 0.30)
					_attack_cd = 0.48 if _boss_phase2 else (0.65 if (archetype == "frenzy" or is_boss) else 0.88)
		"recover":
			_state_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 540.0 * delta)
			if _state_timer <= 0.0:
				_state = "chase"
		_:
			if dist <= aggro_range:
				facing = 1 if dx >= 0.0 else -1
				_sprite.flip_h = facing < 0
				if preferred_min_range > 0.0 and dist < preferred_min_range and _attack_cd > 0.15:
					_state = "chase"
					velocity.x = -float(facing) * move_speed * 0.78 * speed_mult
				elif dist <= attack_range and _attack_cd <= 0.0:
					_state = "windup"
					_next_unparryable = (is_boss and _boss_phase2 and randf() < 0.48) or (archetype == "brute" and randf() < 0.48)
					_state_timer = 0.22 if _boss_phase2 else (0.24 if archetype == "frenzy" else (0.38 if archetype == "brute" else 0.31))
					velocity.x = 0.0
				else:
					_state = "chase"
					# Anti-kiting Gap-Closer lunge for melee enemies when player runs far away!
					if preferred_min_range == 0.0 and dist > 90.0 and dist < 230.0 and _gap_close_cd <= 0.0 and is_on_floor():
						_gap_close_cd = 2.1
						velocity.x = float(facing) * (move_speed * 2.60)
						velocity.y = -125.0
					else:
						velocity.x = float(facing) * move_speed * speed_mult
			else:
				_state = "idle"
				velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)

	move_and_slide()
	_update_anim()


func _execute_strike(player: Node) -> void:
	_state = "strike"
	_did_hit_this_strike = false

	match archetype:
		"frenzy":
			_state_timer = 0.18
			velocity.x = float(facing) * 110.0
		"charger":
			_state_timer = 0.30
			velocity.x = float(facing) * 265.0
			SfxManager.play("dash")
		"thrower":
			_state_timer = 0.16
			_did_hit_this_strike = true
			var dist_x := clampf(player.global_position.x - global_position.x, -175.0, 175.0)
			_spawn_enemy_proj({
				"pos": global_position + Vector2(float(facing) * 10.0, -20),
				"vel": Vector2(dist_x * 1.20, -155.0),
				"gravity": 340.0,
				"damage": attack_damage,
				"radius": 11.0,
				"color": Color(1.0, 0.48, 0.15),
				"dot_size": 7.0,
				"explode_vfx": "fire_bomb",
				"explode_radius": 32.0,
			})
			SfxManager.play("slash")
		"mage":
			# 3-orb spread fan! (Jump, Dash, or Parry to reflect!)
			_state_timer = 0.22
			_did_hit_this_strike = true
			for vy in [-48.0, 0.0, 48.0]:
				_spawn_enemy_proj({
					"pos": global_position + Vector2(float(facing) * 14.0, -18),
					"vel": Vector2(float(facing) * 205.0, vy),
					"damage": attack_damage,
					"radius": 12.0,
					"vfx": "dark_orb",
					"vfx_scale": 0.24,
					"explode_vfx": "hit_spark",
					"life": 1.8,
				})
			SfxManager.play("skill")
		"brute":
			_state_timer = 0.26
			_did_hit_this_strike = true
			VfxManager.spawn_vfx("ground_slam", get_parent(), global_position + Vector2(float(facing) * 22.0, 0), facing < 0, 0.50)
			SfxManager.play("hit")
			if global_position.distance_to(player.global_position) <= 64.0:
				player.take_damage(attack_damage, float(facing) * 220.0, self)
		"boss", "boss_bridge", "boss_station", "boss_king":
			_boss_pattern = (_boss_pattern + 1) % (4 if _boss_phase2 else 2)
			if _boss_pattern == 0:
				# Lunge + slash (2-hit double lunge in Phase 2!)
				_state_timer = 0.26
				if _boss_phase2 and _double_lunge_left == 0:
					_double_lunge_left = 1
				velocity.x = float(facing) * (255.0 if _boss_phase2 else 220.0)
				VfxManager.spawn_vfx("slash", get_parent(), global_position + Vector2(float(facing) * 28.0, -16), facing < 0, 0.64)
				SfxManager.play("slash")
			elif _boss_pattern == 1:
				# 3-orb dark spread volley
				_state_timer = 0.20
				_did_hit_this_strike = true
				var fan := [-72.0, -36.0, 0.0, 36.0, 72.0] if _boss_phase2 else [-42.0, 0.0, 42.0]
				for vy in fan:
					_spawn_enemy_proj({
						"pos": global_position + Vector2(float(facing) * 18.0, -18),
						"vel": Vector2(float(facing) * (245.0 if _boss_phase2 else 215.0), vy),
						"damage": attack_damage - 2,
						"radius": 13.0,
						"vfx": "dark_orb",
						"vfx_scale": 0.28,
						"explode_vfx": "hit_spark",
						"life": 1.9,
					})
				SfxManager.play("skill")
			elif _boss_pattern == 2:
				# Phase 2 Ground Slam shockwave + Twin Falling Sky Pillars!
				_state_timer = 0.28
				_did_hit_this_strike = true
				VfxManager.spawn_vfx("ground_slam", get_parent(), global_position, false, 0.68)
				SfxManager.play("skill")
				for px_off in [0.0, float(facing) * 58.0]:
					var hz := Node2D.new()
					hz.set_script(SkyHazardScript)
					get_parent().add_child(hz)
					hz.setup(player.global_position.x + px_off, 212.0, attack_damage)
				if global_position.distance_to(player.global_position) <= 94.0:
					player.take_damage(attack_damage + 10, float(facing) * 255.0, self, true)
			else:
				# Phase 2 Summon reinforcement minion!
				_state_timer = 0.24
				_did_hit_this_strike = true
				VfxManager.spawn_vfx("mana_burst", get_parent(), global_position + Vector2(0, -18), false, 0.48)
				SfxManager.play("system")
				request_summon.emit("mage" if randf() > 0.5 else "frenzy", global_position + Vector2(-float(facing) * 44.0, 0))


func _spawn_enemy_proj(opts: Dictionary) -> void:
	opts["from_player"] = false
	var proj := Node2D.new()
	proj.set_script(ProjectileScript)
	get_parent().add_child(proj)
	proj.setup(opts)


func _base_tint() -> Color:
	if _stun_timer > 0.0:
		return Color(1.3, 1.25, 0.65)
	if _slow_timer > 0.0:
		return Color(0.55, 0.85, 1.3)
	if is_golden_elite:
		return Color(1.45, 1.22, 0.55)
	if is_elite:
		return Color(1.25, 0.85, 1.45)
	if _boss_phase2:
		return Color(1.4, 0.62, 0.68)
	if archetype == "boss_bridge":
		return Color(0.75, 1.15, 0.95)
	if archetype == "boss_station":
		return Color(0.85, 0.75, 1.25)
	if archetype == "boss_king":
		return Color(1.25, 1.05, 0.60)
	return Color.WHITE


func _find_nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = 999999.0
	var local_p := get_tree().get_first_node_in_group("player")
	if local_p != null and is_instance_valid(local_p) and GameState.hp > 0:
		best = local_p
		best_d = absf(local_p.global_position.x - global_position.x)
	if NetworkManager.is_online:
		for rp in get_tree().get_nodes_in_group("remote_players"):
			if is_instance_valid(rp) and not rp.is_downed:
				var d := absf(rp.global_position.x - global_position.x)
				if d < best_d:
					best_d = d
					best = rp
	return best


func _hit_target(target: Node, eff_dmg: int, knock_x: float, unparryable: bool) -> void:
	if target.has_method("take_damage"):
		target.take_damage(eff_dmg, knock_x, self, unparryable)
	elif NetworkManager.is_online and NetworkManager.is_host and target.is_in_group("remote_players"):
		NetworkManager.send_player_hit(String(target.peer_id), eff_dmg, knock_x, unparryable)


func apply_net_sync(nx: float, ny: float, nhp: int, nmax_hp: int, nfacing: int, nstate: String = "idle") -> void:
	_net_target_pos = Vector2(nx, ny)
	if position == Vector2.ZERO or absf(position.x - nx) > 130.0:
		position = _net_target_pos
	if nfacing != 0:
		facing = nfacing
	_state = nstate
	max_hp = maxi(1, nmax_hp)
	hp = clampi(nhp, 0, max_hp)
	var is_boss := archetype.begins_with("boss")
	var bar_w := 52.0 if is_boss else (30.0 if archetype == "brute" else 24.0)
	if _hp_bar_fill != null:
		_hp_bar_fill.size.x = bar_w * (float(hp) / float(max_hp))
	if hp <= 0:
		die_from_network()


func die_from_network() -> void:
	VfxManager.spawn_vfx("coin_sparkle", get_parent(), global_position + Vector2(0, -14), false, 0.50)
	SfxManager.play("coin")
	queue_free()


func take_damage(amount: int, knockback_x: float, heavy_poise_break: bool = false, from_network: bool = false) -> void:
	if is_net_puppet and not from_network:
		if NetworkManager.is_online and net_id != "":
			NetworkManager.send_enemy_hit(net_id, amount, knockback_x, 0.0)
		# Immediate visual hit feedback on Guest; Host confirms exact HP & death!
		hp = maxi(1, hp - amount)
		var is_boss_p := archetype.begins_with("boss")
		var bar_w_p := 52.0 if is_boss_p else (30.0 if archetype == "brute" else 24.0)
		if _hp_bar_fill != null:
			_hp_bar_fill.size.x = bar_w_p * (float(hp) / float(max_hp))
		if _sprite != null:
			_sprite.modulate = Color(1.8, 0.9, 0.9)
		return
	if not from_network and NetworkManager.is_online and net_id != "":
		NetworkManager.send_enemy_hit(net_id, amount, knockback_x, 0.0)
	var mult := 1.0
	if _stun_timer > 0.0:
		mult *= 1.35
	if _armor_break_timer > 0.0:
		mult *= 1.45
	if _death_mark_timer > 0.0:
		mult *= 1.60
	var final_dmg := int(round(float(amount) * mult))
	hp = maxi(0, hp - final_dmg)
	var is_boss := archetype.begins_with("boss")
	var bar_w := 52.0 if is_boss else (30.0 if archetype == "brute" else 24.0)
	_hp_bar_fill.size.x = bar_w * (float(hp) / float(max_hp))

	if is_boss and not _boss_phase2 and hp > 0 and hp <= int(float(max_hp) * (0.66 if archetype == "boss_king" else 0.50)):
		_boss_phase2 = true
		SfxManager.play("system")
		SfxManager.play_bgm("bgm_boss")
		VfxManager.spawn_vfx("mana_burst", get_parent(), global_position + Vector2(0, -16), false, 0.60)
		ScenarioManager.constellation_message.emit("[คำเตือน! บอสเข้าสู่เฟส 2 — ท่าสีแดงปัดไม่ได้ + เสาไฟจากฟ้า + เรียกลูกน้อง!]", 0)
	elif archetype == "boss_king" and not _boss_phase3 and hp > 0 and hp <= int(float(max_hp) * 0.33):
		_boss_phase3 = true
		move_speed *= 1.22
		attack_damage += 8
		SfxManager.play("system")
		VfxManager.spawn_vfx("fire_bomb", get_parent(), global_position + Vector2(0, -16), false, 0.72)
		ScenarioManager.constellation_message.emit("[★ คำเตือนสูงสุด! ทรราชผู้ชิงบัลลังก์เข้าสู่เฟส 3 'ราชาคลั่ง'! ★]", 0)
		request_summon.emit("brute", global_position + Vector2(-50.0, 0))

	# Poise system: prevents infinite light-attack stunlock!
	_poise -= (3 if heavy_poise_break else 1)
	var poise_broken := _poise <= 0
	if poise_broken:
		_poise = _max_poise

	var has_hyper_armor := (is_boss or archetype == "brute" or is_elite) and (_state in ["windup", "strike"])
	if poise_broken and not has_hyper_armor and _stun_timer <= 0.0:
		_telegraph_label.visible = false
		_state = "hurt"
		_state_timer = 0.14 if (is_boss or archetype == "brute" or is_elite) else 0.20
		velocity.x = knockback_x * (0.30 if (is_boss or archetype == "brute" or is_elite) else 0.85)
		velocity.y = -36.0
	_sprite.modulate = _base_tint()

	if hp <= 0:
		VfxManager.spawn_vfx("coin_sparkle", get_parent(), global_position + Vector2(0, -14), false, 0.50)
		SfxManager.play("coin")
		if is_elite:
			ScenarioManager.register_elite_killed(is_golden_elite)
		ScenarioManager.register_enemy_killed(archetype, true)
		enemy_died.emit(self, archetype)
		queue_free()


func _update_anim() -> void:
	_sprite.modulate = _base_tint() if _state != "windup" else _sprite.modulate
	if _state == "hurt" or _state == "stunned":
		_sprite.play("hurt")
	elif _state == "strike" or _state == "windup":
		_sprite.play("attack")
	elif absf(velocity.x) > 8.0:
		_sprite.play("run")
	else:
		_sprite.play("idle")
