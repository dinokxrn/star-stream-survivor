extends SceneTree

# Generates a crisp 64x64 pixel-art portrait of Dokkaebi Bihyung (ORV)
func _init() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var outline := Color(0.08, 0.10, 0.16, 1.0)
	var fur_w := Color(0.95, 0.96, 0.99, 1.0)
	var fur_sh := Color(0.78, 0.83, 0.92, 1.0)
	var fur_deep := Color(0.62, 0.68, 0.80, 1.0)
	var horn_dark := Color(0.28, 0.30, 0.38, 1.0)
	var horn_light := Color(0.56, 0.60, 0.70, 1.0)
	var eye_glow := Color(0.18, 0.88, 1.0, 1.0)
	var eye_hi := Color(0.85, 0.99, 1.0, 1.0)
	var cheek := Color(0.96, 0.66, 0.72, 0.85)
	var mouth := Color(0.16, 0.08, 0.14, 1.0)
	var fang := Color(1.0, 1.0, 1.0, 1.0)
	var tunic_dark := Color(0.16, 0.18, 0.28, 1.0)
	var tunic_mid := Color(0.26, 0.30, 0.44, 1.0)
	var straw := Color(0.76, 0.64, 0.38, 1.0)
	var straw_sh := Color(0.54, 0.43, 0.22, 1.0)
	var gold := Color(1.0, 0.86, 0.32, 1.0)
	var cyan_aura := Color(0.22, 0.82, 1.0, 0.35)

	# Soft circular Star Stream halo behind Bihyung
	_fill_ellipse(img, 32, 32, 27, 27, Color(0.05, 0.14, 0.28, 0.85))
	_fill_ellipse(img, 32, 32, 24, 24, Color(0.08, 0.22, 0.42, 0.70))
	_draw_ring(img, 32, 32, 27, Color(0.25, 0.85, 1.0, 0.85))

	# Body (chubby floating Dokkaebi torso in dark tunic + straw waist wrap)
	_fill_ellipse(img, 32, 47, 13, 11, outline)
	_fill_ellipse(img, 32, 47, 11, 9, tunic_dark)
	_fill_ellipse(img, 31, 45, 9, 6, tunic_mid)
	# Traditional straw-mat waist sash (Dokkaebi signature)
	for y in range(47, 53):
		for x in range(21, 44):
			if _in_ellipse(x, y, 32, 47, 11, 9):
				var c := straw if ((x + y) % 3 != 0) else straw_sh
				img.set_pixel(x, y, c)
	# Blue Star Stream gem on chest
	_fill_rect(img, 30, 41, 4, 4, outline)
	_fill_rect(img, 31, 42, 2, 2, eye_glow)

	# Little floating fluffy arms
	_fill_ellipse(img, 18, 43, 5, 4, outline)
	_fill_ellipse(img, 18, 43, 3, 2, fur_w)
	_fill_ellipse(img, 46, 43, 5, 4, outline)
	_fill_ellipse(img, 46, 43, 3, 2, fur_w)

	# Horns (two cute sharp horns on top of head)
	var horn_pts_l := [Vector2i(22, 19), Vector2i(21, 14), Vector2i(23, 10), Vector2i(26, 15), Vector2i(27, 19)]
	var horn_pts_r := [Vector2i(42, 19), Vector2i(43, 14), Vector2i(41, 10), Vector2i(38, 15), Vector2i(37, 19)]
	_draw_horn(img, 23, 10, 22, 20, 27, 20, outline, horn_dark, horn_light)
	_draw_horn(img, 41, 10, 37, 20, 42, 20, outline, horn_dark, horn_light)

	# Fluffy white Dokkaebi head (slightly wide & round with fluffy tufts)
	_fill_ellipse(img, 32, 29, 17, 14, outline)
	_fill_ellipse(img, 17, 28, 5, 5, outline)
	_fill_ellipse(img, 47, 28, 5, 5, outline)
	_fill_ellipse(img, 32, 17, 7, 4, outline)

	_fill_ellipse(img, 32, 29, 15, 12, fur_sh)
	_fill_ellipse(img, 32, 27, 14, 11, fur_w)
	_fill_ellipse(img, 18, 28, 3, 3, fur_w)
	_fill_ellipse(img, 46, 28, 3, 3, fur_w)
	_fill_ellipse(img, 32, 18, 5, 3, fur_w)
	# Subtle chin shading
	for x in range(22, 43):
		if _in_ellipse(x, 38, 32, 29, 14, 11):
			img.set_pixel(x, 38, fur_deep)

	# Expressive mischievous eyebrows
	for i in range(6):
		img.set_pixel(21 + i, 22 + int(i / 3), outline)
		img.set_pixel(21 + i, 23 + int(i / 3), outline)
		img.set_pixel(43 - i, 22 + int(i / 3), outline)
		img.set_pixel(43 - i, 23 + int(i / 3), outline)

	# Big glowing Star Stream eyes
	_fill_rect(img, 22, 25, 6, 6, outline)
	_fill_rect(img, 23, 26, 4, 4, eye_glow)
	img.set_pixel(24, 27, eye_hi)
	img.set_pixel(23, 26, eye_hi)

	_fill_rect(img, 36, 25, 6, 6, outline)
	_fill_rect(img, 37, 26, 4, 4, eye_glow)
	img.set_pixel(38, 27, eye_hi)
	img.set_pixel(37, 26, eye_hi)

	# Rosy cheeks
	_fill_rect(img, 19, 31, 3, 2, cheek)
	_fill_rect(img, 42, 31, 3, 2, cheek)

	# Mischievous grin + tiny fang!
	_fill_rect(img, 27, 33, 10, 4, mouth)
	img.set_pixel(26, 33, mouth)
	img.set_pixel(37, 33, mouth)
	img.set_pixel(29, 34, fang)
	img.set_pixel(34, 34, fang)
	img.set_pixel(30, 36, Color(0.88, 0.36, 0.46, 1.0))
	img.set_pixel(31, 36, Color(0.88, 0.36, 0.46, 1.0))
	img.set_pixel(32, 36, Color(0.88, 0.36, 0.46, 1.0))
	img.set_pixel(33, 36, Color(0.88, 0.36, 0.46, 1.0))

	# Star Stream floating sparkles
	_draw_sparkle(img, 11, 15, gold)
	_draw_sparkle(img, 53, 18, eye_glow)
	_draw_sparkle(img, 10, 48, eye_glow)
	_draw_sparkle(img, 54, 46, gold)
	_fill_rect(img, 50, 12, 2, 2, cyan_aura)

	img.save_png("res://assets/sprites/bihyung_portrait.png")
	print("Generated res://assets/sprites/bihyung_portrait.png (64x64)")
	quit(0)


func _in_ellipse(x: int, y: int, cx: int, cy: int, rx: int, ry: int) -> bool:
	var dx := float(x - cx) / float(maxi(1, rx))
	var dy := float(y - cy) / float(maxi(1, ry))
	return dx * dx + dy * dy <= 1.0


func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(maxi(0, cy - ry), mini(64, cy + ry + 1)):
		for x in range(maxi(0, cx - rx), mini(64, cx + rx + 1)):
			if _in_ellipse(x, y, cx, cy, rx, ry):
				img.set_pixel(x, y, col)


func _draw_ring(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(64):
		for x in range(64):
			var d := sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			if absf(d - float(r)) <= 0.85:
				img.set_pixel(x, y, col)


func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	for y in range(maxi(0, y0), mini(64, y0 + h)):
		for x in range(maxi(0, x0), mini(64, x0 + w)):
			img.set_pixel(x, y, col)


func _draw_horn(img: Image, tx: int, ty: int, lx: int, by: int, rx: int, _ry: int, out_c: Color, mid_c: Color, hi_c: Color) -> void:
	for y in range(ty, by + 1):
		var t := float(y - ty) / float(maxi(1, by - ty))
		var x1 := int(round(lerpf(float(tx), float(lx), t)))
		var x2 := int(round(lerpf(float(tx), float(rx), t)))
		for x in range(mini(x1, x2) - 1, maxi(x1, x2) + 2):
			if x >= 0 and x < 64 and y >= 0 and y < 64:
				if x == mini(x1, x2) - 1 or x == maxi(x1, x2) + 1 or y == ty:
					img.set_pixel(x, y, out_c)
				elif x == mini(x1, x2):
					img.set_pixel(x, y, hi_c)
				else:
					img.set_pixel(x, y, mid_c)


func _draw_sparkle(img: Image, cx: int, cy: int, col: Color) -> void:
	var pts := [Vector2i(cx, cy), Vector2i(cx - 1, cy), Vector2i(cx + 1, cy), Vector2i(cx, cy - 1), Vector2i(cx, cy + 1)]
	for p in pts:
		if p.x >= 0 and p.x < 64 and p.y >= 0 and p.y < 64:
			img.set_pixel(p.x, p.y, col)
