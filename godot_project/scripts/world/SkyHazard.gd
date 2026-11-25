extends Node2D

var delay: float = 0.85
var damage: int = 28
var radius: float = 24.0
var _warn_rect: ColorRect
var _elapsed: float = 0.0
var _struck: bool = false


func setup(pos_x: float, floor_y: float, dmg: int = 28) -> void:
	position = Vector2(pos_x, floor_y)
	damage = dmg
	_warn_rect = ColorRect.new()
	_warn_rect.size = Vector2(radius * 2.0, 180.0)
	_warn_rect.position = Vector2(-radius, -180.0)
	_warn_rect.color = Color(1.0, 0.18, 0.22, 0.18)
	_warn_rect.z_index = 19
	add_child(_warn_rect)


func _process(delta: float) -> void:
	if _struck:
		return
	_elapsed += delta
	_warn_rect.color.a = 0.14 + 0.24 * absf(sin(_elapsed * 16.0))
	if _elapsed >= delay:
		_struck = true
		_warn_rect.visible = false
		VfxManager.spawn_vfx("fire_bomb", get_parent(), position + Vector2(0, -14), false, 0.56)
		SfxManager.play("skill")
		var player := get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			if absf(player.global_position.x - position.x) <= radius + 10.0:
				player.take_damage(damage, 0.0, null, true)
		queue_free()
