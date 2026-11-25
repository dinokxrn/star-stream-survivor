extends Area2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const UiTheme = preload("res://scripts/ui/UiTheme.gd")

signal interacted(kind: String, node: Node)

var kind: String = "weapon"
var prompt_text: String = "[F] สำรวจ"
var used: bool = false
var _player_near: bool = false

var _sprite: Sprite2D
var _prompt_label: Label
var _glow_rect: ColorRect
var _time: float = 0.0


func setup(p_kind: String, p_prompt: String, pos: Vector2) -> void:
	kind = p_kind
	prompt_text = p_prompt
	position = pos
	collision_layer = 8
	collision_mask = 2

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 32)
	col.shape = shape
	col.position = Vector2(0, -14)
	add_child(col)

	_glow_rect = ColorRect.new()
	_glow_rect.size = Vector2(22, 22)
	_glow_rect.position = Vector2(-11, -24)
	_glow_rect.color = Color(0.22, 0.74, 0.97, 0.22)
	if kind == "bug_box":
		_glow_rect.color = Color(0.13, 0.85, 0.45, 0.25)
	elif kind == "npc_rescue":
		_glow_rect.color = Color(0.98, 0.8, 0.15, 0.2)
	add_child(_glow_rect)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == "npc_rescue":
		_sprite.texture = SpriteLoader.load_tex("res://assets/sprites/npc_survivor.png")
		_sprite.position = Vector2(0, -19)
	elif kind in ["gas_mask_crate", "station_exit", "green_zone", "king_flag"]:
		var camp_tex := SpriteLoader.load_tex("res://assets/sprites/props_campaign.png")
		if camp_tex != null:
			var tile_map := {"gas_mask_crate": 0, "station_exit": 24, "green_zone": 48, "king_flag": 72}
			_sprite.texture = SpriteLoader.make_atlas(camp_tex, int(tile_map[kind]), 0, 24, 24)
		_sprite.position = Vector2(0, -12)
	else:
		var props_tex := SpriteLoader.load_tex("res://assets/sprites/props.png")
		if props_tex != null:
			var tile_x := 0 if kind == "weapon" else 24
			_sprite.texture = SpriteLoader.make_atlas(props_tex, tile_x, 0, 24, 24)
		_sprite.position = Vector2(0, -12)
	add_child(_sprite)

	_prompt_label = Label.new()
	_prompt_label.text = prompt_text
	_prompt_label.visible = false
	_prompt_label.position = Vector2(-46, -46)
	_prompt_label.add_theme_font_override("font", UiTheme.load_pixel_font())
	_prompt_label.add_theme_font_size_override("font_size", 12)
	_prompt_label.add_theme_color_override("font_color", Color(0.75, 0.94, 1.0))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.12))
	_prompt_label.add_theme_constant_override("outline_size", 3)
	_prompt_label.z_index = 35
	add_child(_prompt_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if used:
		return
	_time += delta
	var pulse := 0.16 + 0.14 * sin(_time * 4.5)
	if kind == "bug_box" and GameState.current_attribute_id == "apocalypse_reader":
		pulse = 0.35 + 0.25 * sin(_time * 7.0)
	_glow_rect.color.a = pulse
	if _player_near and Input.is_action_just_pressed("interact"):
		interacted.emit(kind, self)


func mark_used() -> void:
	used = true
	_prompt_label.visible = false
	_glow_rect.visible = false
	if kind == "weapon":
		_sprite.visible = false


func _on_body_entered(body: Node) -> void:
	if not used and body.is_in_group("player"):
		_player_near = true
		_prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_prompt_label.visible = false
