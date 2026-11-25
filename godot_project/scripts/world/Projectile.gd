extends Node2D

var vel: Vector2 = Vector2.ZERO
var gravity: float = 0.0
var from_player: bool = true
var damage: int = 12
var radius: float = 12.0
var life: float = 1.6
var explode_vfx: String = "hit_spark"
var explode_radius: float = 0.0
var slow_duration: float = 0.0
var knockback: float = 95.0

var _vfx_sprite: AnimatedSprite2D = null
var _dot: ColorRect = null


func setup(opts: Dictionary) -> void:
	position = opts.get("pos", Vector2.ZERO)
	vel = opts.get("vel", Vector2(220, 0))
	gravity = float(opts.get("gravity", 0.0))
	from_player = bool(opts.get("from_player", true))
	damage = int(opts.get("damage", 12))
	radius = float(opts.get("radius", 13.0))
	life = float(opts.get("life", 1.5))
	explode_vfx = String(opts.get("explode_vfx", "hit_spark"))
	explode_radius = float(opts.get("explode_radius", 0.0))
	slow_duration = float(opts.get("slow_duration", 0.0))
	knockback = float(opts.get("knockback", 95.0))

	var vfx_name: String = String(opts.get("vfx", ""))
	if vfx_name != "" and VfxManager.has_vfx(vfx_name):
		_vfx_sprite = VfxManager.spawn_vfx(vfx_name, self, Vector2.ZERO, vel.x < 0.0, float(opts.get("vfx_scale", 0.36)))
	else:
		_dot = ColorRect.new()
		var sz := float(opts.get("dot_size", 7.0))
		_dot.size = Vector2(sz, sz)
		_dot.position = Vector2(-sz * 0.5, -sz * 0.5)
		_dot.color = opts.get("color", Color(0.4, 0.88, 1.0))
		_dot.z_index = 26
		add_child(_dot)


func _physics_process(delta: float) -> void:
	vel.y += gravity * delta
	position += vel * delta
	life -= delta

	# Floor impact for arcing projectiles
	if position.y >= 210.0 and gravity > 0.0:
		_detonate()
		return
	if life <= 0.0 or position.x < -10.0 or position.x > 1630.0:
		queue_free()
		return

	if from_player:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
				continue
			var epos: Vector2 = enemy.global_position + Vector2(0, -14)
			if global_position.distance_to(epos) <= radius + 12.0:
				_hit_enemy_target(enemy)
				return
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			var ppos: Vector2 = player.global_position + Vector2(0, -14)
			if global_position.distance_to(ppos) <= radius + 12.0:
				if player.has_method("is_parrying") and player.is_parrying():
					from_player = true
					vel.x = -vel.x * 1.45
					vel.y = -absf(vel.y) * 0.35
					gravity = 0.0
					damage = int(round(float(damage) * 2.4))
					life = 1.6
					if _vfx_sprite != null:
						_vfx_sprite.flip_h = vel.x < 0.0
					player.on_parry_success(null)
					return
				var kb_dir := 1.0 if vel.x >= 0.0 else -1.0
				player.take_damage(damage, kb_dir * knockback)
				_detonate()
				return


func _hit_enemy_target(primary_enemy: Node) -> void:
	var kb_dir := 1.0 if vel.x >= 0.0 else -1.0
	if explode_radius > 0.0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var epos: Vector2 = enemy.global_position + Vector2(0, -14)
				if global_position.distance_to(epos) <= explode_radius:
					enemy.take_damage(damage, kb_dir * knockback)
					if slow_duration > 0.0 and enemy.has_method("apply_slow"):
						enemy.apply_slow(slow_duration)
	else:
		primary_enemy.take_damage(damage, kb_dir * knockback)
		if slow_duration > 0.0 and primary_enemy.has_method("apply_slow"):
			primary_enemy.apply_slow(slow_duration)
	_detonate()


func _detonate() -> void:
	if explode_vfx != "" and get_parent() != null:
		VfxManager.spawn_vfx(explode_vfx, get_parent(), global_position, vel.x < 0.0, 0.44 if explode_radius > 0.0 else 0.34)
	SfxManager.play("hit")
	queue_free()
