extends CharacterBody2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const UiTheme = preload("res://scripts/ui/UiTheme.gd")

const GRAVITY: float = 760.0

var comp_id: String = "yuna" # yuna (support/healer), jaehoon (vanguard melee), constellation (OP Stage 19-20 descent)
var facing: int = 1
var _attack_cd: float = 0.0
var _heal_cd: float = 7.0
var _combo_hits: int = 0
var _float_t: float = 0.0
var _sprite: Sprite2D
var _aura_ring: ColorRect = null
var _name_lbl: Label


func setup(p_comp_id: String, pos: Vector2) -> void:
	comp_id = p_comp_id
	position = pos
	add_to_group("companions")
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 24)
	col.shape = shape
	col.position = Vector2(0, -12)
	add_child(col)

	var is_constellation := comp_id == "constellation"
	if is_constellation:
		_aura_ring = ColorRect.new()
		_aura_ring.size = Vector2(44, 52)
		_aura_ring.position = Vector2(-22, -48)
		_aura_ring.color = Color(1.0, 0.86, 0.25, 0.24)
		add_child(_aura_ring)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = SpriteLoader.load_tex("res://assets/sprites/npc_survivor.png")
	_sprite.position = Vector2(0, -28 if is_constellation else -19)
	if is_constellation:
		_sprite.scale = Vector2(1.55, 1.55)
		_sprite.modulate = Color(1.35, 1.18, 0.65, 1.0)
	else:
		_sprite.modulate = Color(0.85, 1.0, 0.95) if comp_id == "yuna" else Color(1.0, 0.88, 0.72)
	add_child(_sprite)

	_name_lbl = Label.new()
	if is_constellation:
		var sp_name: String = GameData.SPONSORS.get(GameState.selected_sponsor_id, {}).get("name", "")
		if sp_name == "" or GameState.selected_sponsor_id == "none":
			sp_name = "เทวทูตผู้พิพากษาแห่งเพลิง"
		_name_lbl.text = "★ %s (ลงจุติ) ★" % sp_name
		_name_lbl.position = Vector2(-68, -64)
		_name_lbl.add_theme_font_size_override("font_size", 10)
		_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	else:
		_name_lbl.text = "ซอ ยูนา" if comp_id == "yuna" else "พัค แจฮุน"
		_name_lbl.position = Vector2(-22, -40)
		_name_lbl.add_theme_font_size_override("font_size", 9)
		_name_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72))
	_name_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	add_child(_name_lbl)


func _physics_process(delta: float) -> void:
	_float_t += delta
	velocity.y += GRAVITY * delta
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _heal_cd > 0.0:
		_heal_cd -= delta

	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		move_and_slide()
		return

	# OP Constellation Avatar Descent AI (Stages 19-20)
	if comp_id == "constellation":
		_sprite.position.y = -28.0 + sin(_float_t * 5.0) * 4.0
		if _aura_ring != null:
			_aura_ring.color.a = 0.20 + sin(_float_t * 8.0) * 0.10
		var c_target: Node2D = null
		var c_best: float = 480.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_method("take_damage"):
				var d := global_position.distance_to(e.global_position)
				if d < c_best:
					c_best = d
					c_target = e
		if c_target != null:
			var dx := c_target.global_position.x - global_position.x
			facing = 1 if dx >= 0.0 else -1
			_sprite.flip_h = facing < 0
			if absf(dx) > 95.0:
				# Blink-dash straight into combat!
				velocity.x = float(facing) * 290.0
			else:
				velocity.x = 0.0
			if absf(dx) <= 105.0 and _attack_cd <= 0.0:
				_attack_cd = 0.42
				_combo_hits += 1
				var base_dmg := 420 + (int(GameState.stats["str"]) + int(GameState.stats["mag"])) * 12
				var is_ult := (_combo_hits % 4 == 0)
				var aoe_r := 165.0 if is_ult else 110.0
				var dmg := int(round(float(base_dmg) * (2.2 if is_ult else 1.0)))
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.has_method("take_damage") and global_position.distance_to(e.global_position) <= aoe_r:
						e.take_damage(dmg, float(facing) * (210.0 if is_ult else 130.0))
						if is_ult and e.has_method("apply_stun"):
							e.apply_stun(1.4)
				if is_ult:
					VfxManager.spawn_vfx("fire_bomb", get_parent(), c_target.global_position + Vector2(0, -16), false, 1.15)
					VfxManager.spawn_vfx("lightning", get_parent(), c_target.global_position + Vector2(0, -24), false, 1.05)
					VfxManager.spawn_vfx("impact_frame", get_parent(), c_target.global_position, false, 0.85)
					SfxManager.play("skill")
					var h_amt := int(round(float(GameState.get_max_hp()) * 0.35))
					GameState.hp = mini(GameState.get_max_hp(), GameState.hp + h_amt)
					GameState.shield_hp = maxi(GameState.shield_hp, 80)
					GameState.hp_mp_changed.emit()
					if player.has_method("spawn_floating_text"):
						player.spawn_floating_text("★ เพลิงพิพากษา! +%d HP ★" % h_amt, Color(1.0, 0.88, 0.25))
				else:
					VfxManager.spawn_vfx("lightning", get_parent(), c_target.global_position + Vector2(0, -16), facing < 0, 0.65)
					VfxManager.spawn_vfx("slash", get_parent(), c_target.global_position + Vector2(0, -14), facing < 0, 0.72)
					SfxManager.play("slash")
		else:
			var want_x: float = player.global_position.x - 36.0
			var dx := want_x - global_position.x
			if absf(dx) > 16.0:
				facing = 1 if dx >= 0.0 else -1
				_sprite.flip_h = facing < 0
				velocity.x = float(facing) * 210.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return

	# Yuna periodic heal when player is hurt (hardcore balanced: 18s CD)
	if comp_id == "yuna" and _heal_cd <= 0.0 and GameState.hp < int(GameState.get_max_hp() * 0.72):
		_heal_cd = 18.0
		var heal := 14
		GameState.hp = mini(GameState.get_max_hp(), GameState.hp + heal)
		GameState.hp_mp_changed.emit()
		SfxManager.play("levelup")
		VfxManager.spawn_vfx("shield_aura", get_parent(), player.global_position + Vector2(0, -14), false, 0.34)
		if player.has_method("spawn_floating_text"):
			player.spawn_floating_text("ยูนาฮีล +%d HP!" % heal, Color(0.4, 1.0, 0.65))

	# Find nearest enemy within 185 px
	var target: Node2D = null
	var best_dist: float = 185.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			var d := global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				target = e

	var follow_offset := -28.0 if comp_id == "yuna" else 28.0
	var dist_to_player := absf(player.global_position.x - global_position.x)
	if dist_to_player > 230.0:
		# Teleport catch-up if player dashed far ahead
		global_position = player.global_position + Vector2(follow_offset, 0)
		velocity.x = 0.0
	elif target != null and dist_to_player < 190.0:
		var dx := target.global_position.x - global_position.x
		facing = 1 if dx >= 0.0 else -1
		_sprite.flip_h = facing < 0
		var reach := 36.0 if comp_id == "jaehoon" else 52.0
		if absf(dx) <= reach:
			velocity.x = 0.0
			if _attack_cd <= 0.0:
				_attack_cd = 0.95 if comp_id == "jaehoon" else 1.20
				var dmg := (20 if comp_id == "jaehoon" else 15) + int(GameState.stats["str"]) * 2
				if GameState.has_fable("fable_saviour"):
					dmg = int(round(float(dmg) * 1.4))
				target.take_damage(dmg, float(facing) * 85.0)
				VfxManager.spawn_vfx("slash" if comp_id == "jaehoon" else "hit_spark", get_parent(), target.global_position + Vector2(0, -14), facing < 0, 0.36)
				SfxManager.play("slash")
		else:
			velocity.x = float(facing) * 125.0
	else:
		var want_x: float = player.global_position.x + follow_offset
		var dx := want_x - global_position.x
		if absf(dx) > 10.0:
			facing = 1 if dx >= 0.0 else -1
			_sprite.flip_h = facing < 0
			velocity.x = float(facing) * 128.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	move_and_slide()
