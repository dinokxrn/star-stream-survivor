extends Node2D

const SpriteLoader = preload("res://scripts/data/SpriteLoader.gd")
const GameData = preload("res://scripts/data/GameData.gd")
const UiTheme = preload("res://scripts/ui/UiTheme.gd")

var peer_id: String = ""
var display_name: String = "ผู้รอดชีวิต"
var char_idx: int = 0
var attr_id: String = "office_worker"
var hp: int = 100
var max_hp: int = 100
var facing: int = 1
var is_downed: bool = false

var _target_pos: Vector2 = Vector2(88, 212)
var _current_anim: String = "idle"
var _anim_time: float = 0.0
var _dashing: bool = false
var _parrying: bool = false

var _sprite: AnimatedSprite2D
var _aura: ColorRect
var _name_lbl: Label
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _down_lbl: Label


func setup(p_peer_id: String, p_name: String, p_char_idx: int, p_attr_id: String, start_pos: Vector2 = Vector2(88, 212)) -> void:
	peer_id = p_peer_id
	display_name = p_name if p_name != "" else p_peer_id
	char_idx = clampi(p_char_idx, 0, GameData.CHARACTERS.size() - 1)
	attr_id = p_attr_id
	position = start_pos
	_target_pos = start_pos
	add_to_group("remote_players")

	var outfit: Dictionary = GameData.CLASS_OUTFITS.get(attr_id, {"tint": Color.WHITE, "aura": Color(0.35, 0.85, 0.98, 0.3)})

	_aura = ColorRect.new()
	_aura.size = Vector2(16, 3)
	_aura.position = Vector2(-8, -2)
	_aura.color = outfit["aura"]
	_aura.color.a = 0.55
	_aura.z_index = -1
	add_child(_aura)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -23)
	_sprite.scale = Vector2(0.78, 0.78)
	_sprite.modulate = outfit["tint"]
	_sprite.sprite_frames = _build_frames(char_idx)
	add_child(_sprite)
	_sprite.play("idle")

	_hp_bg = ColorRect.new()
	_hp_bg.size = Vector2(26, 3)
	_hp_bg.position = Vector2(-13, -44)
	_hp_bg.color = Color(0.08, 0.08, 0.12, 0.85)
	_hp_bg.z_index = 12
	add_child(_hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.size = Vector2(26, 3)
	_hp_fill.position = Vector2(-13, -44)
	_hp_fill.color = Color(0.28, 0.92, 0.52)
	_hp_fill.z_index = 13
	add_child(_hp_fill)

	_name_lbl = Label.new()
	_name_lbl.text = display_name
	_name_lbl.position = Vector2(-42, -57)
	_name_lbl.custom_minimum_size = Vector2(84, 12)
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	_name_lbl.add_theme_font_size_override("font_size", 8)
	_name_lbl.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_name_lbl.z_index = 14
	add_child(_name_lbl)

	_down_lbl = Label.new()
	_down_lbl.text = "[F] ชุบชีวิต!"
	_down_lbl.position = Vector2(-42, -69)
	_down_lbl.custom_minimum_size = Vector2(84, 12)
	_down_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down_lbl.add_theme_font_override("font", UiTheme.load_pixel_font())
	_down_lbl.add_theme_font_size_override("font_size", 8)
	_down_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_down_lbl.z_index = 15
	_down_lbl.visible = false
	add_child(_down_lbl)


func _build_frames(c_idx: int) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var cdata: Dictionary = GameData.CHARACTERS[clampi(c_idx, 0, GameData.CHARACTERS.size() - 1)]
	var tex := SpriteLoader.load_tex(String(cdata.get("sprite", "res://assets/sprites/char_0.png")))
	if tex == null:
		tex = SpriteLoader.load_tex("res://assets/sprites/player_sheet.png")
	if tex == null:
		return sf
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
	var fw := maxi(32, int(tex.get_width() / 30))
	var fh := tex.get_height()
	for anim in defs.keys():
		sf.add_animation(anim)
		var fps := 16.0 if anim.begins_with("attack") else (8.5 if anim == "run" else 5.0)
		sf.set_animation_speed(anim, fps)
		sf.set_animation_loop(anim, anim in ["idle", "run"])
		for idx in defs[anim]:
			sf.add_frame(anim, SpriteLoader.make_atlas(tex, int(idx) * fw, 0, fw, fh))
	return sf


func apply_net_state(data: Dictionary) -> void:
	var nx := float(data.get("x", _target_pos.x))
	var ny := float(data.get("y", _target_pos.y))
	_target_pos = Vector2(nx, ny)
	facing = int(data.get("facing", facing))
	if facing == 0:
		facing = 1
	hp = int(data.get("hp", hp))
	max_hp = maxi(1, int(data.get("max_hp", max_hp)))
	_dashing = bool(data.get("dashing", false))
	_parrying = bool(data.get("parrying", false))
	is_downed = hp <= 0

	var new_name := String(data.get("name", display_name))
	if new_name != "" and new_name != display_name:
		display_name = new_name
		if _name_lbl:
			_name_lbl.text = display_name

	var new_char := int(data.get("char_idx", char_idx))
	if new_char != char_idx and _sprite != null:
		char_idx = clampi(new_char, 0, GameData.CHARACTERS.size() - 1)
		_sprite.sprite_frames = _build_frames(char_idx)

	var anim := String(data.get("anim", "idle"))
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
		if anim != _current_anim or anim.begins_with("attack"):
			_current_anim = anim
			_sprite.play(anim)
			if anim.begins_with("attack"):
				_sprite.frame = 0

	if _hp_fill != null:
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		_hp_fill.size.x = 26.0 * ratio
		_hp_fill.color = Color(0.95, 0.25, 0.25) if ratio < 0.35 else Color(0.28, 0.92, 0.52)
	if _down_lbl != null:
		_down_lbl.visible = is_downed


func _process(delta: float) -> void:
	_anim_time += delta
	if position.distance_to(_target_pos) > 160.0:
		position = _target_pos
	else:
		position = position.lerp(_target_pos, minf(1.0, delta * 16.0))

	if _sprite == null:
		return
	_sprite.flip_h = facing < 0
	if is_downed:
		_sprite.rotation = deg_to_rad(85.0 * float(facing))
		_sprite.position = Vector2(0, -8)
		_sprite.modulate.a = 0.65
		return
	_sprite.modulate.a = 0.78 if _dashing else 1.0
	if _current_anim == "run":
		var bob := absf(sin(_anim_time * 13.0)) * 2.0
		_sprite.position = Vector2(0, -19.0 - bob)
		_sprite.rotation = deg_to_rad(5.0 * float(facing))
	elif _current_anim.begins_with("attack"):
		_sprite.position = Vector2(float(facing) * 3.0, -19.0)
		_sprite.rotation = deg_to_rad(7.0 * float(facing))
	else:
		_sprite.position = Vector2(0, -19.0)
		_sprite.rotation = 0.0
