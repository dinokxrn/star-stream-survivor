extends CharacterBody2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const UiTheme = preload("res://scripts/ui/UiTheme.gd")

const GRAVITY: float = 760.0

var comp_id: String = "yuna" # yuna (support/healer), jaehoon (vanguard melee)
var facing: int = 1
var _attack_cd: float = 0.0
var _heal_cd: float = 7.0
var _sprite: Sprite2D
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

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = SpriteLoader.load_tex("res://assets/sprites/npc_survivor.png")
	_sprite.position = Vector2(0, -19)
	_sprite.modulate = Color(0.85, 1.0, 0.95) if comp_id == "yuna" else Color(1.0, 0.88, 0.72)
	add_child(_sprite)

	_name_lbl = Label.new()
	_name_lbl.text = "ซอ ยูนา" if comp_id == "yuna" else "พัค แจฮุน"
	_name_lbl.position = Vector2(-22, -40)
	_name_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	_name_lbl.add_theme_font_size_override("font_size", 9)
	_name_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72))
	add_child(_name_lbl)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _heal_cd > 0.0:
		_heal_cd -= delta

	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
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
