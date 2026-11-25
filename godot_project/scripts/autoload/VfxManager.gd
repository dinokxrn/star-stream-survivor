extends Node

const VFX_KEYS: Array[String] = [
	"slash",
	"wind_slash",
	"hit_spark",
	"dash_puff",
	"mana_burst",
	"shield_aura",
	"fire_bomb",
	"coin_sparkle",
	"level_up",
	"fireball",
	"lightning",
	"frost_nova",
	"dark_orb",
	"ground_slam",
	"parry",
	"impact_frame",
	"dagger_flurry",
	"heavy_cleave",
	"spin_slash",
	"scythe_reap",
]

var _cache: Dictionary = {}


func _ready() -> void:
	preload_all()


func preload_all() -> void:
	for key in VFX_KEYS:
		_load_vfx(key)


func has_vfx(vfx_name: String) -> bool:
	if not _cache.has(vfx_name):
		_load_vfx(vfx_name)
	return _cache.has(vfx_name)


func _load_vfx(vfx_name: String) -> void:
	var png_path := "res://assets/vfx/%s/%s.png" % [vfx_name, vfx_name]
	var json_path := "res://assets/vfx/%s/%s.json" % [vfx_name, vfx_name]
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(png_path):
		push_warning("VfxManager: missing VFX files for '%s'" % vfx_name)
		return

	var raw := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("VfxManager: invalid JSON for '%s'" % vfx_name)
		return

	var tex: Texture2D = null
	if ResourceLoader.exists(png_path):
		tex = load(png_path)
	if tex == null and FileAccess.file_exists(png_path):
		var bytes := FileAccess.get_file_as_bytes(png_path)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		var img2 := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if img2 != null and not img2.is_empty():
			tex = ImageTexture.create_from_image(img2)
	if tex == null:
		return

	var frames_data = parsed.get("frames", {})
	var meta: Dictionary = parsed.get("meta", {})
	var pfx_meta: Dictionary = meta.get("pixelfx", {})
	var fps: float = float(pfx_meta.get("fps", 16.0))
	var loop: bool = bool(pfx_meta.get("loop", false))
	var pivot_arr = pfx_meta.get("pivot", [0.5, 0.5])
	var frame_size_arr = pfx_meta.get("frameSize", [64, 64])

	var sf := SpriteFrames.new()
	sf.add_animation("play")
	sf.set_animation_speed("play", fps)
	sf.set_animation_loop("play", loop)

	var entries: Array = []
	if typeof(frames_data) == TYPE_DICTIONARY:
		var keys: Array = frames_data.keys()
		keys.sort()
		for k in keys:
			entries.append(frames_data[k])
	elif typeof(frames_data) == TYPE_ARRAY:
		entries = frames_data

	var first_w: float = float(frame_size_arr[0]) if frame_size_arr.size() >= 2 else 64.0
	var first_h: float = float(frame_size_arr[1]) if frame_size_arr.size() >= 2 else 64.0

	for entry in entries:
		var f: Dictionary = entry.get("frame", {})
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(
			float(f.get("x", 0)),
			float(f.get("y", 0)),
			float(f.get("w", first_w)),
			float(f.get("h", first_h))
		)
		first_w = atlas.region.size.x
		first_h = atlas.region.size.y
		sf.add_frame("play", atlas)

	var pivot_px := Vector2(first_w * 0.5, first_h * 0.5)
	if typeof(pivot_arr) == TYPE_ARRAY and pivot_arr.size() >= 2:
		var px := float(pivot_arr[0])
		var py := float(pivot_arr[1])
		# pixelfx pivot can be normalized (0..1) or pixel coordinates
		if px <= 1.0 and py <= 1.0:
			pivot_px = Vector2(first_w * px, first_h * py)
		else:
			pivot_px = Vector2(px, py)
	elif typeof(pivot_arr) == TYPE_DICTIONARY:
		pivot_px = Vector2(float(pivot_arr.get("x", first_w * 0.5)), float(pivot_arr.get("y", first_h * 0.5)))

	var center_offset := Vector2(first_w * 0.5 - pivot_px.x, first_h * 0.5 - pivot_px.y)
	_cache[vfx_name] = {
		"frames": sf,
		"loop": loop,
		"offset": center_offset,
		"size": Vector2(first_w, first_h),
	}


func spawn_vfx(vfx_name: String, parent: Node2D, pos: Vector2, flip_h: bool = false, scale_mult: float = 0.55) -> AnimatedSprite2D:
	if not has_vfx(vfx_name) or parent == null:
		return null
	var data: Dictionary = _cache[vfx_name]
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = data["frames"]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.flip_h = flip_h
	var off: Vector2 = data["offset"]
	if flip_h:
		off.x = -off.x
	sprite.offset = off
	sprite.scale = Vector2(scale_mult, scale_mult)
	sprite.z_index = 25
	parent.add_child(sprite)
	sprite.play("play")
	if not bool(data["loop"]):
		sprite.animation_finished.connect(sprite.queue_free)
	return sprite
