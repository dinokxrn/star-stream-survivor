extends CharacterBody2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const GameData = preload("res://scripts/data/GameData.gd")
const FloatingTextScript = preload("res://scripts/world/FloatingText.gd")
const ProjectileScript = preload("res://scripts/world/Projectile.gd")

signal player_died
signal hit_enemy(enemy: Node, damage: int)
signal request_shake(strength: float, duration: float)

const GRAVITY: float = 760.0
const JUMP_VEL: float = -265.0
const DASH_SPEED: float = 310.0
const DASH_DURATION: float = 0.22
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.10

var facing: int = 1
var _coyote: float = 0.0
var _jump_buf: float = 0.0
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _parry_timer: float = 0.0
var _parry_cd: float = 0.0
var _iframe_timer: float = 0.0
var _attack_timer: float = 0.0
var _current_attack_anim: String = "attack1"
var _anim_time: float = 0.0
var _was_on_floor: bool = true
var _combo_step: int = 0
var _combo_reset: float = 0.0
var _hurt_timer: float = 0.0
var _hit_stop_timer: float = 0.0
var _perfect_dodge_checked: bool = false
var controls_locked: bool = false

var _sprite: AnimatedSprite2D
var _class_aura: ColorRect = null
var _outfit_tint: Color = Color.WHITE
var _shield_vfx: AnimatedSprite2D = null


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 26)
	col.shape = shape
	col.position = Vector2(0, -13)
	add_child(col)

	var outfit: Dictionary = GameData.CLASS_OUTFITS.get(GameState.current_attribute_id, {"tint": Color.WHITE, "aura": Color(0.35, 0.72, 0.95, 0.2)})
	_outfit_tint = outfit["tint"]

	_class_aura = ColorRect.new()
	_class_aura.size = Vector2(16, 3)
	_class_aura.position = Vector2(-8, -2)
	_class_aura.color = outfit["aura"]
	_class_aura.color.a = minf(0.65, _class_aura.color.a * 1.8)
	_class_aura.z_index = -1
	add_child(_class_aura)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -23)
	_sprite.scale = Vector2(0.78, 0.78)
	_sprite.modulate = _outfit_tint
	_sprite.sprite_frames = _build_frames()
	add_child(_sprite)
	_sprite.play("idle")


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var tex := SpriteLoader.load_tex(GameState.get_char_sprite_path())
	if tex == null:
		tex = SpriteLoader.load_tex("res://assets/sprites/player_sheet.png")
	if tex == null:
		return sf
	var fw := maxi(32, int(tex.get_width() / 30))
	var fh := tex.get_height()
	var defs := {
		"idle": [0, 1],
		"run": [2, 3, 4, 5],
		"jump": [6],
		"dash": [7],
		"hurt": [8],
		"parry_pose": [9],
		"attack1": [10, 11, 12],
		"attack2": [13, 14, 15],
		"attack3": [16, 17, 18],
		"attack_thrust": [19, 20, 21],
		"attack_heavy": [22, 23, 24],
		"attack_spin": [25, 26, 25],
		"attack_cast": [27, 28, 28],
		"attack_shoot": [29, 1],
	}
	for anim in defs.keys():
		sf.add_animation(anim)
		var fps := 16.0 if anim.begins_with("attack") else (8.5 if anim == "run" else 5.0)
		sf.set_animation_speed(anim, fps)
		sf.set_animation_loop(anim, anim in ["idle", "run"])
		for idx in defs[anim]:
			sf.add_frame(anim, SpriteLoader.make_atlas(tex, int(idx) * fw, 0, fw, fh))
	return sf


func is_dashing() -> bool:
	return _dash_timer > 0.0


func is_parrying() -> bool:
	return _parry_timer > 0.0


func get_facing() -> int:
	return facing


func get_current_anim() -> String:
	return _sprite.animation if _sprite != null else "idle"


func revive_coop(ratio: float = 0.55) -> void:
	var heal_amt := maxi(25, int(round(float(GameState.max_hp) * ratio)))
	GameState.hp = mini(GameState.max_hp, heal_amt)
	GameState.stats_changed.emit()
	controls_locked = false
	_iframe_timer = 1.5
	SfxManager.play("levelup")
	VfxManager.spawn_vfx("level_up", get_parent(), global_position, false, 0.50)
	spawn_floating_text("ฟื้นคืนชีพ Co-op!", Color(0.35, 1.0, 0.65))


func apply_hit_stop(duration: float) -> void:
	_hit_stop_timer = maxf(_hit_stop_timer, duration)


func _physics_process(delta: float) -> void:
	if _hit_stop_timer > 0.0:
		_hit_stop_timer -= delta
		return

	_update_shield_vfx()

	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _parry_timer > 0.0:
		_parry_timer -= delta
	if _parry_cd > 0.0:
		_parry_cd -= delta
	if _iframe_timer > 0.0:
		_iframe_timer -= delta
	if _attack_timer > 0.0:
		_attack_timer -= delta
	_anim_time += delta
	var base_sc := Vector2(0.78, 0.78)
	_sprite.scale = _sprite.scale.lerp(base_sc, minf(1.0, delta * 13.0))
	_sprite.rotation = lerpf(_sprite.rotation, 0.0, minf(1.0, delta * 14.0))
	if is_on_floor() and not _was_on_floor:
		_sprite.scale = Vector2(0.94, 0.62) # Crisp landing squash!
	_was_on_floor = is_on_floor()
	if _combo_reset > 0.0:
		_combo_reset -= delta
		if _combo_reset <= 0.0:
			_combo_step = 0
	if _hurt_timer > 0.0:
		_hurt_timer -= delta

	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if controls_locked:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		velocity.y += GRAVITY * delta
		move_and_slide()
		_update_anim()
		return

	if Input.is_action_just_pressed("jump"):
		_jump_buf = JUMP_BUFFER_TIME
	else:
		_jump_buf = maxf(0.0, _jump_buf - delta)

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0 and _dash_timer <= 0.0:
		facing = 1 if dir > 0.0 else -1
		_sprite.flip_h = facing < 0

	# Dash (left/right with i-frames + Perfect Dodge check)
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _dash_timer <= 0.0:
		_start_dash(facing if dir == 0.0 else (1 if dir > 0.0 else -1))

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = float(facing) * DASH_SPEED
		velocity.y = 0.0
		_check_perfect_dodge()
	else:
		if _jump_buf > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_VEL
			_coyote = 0.0
			_jump_buf = 0.0
			_sprite.scale = Vector2(0.82, 1.22) # Jump stretch!
			SfxManager.play("jump")
		velocity.y += GRAVITY * delta
		if Input.is_action_pressed("move_down"):
			if not is_on_floor():
				velocity.y = maxf(velocity.y, 320.0) # Fast-fall with S!
			elif position.y < 208.0:
				position.y += 4.0 # Drop through one-way luggage platform with S!
		var speed := GameState.get_move_speed()
		if _hurt_timer > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
		elif _attack_timer > 0.08:
			velocity.x = move_toward(velocity.x, float(facing) * 28.0, 500.0 * delta)
		else:
			velocity.x = dir * speed

		if Input.is_action_just_pressed("parry") and _parry_cd <= 0.0:
			_start_parry()
		elif Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
			_perform_attack()
		elif Input.is_action_just_pressed("skill_1"):
			_perform_skill(0)
		elif Input.is_action_just_pressed("skill_2"):
			_perform_skill(1)
		elif Input.is_action_just_pressed("skill_3"):
			_perform_skill(2)
		elif Input.is_action_just_pressed("stigma_skill"):
			_perform_stigma()
		elif Input.is_action_just_pressed("item_1"):
			var iid0 := GameState.quick_slots[0] if GameState.quick_slots.size() > 0 else ""
			if iid0 != "" and int(GameState.consumables.get(iid0, 0)) > 0:
				_use_quick_item(0)
			else:
				_use_quick_item(1)
		elif Input.is_action_just_pressed("item_2"):
			_use_quick_item(1)

	move_and_slide()
	_update_anim()


func _start_parry() -> void:
	if not GameState.use_stamina(20.0):
		spawn_floating_text("Stamina หมด!", Color(1.0, 0.72, 0.25))
		return
	_parry_timer = GameState.get_parry_window()
	_parry_cd = 0.46 if GameState.has_fable("fable_parry_master") else 0.62
	SfxManager.play("slash")
	spawn_floating_text("GUARD", Color(0.75, 0.92, 1.0))


func on_parry_success(attacker: Node) -> void:
	_parry_timer = 0.0
	_iframe_timer = maxf(_iframe_timer, 0.35)
	GameState.parries_landed += 1
	if GameState.parries_landed >= 5:
		GameState.unlock_fable("fable_parry_master")
	GameState.add_hype(30.0, 3)
	ScenarioManager.trigger_parry_reward()
	SfxManager.play("levelup")
	VfxManager.spawn_vfx("parry", get_parent(), global_position + Vector2(float(facing) * 14.0, -16), facing < 0, 0.48)
	VfxManager.spawn_vfx("impact_frame", get_parent(), global_position + Vector2(0, -16), false, 0.35)
	spawn_floating_text("★ PARRY! ★", Color(1.0, 0.88, 0.22))
	apply_hit_stop(0.08)
	request_shake.emit(5.0, 0.18)
	if attacker != null and is_instance_valid(attacker) and attacker.has_method("apply_stun"):
		attacker.apply_stun(1.9)
	if GameState.has_boon("parry_overdrive"):
		GameState.reduce_all_cooldowns(0.5)
		VfxManager.spawn_vfx("mana_burst", get_parent(), global_position + Vector2(0, -14), false, 0.52)
		_deal_area_damage(global_position + Vector2(0, -14), 76.0, int(GameState.get_attack_damage() * 1.8), 190.0, 0.0, true)


func _start_dash(dash_dir: int) -> void:
	if not GameState.use_stamina(28.0):
		spawn_floating_text("Stamina หมด!", Color(1.0, 0.72, 0.25))
		return
	facing = dash_dir
	_sprite.flip_h = facing < 0
	_dash_timer = DASH_DURATION
	_iframe_timer = DASH_DURATION + 0.06
	_dash_cd = GameState.get_dash_cooldown()
	_perfect_dodge_checked = false
	SfxManager.play("dash")
	VfxManager.spawn_vfx("dash_puff", get_parent(), global_position + Vector2(0, -14), facing < 0, 0.42)
	if GameState.has_boon("dash_bomb"):
		var bpos := global_position + Vector2(0, -12)
		VfxManager.spawn_vfx("fire_bomb", get_parent(), bpos, false, 0.44)
		_deal_area_damage(bpos, 56.0, int(GameState.get_attack_damage() * 1.35), 140.0, 0.0, true)
	if GameState.current_attribute_id == "shadow_assassin":
		var spos := global_position + Vector2(float(facing) * 28.0, -14)
		VfxManager.spawn_vfx("dagger_flurry", get_parent(), spos, facing < 0, 0.40)
		_deal_area_damage(spos, 42.0, int(GameState.get_attack_damage() * 0.95), 95.0, 0.0, false)


func _check_perfect_dodge() -> void:
	if _perfect_dodge_checked:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("is_attacking_danger") and enemy.is_attacking_danger():
			if global_position.distance_to(enemy.global_position) < 42.0:
				_perfect_dodge_checked = true
				ScenarioManager.trigger_perfect_dodge()
				SfxManager.play("coin")
				spawn_floating_text("PERFECT DODGE!", Color(0.22, 0.82, 1.0))
				apply_hit_stop(0.05)
				return


func _trigger_attack_motion(anim_name: String, lunge_rot: float = 0.22) -> void:
	_current_attack_anim = anim_name
	_sprite.stop()
	_sprite.animation = anim_name
	_sprite.frame = 0
	_sprite.play(anim_name)
	_sprite.scale = Vector2(1.22, 0.84)
	_sprite.rotation = float(facing) * lunge_rot


func _perform_attack() -> void:
	_combo_step = (_combo_step % 3) + 1
	_combo_reset = 0.65

	var wdata := GameState.get_weapon_data()
	var style: String = String(wdata.get("attack_style", "magic" if bool(wdata.get("is_magic", false)) else "sword"))
	var dmg := GameState.get_attack_damage()
	if _combo_step == 3:
		dmg = int(round(float(dmg) * 1.35))
	var slow_t := 2.0 if (GameState.has_boon("frost_touch") and randf() < 0.35) else 0.0

	match style:
		"dagger":
			_attack_timer = 0.16
			_current_attack_anim = "attack%d" % _combo_step
			SfxManager.play("slash")
			var pos := global_position + Vector2(float(facing) * 22.0, -14)
			VfxManager.spawn_vfx("dagger_flurry", get_parent(), pos, facing < 0, 0.42)
			_deal_area_damage(pos, 32.0, dmg, 65.0, slow_t, false)
		"heavy":
			_attack_timer = 0.34
			_current_attack_anim = "attack_heavy"
			SfxManager.play("hit")
			var pos := global_position + Vector2(float(facing) * 28.0, -12)
			VfxManager.spawn_vfx("heavy_cleave", get_parent(), pos, facing < 0, 0.46)
			_deal_area_damage(pos, 48.0, int(round(float(dmg) * 1.25)), 190.0, slow_t, false)
			request_shake.emit(3.5, 0.14)
		"spear":
			_attack_timer = 0.24
			_current_attack_anim = "attack_thrust"
			SfxManager.play("slash")
			var pos := global_position + Vector2(float(facing) * 34.0, -14)
			VfxManager.spawn_vfx("wind_slash", get_parent(), pos, facing < 0, 0.38)
			_deal_line_damage(global_position + Vector2(0, -14), float(facing), 74.0, 22.0, dmg, 135.0, false)
		"scythe":
			_attack_timer = 0.30
			_current_attack_anim = "attack_heavy"
			SfxManager.play("slash")
			var pos := global_position + Vector2(float(facing) * 28.0, -14)
			VfxManager.spawn_vfx("scythe_reap", get_parent(), pos, facing < 0, 0.50)
			_deal_area_damage(pos, 58.0, int(round(float(dmg) * 1.15)), 155.0, slow_t, false)
		"spin":
			_attack_timer = 0.24
			_current_attack_anim = "attack_spin"
			SfxManager.play("slash")
			var pos := global_position + Vector2(0, -14)
			VfxManager.spawn_vfx("spin_slash", get_parent(), pos, facing < 0, 0.52)
			_deal_area_damage(pos, 58.0, dmg, 140.0, slow_t, false)
		"bow":
			_attack_timer = 0.25
			_current_attack_anim = "attack_shoot"
			SfxManager.play("slash")
			_spawn_projectile({
				"pos": global_position + Vector2(float(facing) * 14.0, -16),
				"vel": Vector2(float(facing) * 310.0, 0.0),
				"from_player": true,
				"damage": dmg,
				"radius": 10.0,
				"life": 0.9,
				"color": Color(0.95, 0.92, 0.55),
				"dot_size": 6.0,
				"explode_vfx": "hit_spark",
				"slow_duration": slow_t,
			})
		"gun":
			_attack_timer = 0.17
			_current_attack_anim = "attack_shoot"
			SfxManager.play("hit")
			var burst := [-26.0, 0.0, 26.0] if _combo_step == 3 else [0.0]
			for vy in burst:
				_spawn_projectile({
					"pos": global_position + Vector2(float(facing) * 16.0, -16),
					"vel": Vector2(float(facing) * 330.0, vy),
					"from_player": true,
					"damage": dmg if _combo_step < 3 else int(round(float(dmg) * 0.72)),
					"radius": 9.0,
					"life": 0.85,
					"color": Color(1.0, 0.85, 0.25),
					"dot_size": 5.0,
					"explode_vfx": "hit_spark",
					"slow_duration": slow_t,
				})
		"bomb":
			_attack_timer = 0.30
			_current_attack_anim = "attack_cast"
			SfxManager.play("slash")
			_spawn_projectile({
				"pos": global_position + Vector2(float(facing) * 12.0, -20),
				"vel": Vector2(float(facing) * 155.0, -145.0),
				"gravity": 340.0,
				"from_player": true,
				"damage": dmg,
				"radius": 11.0,
				"life": 1.3,
				"color": Color(0.35, 0.95, 0.55),
				"dot_size": 7.0,
				"explode_vfx": "fire_bomb",
				"explode_radius": 46.0,
				"slow_duration": slow_t,
			})
		"pyro":
			_attack_timer = 0.28
			_current_attack_anim = "attack_cast"
			SfxManager.play("skill")
			_spawn_projectile({
				"pos": global_position + Vector2(float(facing) * 16.0, -16),
				"vel": Vector2(float(facing) * 235.0, 0.0),
				"from_player": true,
				"damage": dmg,
				"radius": 12.0,
				"life": 1.0,
				"vfx": "fireball",
				"vfx_scale": 0.32,
				"explode_vfx": "fire_bomb",
				"explode_radius": 40.0,
				"slow_duration": slow_t,
			})
		"necro":
			_attack_timer = 0.26
			_current_attack_anim = "attack_cast"
			SfxManager.play("skill")
			_spawn_projectile({
				"pos": global_position + Vector2(float(facing) * 16.0, -16),
				"vel": Vector2(float(facing) * 225.0, 0.0),
				"from_player": true,
				"damage": dmg,
				"radius": 12.0,
				"life": 1.1,
				"vfx": "dark_orb",
				"vfx_scale": 0.24,
				"explode_vfx": "hit_spark",
				"slow_duration": slow_t,
			})
		"archmage":
			_attack_timer = 0.25
			_current_attack_anim = "attack_cast"
			SfxManager.play("skill")
			for vy in [-44.0, 0.0, 44.0]:
				_spawn_projectile({
					"pos": global_position + Vector2(float(facing) * 16.0, -16),
					"vel": Vector2(float(facing) * 255.0, vy),
					"from_player": true,
					"damage": int(round(float(dmg) * 0.78)),
					"radius": 11.0,
					"life": 1.0,
					"color": Color(0.98, 0.86, 0.32) if vy == 0.0 else Color(0.35, 0.88, 1.0),
					"dot_size": 7.0,
					"explode_vfx": "hit_spark",
					"slow_duration": slow_t,
				})
		"magic":
			_attack_timer = 0.24
			_current_attack_anim = "attack_cast"
			SfxManager.play("skill")
			var wid: String = String(wdata["id"])
			var bolt_col := Color(0.4, 0.88, 1.0)
			var st := slow_t
			if wid == "apprentice_wand":
				bolt_col = Color(1.0, 0.55, 0.2)
			elif wid == "volt_staff":
				bolt_col = Color(0.95, 0.92, 0.3)
			elif wid == "frost_staff":
				bolt_col = Color(0.65, 0.95, 1.0)
				st = maxf(st, 1.4)
			_spawn_projectile({
				"pos": global_position + Vector2(float(facing) * 14.0, -16),
				"vel": Vector2(float(facing) * 240.0, 0.0),
				"from_player": true,
				"damage": dmg,
				"radius": 11.0,
				"life": 0.95,
				"color": bolt_col,
				"dot_size": 7.0,
				"explode_vfx": "hit_spark",
				"slow_duration": st,
			})
		_:
			_attack_timer = 0.23
			_current_attack_anim = "attack%d" % _combo_step
			SfxManager.play("slash")
			var reach := float(wdata.get("range", 28.0))
			var hit_center := global_position + Vector2(float(facing) * (reach * 0.72), -14)
			VfxManager.spawn_vfx("slash", get_parent(), hit_center, facing < 0, 0.42 if _combo_step < 3 else 0.52)
			_deal_area_damage(hit_center, reach * 0.85, dmg, 130.0 if _combo_step == 3 else 75.0, slow_t, false)

	if _combo_step == 3 and GameState.has_boon("third_hit_lightning"):
		var vpos := global_position + Vector2(float(facing) * 52.0, -16)
		VfxManager.spawn_vfx("lightning", get_parent(), vpos, facing < 0, 0.46)
		_deal_line_damage(global_position + Vector2(0, -14), float(facing), 110.0, 26.0, int(dmg * 1.25), 140.0, true)

	# Restart non-looping attack animation from frame 0 with snappy body lean!
	var rot := -0.16 if style in ["bow", "gun"] else (0.32 if style == "spin" else 0.22)
	_trigger_attack_motion(_current_attack_anim, rot)


func _play_skill_spectacle(skill_name: String, aura_vfx: String, accent_col: Color, shake_str: float = 4.5) -> void:
	_trigger_attack_motion("attack_cast", 0.24)
	_sprite.scale = Vector2(1.32, 0.80)
	VfxManager.spawn_vfx(aura_vfx, get_parent(), global_position + Vector2(0, -16), facing < 0, 0.72)
	VfxManager.spawn_vfx("impact_frame", get_parent(), global_position + Vector2(float(facing) * 18.0, -16), facing < 0, 0.56)
	spawn_floating_text("★ %s! ★" % skill_name, accent_col)
	apply_hit_stop(0.04)
	request_shake.emit(shake_str, 0.20)
	if NetworkManager.is_online:
		NetworkManager.send_player_fx(aura_vfx, global_position + Vector2(0, -16), facing, 0.72)


func _perform_skill(slot_idx: int) -> void:
	var data := GameState.consume_skill(slot_idx)
	if data.is_empty():
		return
	var sid: String = data["id"]
	var sname: String = String(data.get("name", sid))
	SfxManager.play("skill")
	_attack_timer = 0.30
	_play_skill_spectacle(sname, "mana_burst", Color(0.45, 0.94, 1.0), 4.6)

	if sid == "desperate_slash":
		var pos := global_position + Vector2(float(facing) * 32.0, -14)
		VfxManager.spawn_vfx("slash", get_parent(), pos, facing < 0, 0.88)
		VfxManager.spawn_vfx("wind_slash", get_parent(), pos + Vector2(float(facing) * 14.0, 0), facing < 0, 0.66)
		_deal_area_damage(pos, 46.0, GameState.get_skill_damage(sid), 185.0)
		request_shake.emit(4.8, 0.20)
	elif sid == "wind_slash":
		velocity.x = float(facing) * 260.0
		_iframe_timer = maxf(_iframe_timer, 0.24)
		var pos := global_position + Vector2(float(facing) * 34.0, -14)
		VfxManager.spawn_vfx("wind_slash", get_parent(), pos, facing < 0, 0.85)
		VfxManager.spawn_vfx("dash_puff", get_parent(), global_position + Vector2(0, -14), facing < 0, 0.65)
		_deal_area_damage(pos, 54.0, GameState.get_skill_damage(sid), 165.0)
		request_shake.emit(5.0, 0.22)
	elif sid == "fireball":
		VfxManager.spawn_vfx("fire_bomb", get_parent(), global_position + Vector2(float(facing) * 16.0, -16), false, 0.45)
		_spawn_projectile({
			"pos": global_position + Vector2(float(facing) * 18.0, -16),
			"vel": Vector2(float(facing) * 235.0, 0.0),
			"from_player": true,
			"damage": GameState.get_skill_damage(sid),
			"radius": 16.0,
			"life": 1.5,
			"vfx": "fireball",
			"vfx_scale": 0.68,
			"explode_vfx": "fire_bomb",
			"explode_radius": 66.0,
			"knockback": 175.0,
		})
		request_shake.emit(4.2, 0.18)
	elif sid == "lightning_bolt":
		var vpos := global_position + Vector2(float(facing) * 60.0, -16)
		VfxManager.spawn_vfx("lightning", get_parent(), vpos, facing < 0, 0.82)
		VfxManager.spawn_vfx("lightning", get_parent(), vpos + Vector2(float(facing) * 44.0, -8), facing < 0, 0.68)
		_deal_line_damage(global_position + Vector2(0, -14), float(facing), 140.0, 32.0, GameState.get_skill_damage(sid), 190.0)
		request_shake.emit(6.2, 0.24)
	elif sid == "frost_nova":
		var pos := global_position + Vector2(0, -12)
		VfxManager.spawn_vfx("frost_nova", get_parent(), pos, false, 0.85)
		VfxManager.spawn_vfx("ground_slam", get_parent(), pos, false, 0.68)
		_deal_area_damage(pos, 88.0, GameState.get_skill_damage(sid), 155.0, 2.8)
		request_shake.emit(5.6, 0.24)
	elif sid == "mana_burst":
		var pos := global_position + Vector2(0, -14)
		VfxManager.spawn_vfx("mana_burst", get_parent(), pos, false, 0.90)
		VfxManager.spawn_vfx("level_up", get_parent(), pos, false, 0.75)
		_deal_area_damage(pos, 74.0, GameState.get_skill_damage(sid), 230.0)
		request_shake.emit(6.5, 0.26)
	elif sid == "magic_barrier":
		spawn_floating_text("เกราะพลังเวท!", Color(0.45, 0.88, 1.0))
	# --- +20 New Skills Execution (Damage, Control, Buff, Debuff) ---
	elif sid == "meteor_drop":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(float(facing) * 68.0, -14)
		VfxManager.spawn_vfx("fire_bomb", get_parent(), pos, false, 0.75)
		VfxManager.spawn_vfx("ground_slam", get_parent(), pos + Vector2(0, 14), false, 0.58)
		_deal_area_damage(pos, 82.0, GameState.get_skill_damage(sid), 210.0)
		request_shake.emit(6.5, 0.25)
	elif sid == "void_lance":
		_current_attack_anim = "attack_thrust"
		var vpos := global_position + Vector2(float(facing) * 60.0, -16)
		VfxManager.spawn_vfx("dark_orb", get_parent(), vpos, facing < 0, 0.48)
		_deal_line_damage(global_position + Vector2(0, -14), float(facing), 145.0, 30.0, GameState.get_skill_damage(sid), 150.0, true, "armor_break", 6.0)
		request_shake.emit(4.0, 0.16)
	elif sid == "blade_storm":
		_current_attack_anim = "attack_spin"
		var pos := global_position + Vector2(0, -14)
		VfxManager.spawn_vfx("spin_slash", get_parent(), pos, facing < 0, 0.68)
		_deal_area_damage(pos, 72.0, GameState.get_skill_damage(sid), 170.0)
		request_shake.emit(4.5, 0.18)
	elif sid == "shadow_reap":
		_current_attack_anim = "attack_heavy"
		var pos := global_position + Vector2(float(facing) * 34.0, -14)
		VfxManager.spawn_vfx("scythe_reap", get_parent(), pos, facing < 0, 0.64)
		var dmg := GameState.get_skill_damage(sid)
		_deal_area_damage(pos, 66.0, dmg, 165.0)
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + maxi(8, int(round(float(dmg) * 0.20))))
		GameState.hp_mp_changed.emit()
		spawn_floating_text("ดูดวิญญาณ!", Color(0.82, 0.45, 1.0))
	elif sid == "sonic_pierce":
		_current_attack_anim = "attack_thrust"
		velocity.x = float(facing) * 260.0
		var vpos := global_position + Vector2(float(facing) * 48.0, -14)
		VfxManager.spawn_vfx("wind_slash", get_parent(), vpos, facing < 0, 0.56)
		_deal_line_damage(global_position + Vector2(0, -14), float(facing), 120.0, 26.0, GameState.get_skill_damage(sid), 165.0, true)
	elif sid == "chain_zap":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(float(facing) * 46.0, -16)
		VfxManager.spawn_vfx("lightning", get_parent(), pos, facing < 0, 0.58)
		_apply_cc_area(pos, 95.0, GameState.get_skill_damage(sid), "stun", 1.0)
	elif sid == "gravity_well":
		_current_attack_anim = "attack_cast"
		var center := global_position + Vector2(float(facing) * 64.0, -14)
		VfxManager.spawn_vfx("dark_orb", get_parent(), center, false, 0.58)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(center) <= 165.0:
				if enemy.has_method("pull_toward"):
					enemy.pull_toward(center.x, 0.72)
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(3.0)
		_deal_area_damage(center, 95.0, GameState.get_skill_damage(sid), 20.0, 3.0)
		spawn_floating_text("หลุมดำดึงดูด!", Color(0.75, 0.45, 1.0))
	elif sid == "flash_bang":
		var pos := global_position + Vector2(0, -16)
		VfxManager.spawn_vfx("impact_frame", get_parent(), pos, false, 0.46)
		_apply_cc_area(pos, 110.0, GameState.get_skill_damage(sid), "stun", 2.2)
		spawn_floating_text("FLASH STUN!", Color(1.0, 0.95, 0.45))
	elif sid == "ice_prison":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(float(facing) * 48.0, -14)
		VfxManager.spawn_vfx("frost_nova", get_parent(), pos, false, 0.52)
		_apply_cc_area(pos, 86.0, GameState.get_skill_damage(sid), "stun", 1.8)
		_deal_area_damage(pos, 86.0, 1, 20.0, 3.0)
		spawn_floating_text("คุกน้ำแข็ง!", Color(0.55, 0.95, 1.0))
	elif sid == "shockwave_push":
		var pos := global_position + Vector2(0, -10)
		VfxManager.spawn_vfx("ground_slam", get_parent(), pos, false, 0.56)
		_deal_area_damage(pos, 96.0, GameState.get_skill_damage(sid), 320.0, 1.8)
		request_shake.emit(5.0, 0.18)
	elif sid == "earth_bind":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(float(facing) * 45.0, 0)
		VfxManager.spawn_vfx("ground_slam", get_parent(), pos, false, 0.50)
		_apply_cc_area(pos + Vector2(0, -14), 105.0, GameState.get_skill_damage(sid), "stun", 2.5)
		spawn_floating_text("ตรึงปฐพี!", Color(0.85, 0.68, 0.35))
	elif sid == "battle_cry":
		GameState.buff_atk_timer = 8.0
		VfxManager.spawn_vfx("level_up", get_parent(), global_position, false, 0.44)
		spawn_floating_text("ATK +40% (8s)!", Color(1.0, 0.55, 0.25))
	elif sid == "haste_aura":
		GameState.buff_haste_timer = 8.0
		VfxManager.spawn_vfx("dash_puff", get_parent(), global_position + Vector2(0, -14), false, 0.50)
		spawn_floating_text("HASTE +45% (8s)!", Color(0.35, 0.95, 0.85))
	elif sid == "iron_skin":
		GameState.buff_iron_timer = 7.0
		VfxManager.spawn_vfx("shield_aura", get_parent(), global_position + Vector2(0, -14), false, 0.48)
		spawn_floating_text("IRON SKIN -50% DMG!", Color(0.75, 0.85, 1.0))
	elif sid == "arcane_surge":
		GameState.buff_arcane_timer = 8.0
		GameState.mp = mini(GameState.get_max_mp(), GameState.mp + 25)
		GameState.hp_mp_changed.emit()
		VfxManager.spawn_vfx("mana_burst", get_parent(), global_position + Vector2(0, -14), false, 0.48)
		spawn_floating_text("ARCANE +45% & +25MP!", Color(0.45, 0.75, 1.0))
	elif sid == "second_wind":
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + 35)
		GameState.stamina = GameState.MAX_STAMINA
		GameState.hp_mp_changed.emit()
		VfxManager.spawn_vfx("level_up", get_parent(), global_position, false, 0.44)
		spawn_floating_text("+35 HP & FULL STA!", Color(0.35, 1.0, 0.55))
	elif sid == "armor_break":
		_current_attack_anim = "attack_heavy"
		var pos := global_position + Vector2(float(facing) * 36.0, -14)
		VfxManager.spawn_vfx("heavy_cleave", get_parent(), pos, facing < 0, 0.48)
		_apply_debuff_area(pos, 72.0, GameState.get_skill_damage(sid), "armor_break", 7.0)
		spawn_floating_text("ARMOR BREAK!", Color(1.0, 0.65, 0.25))
	elif sid == "curse_weaken":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(0, -14)
		VfxManager.spawn_vfx("dark_orb", get_parent(), pos, false, 0.50)
		_apply_debuff_area(pos, 115.0, GameState.get_skill_damage(sid), "weaken", 7.0)
		spawn_floating_text("WEAKEN -40%!", Color(0.78, 0.45, 1.0))
	elif sid == "venom_cloud":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(float(facing) * 32.0, -14)
		VfxManager.spawn_vfx("mana_burst", get_parent(), pos, false, 0.50)
		_apply_debuff_area(pos, 95.0, GameState.get_skill_damage(sid), "poison", 6.0)
		spawn_floating_text("POISON CLOUD!", Color(0.35, 0.96, 0.45))
	elif sid == "mark_of_death":
		_current_attack_anim = "attack_cast"
		var pos := global_position + Vector2(float(facing) * 44.0, -14)
		VfxManager.spawn_vfx("scythe_reap", get_parent(), pos, facing < 0, 0.52)
		_apply_debuff_area(pos, 86.0, GameState.get_skill_damage(sid), "death_mark", 6.0)
		spawn_floating_text("DEATH MARK +60%!", Color(1.0, 0.25, 0.45))


func _apply_cc_area(center: Vector2, radius: float, dmg: int, cc_kind: String, duration: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var epos: Vector2 = enemy.global_position + Vector2(0, -14)
			if center.distance_to(epos) <= radius:
				enemy.take_damage(dmg, 0.0, true)
				if cc_kind == "stun" and enemy.has_method("apply_stun"):
					enemy.apply_stun(duration)
				GameState.add_hype(6.0, 1)


func _apply_debuff_area(center: Vector2, radius: float, dmg: int, debuff_kind: String, duration: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var epos: Vector2 = enemy.global_position + Vector2(0, -14)
			if center.distance_to(epos) <= radius:
				if enemy.has_method("apply_debuff"):
					enemy.apply_debuff(debuff_kind, duration)
				enemy.take_damage(dmg, 0.0, true)
				GameState.add_hype(6.0, 1)


func _perform_stigma() -> void:
	var data := GameState.consume_stigma()
	if data.is_empty():
		return
	var sid: String = data["id"]
	var dmg: int = GameState.get_stigma_damage()
	SfxManager.play("levelup")
	SfxManager.play("skill")
	_attack_timer = 0.34
	_play_skill_spectacle(String(data["name"]), "level_up", Color(1.0, 0.88, 0.22), 7.5)

	if sid == "stigma_moonlight":
		var vpos := global_position + Vector2(float(facing) * 62.0, -16)
		VfxManager.spawn_vfx("wind_slash", get_parent(), vpos, facing < 0, 0.98)
		VfxManager.spawn_vfx("lightning", get_parent(), vpos + Vector2(float(facing) * 40.0, -4), facing < 0, 0.80)
		_deal_line_damage(global_position + Vector2(0, -14), float(facing), 185.0, 38.0, dmg, 210.0)
		request_shake.emit(7.5, 0.28)
	elif sid == "stigma_shadow":
		VfxManager.spawn_vfx("dash_puff", get_parent(), global_position + Vector2(0, -14), facing < 0, 0.72)
		_iframe_timer = maxf(_iframe_timer, 0.40)
		global_position.x = clampf(global_position.x + float(facing) * 95.0, 24.0, 1596.0)
		VfxManager.spawn_vfx("dark_orb", get_parent(), global_position + Vector2(0, -16), facing < 0, 0.85)
		VfxManager.spawn_vfx("scythe_reap", get_parent(), global_position + Vector2(float(facing) * 20.0, -14), facing < 0, 0.85)
		_deal_area_damage(global_position + Vector2(0, -14), 82.0, dmg, 195.0)
		request_shake.emit(6.8, 0.24)
	elif sid == "stigma_flame":
		VfxManager.spawn_vfx("fire_bomb", get_parent(), global_position + Vector2(0, -16), false, 1.05)
		VfxManager.spawn_vfx("ground_slam", get_parent(), global_position, false, 0.85)
		VfxManager.spawn_vfx("fire_bomb", get_parent(), global_position + Vector2(float(facing) * 48.0, -14), false, 0.75)
		_deal_area_damage(global_position + Vector2(0, -14), 108.0, dmg, 250.0)
		request_shake.emit(8.5, 0.30)
	elif sid == "stigma_will":
		VfxManager.spawn_vfx("mana_burst", get_parent(), global_position + Vector2(0, -14), false, 1.02)
		VfxManager.spawn_vfx("frost_nova", get_parent(), global_position + Vector2(0, -12), false, 0.80)
		_deal_area_damage(global_position + Vector2(0, -14), 98.0, dmg, 240.0)
		request_shake.emit(7.5, 0.26)


func _spawn_projectile(opts: Dictionary) -> void:
	var proj := Node2D.new()
	proj.set_script(ProjectileScript)
	get_parent().add_child(proj)
	proj.setup(opts)


func _deal_line_damage(origin: Vector2, dir: float, length: float, half_h: float, dmg: int, knockback: float, is_skill: bool = true, debuff: String = "", debuff_dur: float = 0.0) -> void:
	var hit_any := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var epos: Vector2 = enemy.global_position + Vector2(0, -14)
		var dx := (epos.x - origin.x) * dir
		if dx >= -8.0 and dx <= length and absf(epos.y - origin.y) <= half_h:
			if debuff != "" and enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff, debuff_dur)
			enemy.take_damage(dmg, dir * knockback, is_skill or _combo_step == 3)
			VfxManager.spawn_vfx("hit_spark", get_parent(), epos, dir < 0.0, 0.40)
			spawn_floating_text_at(epos + Vector2(0, -12), "-%d" % dmg, Color(0.95, 0.92, 0.35))
			hit_enemy.emit(enemy, dmg)
			GameState.add_hype(6.0, 1)
			if (is_skill and GameState.has_boon("stigma_lifesteal")) or GameState.current_attribute_id == "reaper":
				var pct := 0.15 if (is_skill and GameState.has_boon("stigma_lifesteal")) else 0.12
				GameState.hp = mini(GameState.get_max_hp(), GameState.hp + maxi(1, int(round(float(dmg) * pct))))
				GameState.hp_mp_changed.emit()
			hit_any = true
	if hit_any:
		SfxManager.play("hit")
		apply_hit_stop(0.05)


func _use_quick_item(slot_idx: int) -> void:
	var data := GameState.use_consumable(slot_idx)
	if data.is_empty():
		return
	var kind: String = data["kind"]
	if kind == "heal_hp":
		SfxManager.play("levelup")
		spawn_floating_text("+HP", Color(0.3, 0.95, 0.45))
	elif kind == "heal_mp":
		SfxManager.play("coin")
		spawn_floating_text("+MP", Color(0.35, 0.8, 1.0))
	elif kind == "bomb":
		SfxManager.play("skill")
		var pos := global_position + Vector2(float(facing) * 34.0, -14)
		VfxManager.spawn_vfx("fire_bomb", get_parent(), pos, false, 0.52)
		_deal_area_damage(pos, 68.0, int(data["power"]) + int(GameState.stats["mag"]) * 5, 200.0)
		request_shake.emit(5.5, 0.25)


func _deal_area_damage(center: Vector2, radius: float, dmg: int, knockback: float, slow_duration: float = 0.0, is_skill: bool = true) -> void:
	var hit_any := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var epos: Vector2 = enemy.global_position + Vector2(0, -14)
		if center.distance_to(epos) <= radius:
			var kb_dir := 1.0 if epos.x >= global_position.x else -1.0
			enemy.take_damage(dmg, kb_dir * knockback, is_skill or _combo_step == 3)
			if slow_duration > 0.0 and enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_duration)
			VfxManager.spawn_vfx("hit_spark", get_parent(), epos, kb_dir < 0.0, 0.40)
			spawn_floating_text_at(epos + Vector2(0, -12), "-%d" % dmg, Color(0.65, 0.95, 1.0) if slow_duration > 0.0 else Color(1.0, 0.92, 0.35))
			hit_enemy.emit(enemy, dmg)
			GameState.add_hype(5.0, 1)
			if (is_skill and GameState.has_boon("stigma_lifesteal")) or GameState.current_attribute_id == "reaper":
				var pct := 0.15 if (is_skill and GameState.has_boon("stigma_lifesteal")) else 0.12
				GameState.hp = mini(GameState.get_max_hp(), GameState.hp + maxi(1, int(round(float(dmg) * pct))))
				GameState.hp_mp_changed.emit()
			hit_any = true
	if hit_any:
		SfxManager.play("hit")
		apply_hit_stop(0.05)
		request_shake.emit(2.2, 0.10)


func take_damage(raw_damage: int, knockback_x: float, attacker: Node = null, unparryable: bool = false) -> void:
	if _parry_timer > 0.0:
		if not unparryable:
			on_parry_success(attacker)
			return
		else:
			spawn_floating_text("ปัดไม่ได้! (RED)", Color(1.0, 0.22, 0.22))
	if _iframe_timer > 0.0 or GameState.hp <= 0:
		if _dash_timer > 0.0 and not _perfect_dodge_checked:
			_perfect_dodge_checked = true
			GameState.add_hype(22.0, 2)
			ScenarioManager.trigger_perfect_dodge()
			SfxManager.play("coin")
			spawn_floating_text("PERFECT DODGE!", Color(0.22, 0.82, 1.0))
		return
	var dealt := GameState.apply_damage(raw_damage)
	_iframe_timer = 0.36
	_hurt_timer = 0.22
	velocity.x = knockback_x
	velocity.y = -95.0
	SfxManager.play("hurt")
	request_shake.emit(4.2, 0.18)
	if dealt > 0:
		GameState.on_player_hit_hype_drop()
		ScenarioManager.notify_player_took_damage()
		spawn_floating_text("-%d" % dealt, Color(1.0, 0.32, 0.32))
	else:
		spawn_floating_text("BLOCKED!", Color(0.4, 0.88, 1.0))
	if GameState.hp <= 0:
		player_died.emit()


func play_levelup_vfx() -> void:
	VfxManager.spawn_vfx("level_up", get_parent(), global_position, false, 0.45)
	SfxManager.play("levelup")
	spawn_floating_text("STAT UP!", Color(1.0, 0.85, 0.25))


func spawn_floating_text(text: String, color: Color) -> void:
	spawn_floating_text_at(global_position + Vector2(0, -30), text, color)


func spawn_floating_text_at(pos: Vector2, text: String, color: Color) -> void:
	var ft := Node2D.new()
	ft.set_script(FloatingTextScript)
	ft.position = pos
	get_parent().add_child(ft)
	ft.setup(text, color)


func _update_shield_vfx() -> void:
	if GameState.shield_hp > 0 and _shield_vfx == null:
		_shield_vfx = VfxManager.spawn_vfx("shield_aura", self, Vector2(0, -14), false, 0.46)
	elif GameState.shield_hp <= 0 and _shield_vfx != null:
		_shield_vfx.queue_free()
		_shield_vfx = null


func _update_anim() -> void:
	var target := "idle"
	if _hurt_timer > 0.0:
		target = "hurt"
	elif _parry_timer > 0.0:
		target = "parry_pose"
	elif _dash_timer > 0.0:
		target = "dash"
	elif _attack_timer > 0.0:
		target = _current_attack_anim
	elif not is_on_floor():
		target = "jump"
	elif absf(velocity.x) > 8.0:
		target = "run"

	if _sprite.animation != target:
		_sprite.play(target)

	# Dynamic run bounce, forward lean, and idle breathing!
	if target == "run":
		var bounce := -absf(sin(_anim_time * 16.0)) * 2.5
		_sprite.position = Vector2(0, -23.0 + bounce)
		_sprite.rotation = lerpf(_sprite.rotation, float(facing) * 0.09, 0.25)
	elif target == "idle":
		var breath := sin(_anim_time * 4.5) * 0.03
		_sprite.position = Vector2(0, -23.0)
		_sprite.scale = Vector2(0.78 - breath * 0.5, 0.78 + breath)
	else:
		_sprite.position = Vector2(0, -23.0)

	var col := _outfit_tint
	col.a = 0.55 if (_iframe_timer > 0.0 and int(_iframe_timer * 20.0) % 2 == 0) else 1.0
	_sprite.modulate = col
