class_name SpriteLoader
extends RefCounted


static func load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var loaded = load(res_path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(res_path):
		var bytes := FileAccess.get_file_as_bytes(res_path)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img2 := Image.load_from_file(abs_path)
		if img2 != null and not img2.is_empty():
			return ImageTexture.create_from_image(img2)
	return null


static func make_atlas(tex: Texture2D, x: int, y: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(x, y, w, h)
	return a
