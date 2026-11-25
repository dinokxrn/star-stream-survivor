extends SceneTree

const SCRATCH := "/Users/mac/.gemini/antigravity/brain/5e456e27-32dc-4605-b872-c23e2a948663/scratch/oga_chars"
const LPC_DIR := SCRATCH + "/lpc_entry/lpc_entry/png"
const GENT_DIR := SCRATCH + "/modern/gentleman/gentleman"
const VAR_DIR := SCRATCH + "/modern/variety"
const SARA_PATH := SCRATCH + "/sara_full.png"
const OUT_DIR := "/Users/mac/Desktop/GAME_Project/godot_project/assets/sprites"

# [anim_dir, lpc_dir_row, col, full_832_row]
const FRAME_MAP := [
	["walkcycle", 3, 0, 11], # 0 idle1
	["walkcycle", 3, 4, 11], # 1 idle2
	["walkcycle", 3, 1, 11], # 2 run1
	["walkcycle", 3, 3, 11], # 3 run2
	["walkcycle", 3, 5, 11], # 4 run3
	["walkcycle", 3, 7, 11], # 5 run4
	["walkcycle", 3, 2, 11], # 6 jump
	["thrust",    3, 4,  7], # 7 dash
	["hurt",      0, 2, 20], # 8 hurt
	["slash",     3, 1, 15], # 9 parry_pose
	["slash",     3, 1, 15], # 10 attack1_1
	["slash",     3, 3, 15], # 11 attack1_2
	["slash",     3, 5, 15], # 12 attack1_3
	["slash",     3, 2, 15], # 13 attack2_1
	["slash",     3, 4, 15], # 14 attack2_2
	["slash",     3, 5, 15], # 15 attack2_3
	["slash",     3, 0, 15], # 16 attack3_1
	["slash",     3, 3, 15], # 17 attack3_2
	["slash",     3, 5, 15], # 18 attack3_3
	["thrust",    3, 1,  7], # 19 thrust1
	["thrust",    3, 4,  7], # 20 thrust2
	["thrust",    3, 6,  7], # 21 thrust3
	["slash",     3, 0, 15], # 22 heavy1
	["slash",     3, 2, 15], # 23 heavy2
	["slash",     3, 5, 15], # 24 heavy3
	["slash",     3, 3, 15], # 25 spin1
	["slash",     3, 5, 15], # 26 spin2
	["spellcast", 3, 2,  3], # 27 cast1
	["spellcast", 3, 5,  3], # 28 cast2
	["bow",       3, 8, 19], # 29 shoot
]

var _img_cache: Dictionary = {}


func _load_img(path: String) -> Image:
	if _img_cache.has(path):
		return _img_cache[path]
	var img := Image.new()
	if FileAccess.file_exists(path) and img.load(path) == OK:
		img.convert(Image.FORMAT_RGBA8)
		_img_cache[path] = img
		return img
	_img_cache[path] = null
	return null


func _tint_copy(src: Image, tint: Color) -> Image:
	var out: Image = src.duplicate() as Image
	if tint == Color.WHITE:
		return out
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.01:
				out.set_pixel(x, y, Color(
					clampf(c.r * tint.r, 0.0, 1.0),
					clampf(c.g * tint.g, 0.0, 1.0),
					clampf(c.b * tint.b, 0.0, 1.0),
					c.a
				))
	return out


func _bright_white_copy(src: Image, tint: Color) -> Image:
	var out: Image = src.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.01:
				var lum := clampf((c.r * 0.35 + c.g * 0.45 + c.b * 0.20) * 1.45 + 0.15, 0.12, 1.0)
				out.set_pixel(x, y, Color(clampf(lum * tint.r, 0.0, 1.0), clampf(lum * tint.g, 0.0, 1.0), clampf(lum * tint.b, 0.0, 1.0), c.a))
	return out


func _get_lpc_body(anim_dir: String) -> String:
	match anim_dir:
		"slash": return "BODY_human.png"
		"bow": return "BODY_animation.png"
		_: return "BODY_male.png"


func _build_male_sheet(cfg: Dictionary) -> Image:
	var sheet := Image.create(30 * 64, 64, false, Image.FORMAT_RGBA8)
	var is_kid: bool = bool(cfg.get("kid", false))
	var layers: Array = cfg.get("layers", [])
	for fi in FRAME_MAP.size():
		var fm: Array = FRAME_MAP[fi]
		var anim_dir: String = fm[0]
		var row: int = fm[1]
		var col: int = fm[2]
		var full_row: int = fm[3]
		var frame := Image.create(64, 64, false, Image.FORMAT_RGBA8)

		# Base body
		var body_img := _load_img("%s/%s/%s" % [LPC_DIR, anim_dir, _get_lpc_body(anim_dir)])
		if body_img == null:
			body_img = _load_img("%s/%s/BODY_male.png" % [LPC_DIR, anim_dir])
		if body_img != null and (col + 1) * 64 <= body_img.get_width() and (row + 1) * 64 <= body_img.get_height():
			frame.blend_rect(body_img.get_region(Rect2i(col * 64, row * 64, 64, 64)), Rect2i(0, 0, 64, 64), Vector2i.ZERO)

		# Modern layers: ["gent"|"var"|"lpc", filename, tint, optional "white_lift"]
		for ldef in layers:
			var src_kind: String = ldef[0]
			var fname: String = ldef[1]
			var tint: Color = ldef[2]
			var white_lift: bool = ldef.size() >= 4 and bool(ldef[3])
			var limg: Image = null
			var sx := col * 64
			var sy := full_row * 64
			if src_kind == "gent":
				limg = _load_img("%s/%s" % [GENT_DIR, fname])
			elif src_kind == "var":
				limg = _load_img("%s/%s" % [VAR_DIR, fname])
			else:
				limg = _load_img("%s/%s/%s" % [LPC_DIR, anim_dir, fname])
				sy = row * 64
			if limg != null and sx + 64 <= limg.get_width() and sy + 64 <= limg.get_height():
				var sub := limg.get_region(Rect2i(sx, sy, 64, 64))
				if white_lift:
					sub = _bright_white_copy(sub, tint)
				elif tint != Color.WHITE:
					sub = _tint_copy(sub, tint)
				frame.blend_rect(sub, Rect2i(0, 0, 64, 64), Vector2i.ZERO)

		if is_kid:
			var small: Image = frame.duplicate() as Image
			small.resize(52, 52, Image.INTERPOLATE_NEAREST)
			frame.fill(Color(0, 0, 0, 0))
			frame.blend_rect(small, Rect2i(0, 0, 52, 52), Vector2i(6, 12))
		sheet.blit_rect(frame, Rect2i(0, 0, 64, 64), Vector2i(fi * 64, 0))
	return sheet


func _build_female_sheet(cfg: Dictionary) -> Image:
	var sara := _load_img(SARA_PATH)
	var sheet := Image.create(30 * 64, 64, false, Image.FORMAT_RGBA8)
	if sara == null:
		return sheet
	var hair_tint: Color = cfg.get("hair_tint", Color.WHITE)
	var outfit_tint: Color = cfg.get("outfit_tint", Color.WHITE)
	var is_kid: bool = bool(cfg.get("kid", false))
	var add_glasses: bool = bool(cfg.get("glasses", false))
	var jacket_file: String = String(cfg.get("jacket", ""))
	var jacket_tint: Color = cfg.get("jacket_tint", Color.WHITE)

	for fi in FRAME_MAP.size():
		var fm: Array = FRAME_MAP[fi]
		var col: int = fm[2]
		var srow: int = fm[3]
		var sx := col * 64
		var sy := srow * 64
		if sx + 64 > sara.get_width() or sy + 64 > sara.get_height():
			sx = 0
		var frame := sara.get_region(Rect2i(sx, sy, 64, 64))
		for y in 64:
			for x in 64:
				var c := frame.get_pixel(x, y)
				if c.a < 0.05:
					continue
				if c.r > 0.55 and c.g > 0.42 and c.b < 0.38 and hair_tint != Color.WHITE:
					var lum := (c.r * 0.5 + c.g * 0.4 + c.b * 0.1)
					frame.set_pixel(x, y, Color(clampf(lum * hair_tint.r, 0, 1), clampf(lum * hair_tint.g, 0, 1), clampf(lum * hair_tint.b, 0, 1), c.a))
				elif c.b > 0.45 and c.g > 0.45 and c.r < 0.45 and outfit_tint != Color.WHITE:
					var lum := (c.b * 0.55 + c.g * 0.35 + c.r * 0.1)
					frame.set_pixel(x, y, Color(clampf(lum * outfit_tint.r, 0, 1), clampf(lum * outfit_tint.g, 0, 1), clampf(lum * outfit_tint.b, 0, 1), c.a))

		if jacket_file != "":
			var jimg := _load_img("%s/%s" % [GENT_DIR, jacket_file])
			if jimg != null and sx + 64 <= jimg.get_width() and sy + 64 <= jimg.get_height():
				var jsub := _tint_copy(jimg.get_region(Rect2i(sx, sy, 64, 64)), jacket_tint)
				frame.blend_rect(jsub, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
		if add_glasses:
			var gimg := _load_img("%s/formal_glasses.png" % GENT_DIR)
			if gimg != null and sx + 64 <= gimg.get_width() and sy + 64 <= gimg.get_height():
				frame.blend_rect(gimg.get_region(Rect2i(sx, sy, 64, 64)), Rect2i(0, 0, 64, 64), Vector2i.ZERO)

		if is_kid:
			var small: Image = frame.duplicate() as Image
			small.resize(52, 52, Image.INTERPOLATE_NEAREST)
			frame.fill(Color(0, 0, 0, 0))
			frame.blend_rect(small, Rect2i(0, 0, 52, 52), Vector2i(6, 12))
		sheet.blit_rect(frame, Rect2i(0, 0, 64, 64), Vector2i(fi * 64, 0))
	return sheet


func _init() -> void:
	var recipes := [
		# 0: คัง มินซู — ชายหนุ่มออฟฟิศ (สูทกรมท่า + เนกไท + แว่น)
		{"type": "male", "layers": [
			["gent", "formal_pants.png", Color(0.28, 0.34, 0.55)],
			["lpc",  "FEET_shoes_brown.png", Color(0.22, 0.22, 0.28)],
			["gent", "formal_shirt.png", Color.WHITE],
			["gent", "formal_necktie.png", Color(0.85, 0.22, 0.25)],
			["gent", "formal_jacket black.png", Color(0.32, 0.44, 0.72)],
			["lpc",  "HEAD_hair_blonde.png", Color(0.16, 0.18, 0.22)],
			["gent", "formal_glasses.png", Color.WHITE],
		]},
		# 1: ชเว แทโฮ — ชายหนุ่มสายลุย (เสื้อแดง + แจ็กเก็ตดำ + ผมแดง)
		{"type": "male", "layers": [
			["var",  "male_pants_black.png", Color.WHITE],
			["lpc",  "FEET_shoes_brown.png", Color(0.35, 0.25, 0.22)],
			["var",  "male_shirt_red.png", Color.WHITE],
			["gent", "formal_vest.png", Color(0.30, 0.28, 0.32)],
			["lpc",  "HEAD_hair_blonde.png", Color(0.92, 0.22, 0.22)],
		]},
		# 2: ฮัน จีฮยอก — ชายหนุ่มโค้ทขาว (มาดนักอ่าน คิมดกจา!)
		{"type": "male", "layers": [
			["var",  "male_pants_black.png", Color.WHITE],
			["lpc",  "FEET_shoes_brown.png", Color(0.20, 0.20, 0.25)],
			["gent", "formal_shirt.png", Color.WHITE],
			["gent", "formal_necktie.png", Color(0.22, 0.24, 0.32)],
			["gent", "formal_trenchcoat grey.png", Color(0.96, 0.98, 1.0), true],
			["lpc",  "HEAD_hair_blonde.png", Color(0.14, 0.16, 0.20)],
		]},
		# 3: ลี โซยอน — หญิงสาวนักศึกษา (ผมยาวน้ำตาล เสื้อขาว-กรม)
		{"type": "female", "hair_tint": Color(0.55, 0.34, 0.20), "outfit_tint": Color(0.92, 0.95, 1.0)},
		# 4: คิม ฮานึล — หญิงสาวนักดาบ (แจ็กเก็ตแดง-ดำ)
		{"type": "female", "hair_tint": Color(0.18, 0.22, 0.38), "outfit_tint": Color(0.88, 0.24, 0.32), "jacket": "formal_jacket black.png", "jacket_tint": Color(0.90, 0.30, 0.35)},
		# 5: ยุน อาเรอิน — หญิงสาวจอมเวท (ผมเงิน โค้ทม่วงทันสมัย)
		{"type": "female", "hair_tint": Color(0.92, 0.95, 1.0), "outfit_tint": Color(0.58, 0.38, 0.96), "jacket": "formal_trenchcoat grey.png", "jacket_tint": Color(0.65, 0.45, 0.95)},
		# 6: น้องจุนอู — เด็กชาย (เสื้อเหลือง ยีนส์น้ำเงิน)
		{"type": "male", "kid": true, "layers": [
			["var",  "male_pants_blue.png", Color.WHITE],
			["lpc",  "FEET_shoes_brown.png", Color(0.92, 0.26, 0.26)],
			["var",  "male_shirt_yellow.png", Color.WHITE],
			["lpc",  "HEAD_hair_blonde.png", Color(0.22, 0.20, 0.22)],
		]},
		# 7: น้องมินอา — เด็กหญิงผมชมพู
		{"type": "female", "kid": true, "hair_tint": Color(1.0, 0.56, 0.78), "outfit_tint": Color(0.98, 0.78, 0.34)},
		# 8: คุณตาซองอิล — ชายชราผมขาว (เสื้อกั๊กน้ำตาล + แว่น + เชิ้ต)
		{"type": "male", "layers": [
			["gent", "formal_pants.png", Color(0.45, 0.42, 0.38)],
			["lpc",  "FEET_shoes_brown.png", Color(0.38, 0.28, 0.22)],
			["gent", "formal_shirt.png", Color.WHITE],
			["gent", "formal_jacket brown.png", Color.WHITE],
			["lpc",  "HEAD_hair_blonde.png", Color(0.94, 0.96, 1.0)],
			["gent", "formal_glasses.png", Color.WHITE],
		]},
		# 9: คุณยายฮเยจา — หญิงชราผมเงิน (คาร์ดิแกนแดงเข้ม + แว่น)
		{"type": "female", "hair_tint": Color(0.92, 0.94, 0.98), "outfit_tint": Color(0.76, 0.34, 0.44), "glasses": true},
		# 10: ซอ แจมิน — ชายหนุ่มนักกีฬา (ชุดวอร์มเขียว)
		{"type": "male", "layers": [
			["var",  "male_pants_black.png", Color.WHITE],
			["lpc",  "FEET_shoes_brown.png", Color(0.92, 0.92, 0.95)],
			["var",  "male_shirt_green.png", Color.WHITE],
			["lpc",  "HEAD_hair_blonde.png", Color(0.22, 0.20, 0.18)],
		]},
		# 11: ปาร์ค คยองซู — ชายหนุ่มแพทย์สนาม (เสื้อกาวน์ขาว + แว่น)
		{"type": "male", "layers": [
			["var",  "male_pants_blue.png", Color(0.75, 0.85, 0.95)],
			["lpc",  "FEET_shoes_brown.png", Color(0.85, 0.88, 0.92)],
			["var",  "male_shirt_blue.png", Color(0.55, 0.92, 0.95)],
			["gent", "formal_trenchcoat grey.png", Color(0.98, 1.0, 1.0), true],
			["lpc",  "HEAD_hair_blonde.png", Color(0.22, 0.20, 0.24)],
			["gent", "formal_glasses.png", Color.WHITE],
		]},
		# 12: คิม ยองฮุน — ชายหนุ่มนักดนตรี (เสื้อม่วง + แจ็กเก็ตดำ)
		{"type": "male", "layers": [
			["var",  "male_pants_black.png", Color.WHITE],
			["lpc",  "FEET_shoes_brown.png", Color(0.24, 0.22, 0.28)],
			["var",  "male_shirt_purple.png", Color.WHITE],
			["gent", "formal_jacket black.png", Color(0.75, 0.55, 0.95)],
			["lpc",  "HEAD_hair_blonde.png", Color(0.32, 0.22, 0.48)],
		]},
		# 13: จอง อึนบี — หญิงสาวออฟฟิศ (สูทเทา-ฟ้า + แว่น)
		{"type": "female", "hair_tint": Color(0.20, 0.20, 0.24), "outfit_tint": Color(0.45, 0.72, 0.96), "jacket": "formal_jacket black.png", "jacket_tint": Color(0.55, 0.65, 0.82), "glasses": true},
		# 14: ฮัน ยูริ — หญิงสาวนักวิ่ง (ผมส้ม ชุดกีฬาเขียวมิ้นต์)
		{"type": "female", "hair_tint": Color(1.0, 0.54, 0.22), "outfit_tint": Color(0.28, 0.90, 0.64)},
		# 15: แบค ซูจิน — หญิงสาวโค้ทแดง (ผมดำสนิท โค้ทแดง)
		{"type": "female", "hair_tint": Color(0.14, 0.16, 0.20), "outfit_tint": Color(0.92, 0.24, 0.28), "jacket": "formal_trenchcoat grey.png", "jacket_tint": Color(0.95, 0.25, 0.30)},
		# 16: น้องโดฮยอน — เด็กนักเรียนชาย (เสื้อเชิ้ตขาว + เนกไท + กางเกงกรม)
		{"type": "male", "kid": true, "layers": [
			["var",  "male_pants_blue.png", Color(0.55, 0.60, 0.78)],
			["lpc",  "FEET_shoes_brown.png", Color(0.32, 0.26, 0.22)],
			["gent", "formal_shirt.png", Color.WHITE],
			["gent", "formal_necktie.png", Color(0.95, 0.78, 0.22)],
			["lpc",  "HEAD_hair_blonde.png", Color(0.20, 0.18, 0.20)],
		]},
		# 17: น้องฮานะ — เด็กหญิงฮู้ดฟ้า
		{"type": "female", "kid": true, "hair_tint": Color(0.34, 0.24, 0.20), "outfit_tint": Color(0.35, 0.80, 1.0)},
		# 18: คุณลุงจินโฮ — ช่างเทคนิคสถานี (เสื้อกั๊กสะท้อนแสงเหลือง + กางเกงยีนส์)
		{"type": "male", "layers": [
			["var",  "male_pants_blue.png", Color(0.65, 0.75, 0.90)],
			["lpc",  "FEET_shoes_brown.png", Color(0.42, 0.32, 0.24)],
			["var",  "male_shirt_yellow.png", Color.WHITE],
			["gent", "formal_vest.png", Color(1.0, 0.86, 0.22)],
			["lpc",  "HEAD_hair_blonde.png", Color(0.36, 0.34, 0.34)],
		]},
		# 19: คุณป้าซอนมี — คุณป้าใจดี (เสื้อคาร์ดิแกนเขียว)
		{"type": "female", "hair_tint": Color(0.46, 0.36, 0.32), "outfit_tint": Color(0.30, 0.82, 0.48)},
	]

	for i in recipes.size():
		var r: Dictionary = recipes[i]
		var img: Image = _build_female_sheet(r) if r["type"] == "female" else _build_male_sheet(r)
		var out_path := "%s/char_%d.png" % [OUT_DIR, i]
		img.save_png(out_path)
		if i == 0:
			img.save_png("%s/player_sheet.png" % OUT_DIR)
	print("Generated all %d MODERN SEOUL OpenGameArt LPC characters (1920x64)!" % recipes.size())
	quit()
