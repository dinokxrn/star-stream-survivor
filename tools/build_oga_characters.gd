extends SceneTree

const SCRATCH := "/Users/mac/.gemini/antigravity/brain/5e456e27-32dc-4605-b872-c23e2a948663/scratch/oga_chars"
const LPC_DIR := SCRATCH + "/lpc_entry/lpc_entry/png"
const SARA_PATH := SCRATCH + "/sara_full.png"
const OUT_DIR := "/Users/mac/Desktop/GAME_Project/godot_project/assets/sprites"

# Frame mapping: [anim_dir, row_in_dir, col_in_dir, sara_row]
# LPC directions: 0=up, 1=left, 2=down, 3=right (we use 3=right!)
# SaraFullSheet rows: spellcast=0..3, thrust=4..7, walk=8..11, slash=12..15, bow=16..19, hurt=20
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


func _get_lpc_body(anim_dir: String) -> String:
	match anim_dir:
		"slash": return "BODY_human.png"
		"bow": return "BODY_animation.png"
		"hurt": return "BODY_male.png"
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
		var frame := Image.create(64, 64, false, Image.FORMAT_RGBA8)

		# Base body
		var body_img := _load_img("%s/%s/%s" % [LPC_DIR, anim_dir, _get_lpc_body(anim_dir)])
		if body_img == null:
			body_img = _load_img("%s/%s/BODY_male.png" % [LPC_DIR, anim_dir])
		if body_img != null and (col + 1) * 64 <= body_img.get_width() and (row + 1) * 64 <= body_img.get_height():
			var sub := body_img.get_region(Rect2i(col * 64, row * 64, 64, 64))
			frame.blend_rect(sub, Rect2i(0, 0, 64, 64), Vector2i.ZERO)

		# Outfit, hair, hat, weapon layers
		for ldef in layers:
			var fname: String = ldef[0]
			var tint: Color = ldef[1]
			var limg := _load_img("%s/%s/%s" % [LPC_DIR, anim_dir, fname])
			if limg != null and (col + 1) * 64 <= limg.get_width() and (row + 1) * 64 <= limg.get_height():
				var sub := limg.get_region(Rect2i(col * 64, row * 64, 64, 64))
				if tint != Color.WHITE:
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
	var hood_tint: Color = cfg.get("hood_tint", Color(0, 0, 0, 0))

	for fi in FRAME_MAP.size():
		var fm: Array = FRAME_MAP[fi]
		var anim_dir: String = fm[0]
		var col: int = fm[2]
		var srow: int = fm[3]
		var sx := col * 64
		var sy := srow * 64
		if sx + 64 > sara.get_width() or sy + 64 > sara.get_height():
			sx = 0
		var frame := sara.get_region(Rect2i(sx, sy, 64, 64))
		# Recolor Sara's blonde hair (high R+G, low B) and cyan outfit (high B+G, low R) cleanly!
		for y in 64:
			for x in 64:
				var c := frame.get_pixel(x, y)
				if c.a < 0.05:
					continue
				if c.r > 0.55 and c.g > 0.42 and c.b < 0.38 and hair_tint != Color.WHITE:
					# Hair pixel
					var lum := (c.r * 0.5 + c.g * 0.4 + c.b * 0.1)
					frame.set_pixel(x, y, Color(clampf(lum * hair_tint.r, 0, 1), clampf(lum * hair_tint.g, 0, 1), clampf(lum * hair_tint.b, 0, 1), c.a))
				elif c.b > 0.45 and c.g > 0.45 and c.r < 0.45 and outfit_tint != Color.WHITE:
					# Outfit pixel
					var lum := (c.b * 0.55 + c.g * 0.35 + c.r * 0.1)
					frame.set_pixel(x, y, Color(clampf(lum * outfit_tint.r, 0, 1), clampf(lum * outfit_tint.g, 0, 1), clampf(lum * outfit_tint.b, 0, 1), c.a))

		if hood_tint.a > 0.1:
			var himg := _load_img("%s/%s/HEAD_robe_hood.png" % [LPC_DIR, anim_dir])
			var hrow: int = fm[1]
			if himg != null and (col + 1) * 64 <= himg.get_width() and (hrow + 1) * 64 <= himg.get_height():
				var hsub := _tint_copy(himg.get_region(Rect2i(col * 64, hrow * 64, 64, 64)), hood_tint)
				frame.blend_rect(hsub, Rect2i(0, 0, 64, 64), Vector2i.ZERO)

		if is_kid:
			var small: Image = frame.duplicate() as Image
			small.resize(52, 52, Image.INTERPOLATE_NEAREST)
			frame.fill(Color(0, 0, 0, 0))
			frame.blend_rect(small, Rect2i(0, 0, 52, 52), Vector2i(6, 12))
		sheet.blit_rect(frame, Rect2i(0, 0, 64, 64), Vector2i(fi * 64, 0))
	return sheet


func _init() -> void:
	var recipes := [
		# 0: คัง มินซู — ชายหนุ่มออฟฟิศ (สูทกรมท่า)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.28, 0.34, 0.52)],
			["FEET_shoes_brown.png", Color(0.28, 0.28, 0.32)],
			["TORSO_chain_armor_jacket_purple.png", Color(0.24, 0.34, 0.62)],
			["BELT_leather.png", Color(0.3, 0.3, 0.35)],
			["HEAD_hair_blonde.png", Color(0.18, 0.20, 0.26)],
		]},
		# 1: ชเว แทโฮ — ชายหนุ่มสายลุย (ผมแดงตั้ง)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.32, 0.30, 0.38)],
			["FEET_shoes_brown.png", Color(0.55, 0.35, 0.25)],
			["TORSO_leather_armor_torso.png", Color(0.88, 0.36, 0.32)],
			["TORSO_leather_armor_bracers.png", Color(0.95, 0.55, 0.35)],
			["HEAD_hair_blonde.png", Color(0.92, 0.24, 0.22)],
		]},
		# 2: ฮัน จีฮยอก — ชายหนุ่มโค้ทขาว (มาดนักอ่าน)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.22, 0.24, 0.30)],
			["FEET_shoes_brown.png", Color(0.25, 0.25, 0.30)],
			["TORSO_leather_armor_shirt_white.png", Color(1.0, 1.0, 1.0)],
			["TORSO_robe_shirt_brown.png", Color(0.95, 0.97, 1.0)],
			["BELT_leather.png", Color(0.25, 0.30, 0.45)],
			["HEAD_hair_blonde.png", Color(0.16, 0.18, 0.22)],
		]},
		# 3: ลี โซยอน — หญิงสาวนักศึกษา (ผมยาวน้ำตาล)
		{"type": "female", "hair_tint": Color(0.58, 0.36, 0.22), "outfit_tint": Color(0.95, 0.92, 0.98)},
		# 4: คิม ฮานึล — หญิงสาวนักดาบ (ผมหางม้า)
		{"type": "female", "hair_tint": Color(0.22, 0.26, 0.44), "outfit_tint": Color(0.88, 0.26, 0.36)},
		# 5: ยุน อาเรอิน — หญิงสาวจอมเวท (ผมเงินยาว)
		{"type": "female", "hair_tint": Color(0.92, 0.95, 1.0), "outfit_tint": Color(0.55, 0.35, 0.96)},
		# 6: น้องจุนอู — เด็กชายหมวกแก๊ปแดง (ตัวเล็กคล่องตัว)
		{"type": "male", "kid": true, "layers": [
			["LEGS_pants_greenish.png", Color(0.32, 0.48, 0.78)],
			["FEET_shoes_brown.png", Color(0.92, 0.28, 0.28)],
			["TORSO_leather_armor_shirt_white.png", Color(0.95, 0.85, 0.35)],
			["HEAD_leather_armor_hat.png", Color(0.95, 0.24, 0.26)],
		]},
		# 7: น้องมินอา — เด็กหญิงผมแกละชมพู (ตัวเล็กคล่องตัว)
		{"type": "female", "kid": true, "hair_tint": Color(1.0, 0.56, 0.78), "outfit_tint": Color(0.98, 0.75, 0.32)},
		# 8: คุณตาซองอิล — ชายชราหนวดขาว (ผู้ผ่านโลก)
		{"type": "male", "layers": [
			["LEGS_robe_skirt.png", Color(0.45, 0.42, 0.50)],
			["FEET_shoes_brown.png", Color(0.45, 0.35, 0.28)],
			["TORSO_robe_shirt_brown.png", Color(0.62, 0.55, 0.48)],
			["BELT_rope.png", Color(0.85, 0.80, 0.65)],
			["HEAD_hair_blonde.png", Color(0.94, 0.96, 1.0)],
		]},
		# 9: คุณยายฮเยจา — หญิงชราผมมวยเงิน (ใจนิ่งดุจหิน)
		{"type": "female", "hair_tint": Color(0.92, 0.94, 0.98), "outfit_tint": Color(0.72, 0.36, 0.46)},
		# 10: ซอ แจมิน — ชายหนุ่มนักกีฬา (ชุดวอร์มเขียว)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.28, 0.75, 0.45)],
			["FEET_shoes_brown.png", Color(0.95, 0.95, 0.95)],
			["TORSO_leather_armor_torso.png", Color(0.25, 0.82, 0.46)],
			["HEAD_hair_blonde.png", Color(0.24, 0.22, 0.20)],
		]},
		# 11: ปาร์ค คยองซู — ชายหนุ่มแพทย์สนาม (เสื้อกาวน์ขาว)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.32, 0.52, 0.65)],
			["FEET_shoes_brown.png", Color(0.85, 0.88, 0.92)],
			["TORSO_leather_armor_shirt_white.png", Color(1.0, 1.0, 1.0)],
			["TORSO_plate_armor_torso.png", Color(0.92, 0.98, 1.0)],
			["HEAD_hair_blonde.png", Color(0.25, 0.22, 0.26)],
		]},
		# 12: คิม ยองฮุน — ชายหนุ่มนักดนตรี (ผมยาวแจ็กเก็ตม่วง)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.22, 0.20, 0.30)],
			["FEET_shoes_brown.png", Color(0.26, 0.22, 0.30)],
			["TORSO_chain_armor_jacket_purple.png", Color(0.85, 0.45, 1.0)],
			["HEAD_hair_blonde.png", Color(0.42, 0.28, 0.62)],
		]},
		# 13: จอง อึนบี — หญิงสาวออฟฟิศ (สูทเทา-ฟ้า)
		{"type": "female", "hair_tint": Color(0.22, 0.20, 0.24), "outfit_tint": Color(0.45, 0.68, 0.92)},
		# 14: ฮัน ยูริ — หญิงสาวนักวิ่ง (ผมหางม้าส้ม)
		{"type": "female", "hair_tint": Color(1.0, 0.55, 0.22), "outfit_tint": Color(0.30, 0.88, 0.62)},
		# 15: แบค ซูจิน — หญิงสาวโค้ทแดง (ผมยาวดำสนิท)
		{"type": "female", "hair_tint": Color(0.15, 0.16, 0.20), "outfit_tint": Color(0.95, 0.24, 0.28)},
		# 16: น้องโดฮยอน — เด็กชายหมวกเหลือง (ชุดนักเรียน)
		{"type": "male", "kid": true, "layers": [
			["LEGS_pants_greenish.png", Color(0.25, 0.30, 0.48)],
			["FEET_shoes_brown.png", Color(0.35, 0.28, 0.24)],
			["TORSO_leather_armor_shirt_white.png", Color(0.96, 0.96, 1.0)],
			["HEAD_leather_armor_hat.png", Color(1.0, 0.85, 0.22)],
		]},
		# 17: น้องฮานะ — เด็กหญิงฮู้ดฟ้า (ตัวเล็กคล่องตัว)
		{"type": "female", "kid": true, "hair_tint": Color(0.35, 0.26, 0.22), "outfit_tint": Color(0.36, 0.78, 1.0), "hood_tint": Color(0.36, 0.78, 1.0, 1.0)},
		# 18: คุณลุงจินโฮ — ช่างเทคนิคสถานี (หมวกนิรภัยเหลือง)
		{"type": "male", "layers": [
			["LEGS_pants_greenish.png", Color(0.28, 0.36, 0.52)],
			["FEET_plate_armor_shoes.png", Color(0.45, 0.42, 0.38)],
			["TORSO_plate_armor_torso.png", Color(0.35, 0.55, 0.85)],
			["HEAD_plate_armor_helmet.png", Color(1.0, 0.84, 0.20)],
		]},
		# 19: คุณป้าซอนมี — คุณป้าผู้ใจดี (ผ้ากันเปื้อนเขียว)
		{"type": "female", "hair_tint": Color(0.48, 0.38, 0.34), "outfit_tint": Color(0.32, 0.82, 0.48)},
	]

	for i in recipes.size():
		var r: Dictionary = recipes[i]
		var img: Image = _build_female_sheet(r) if r["type"] == "female" else _build_male_sheet(r)
		var out_path := "%s/char_%d.png" % [OUT_DIR, i]
		img.save_png(out_path)
		if i == 0:
			img.save_png("%s/player_sheet.png" % OUT_DIR)
	print("Generated all %d OpenGameArt LPC character sprite sheets (1920x64)!" % recipes.size())
	quit()
