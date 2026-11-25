extends Node2D

const UiTheme = preload("res://scripts/ui/UiTheme.gd")

var _label: Label
var _vel: Vector2 = Vector2(0, -34)
var _life: float = 0.75
var _max_life: float = 0.75


func setup(text: String, color: Color = Color.WHITE) -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_override("font", UiTheme.load_pixel_font())
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1, 1.0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_font_size_override("font_size", 12)
	_label.position = Vector2(-18, -10)
	_label.z_index = 40
	add_child(_label)
	_vel = Vector2(randf_range(-10.0, 10.0), -36.0)


func _process(delta: float) -> void:
	position += _vel * delta
	_vel.y += 42.0 * delta
	_life -= delta
	modulate.a = clampf(_life / _max_life, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
