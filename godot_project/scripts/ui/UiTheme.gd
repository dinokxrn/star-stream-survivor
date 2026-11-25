class_name UiTheme
extends RefCounted

const COL_BG := Color(0.03, 0.08, 0.17, 0.92)
const COL_BG_DARK := Color(0.02, 0.05, 0.11, 0.96)
const COL_BORDER := Color(0.22, 0.74, 0.97, 0.95)
const COL_GOLD := Color(0.98, 0.80, 0.18, 1.0)
const COL_TEXT := Color(0.92, 0.97, 1.0, 1.0)
const COL_MUTED := Color(0.60, 0.76, 0.88, 1.0)


static var _pixel_font_cache: Font = null
static var _pixel_font_bold_cache: Font = null


static func load_pixel_font() -> Font:
	if _pixel_font_cache != null:
		return _pixel_font_cache
	var path := "res://assets/fonts/ThaiPixel.ttf"
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is FontFile:
			loaded.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			loaded.hinting = TextServer.HINTING_NONE
			loaded.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			loaded.generate_mipmaps = false
			_pixel_font_cache = loaded
			return _pixel_font_cache
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var ff := FontFile.new()
			ff.data = bytes
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ff.generate_mipmaps = false
			_pixel_font_cache = ff
			return _pixel_font_cache
	var ff2 := FontFile.new()
	if ff2.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK:
		ff2.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff2.hinting = TextServer.HINTING_NONE
		ff2.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff2.generate_mipmaps = false
		_pixel_font_cache = ff2
		return _pixel_font_cache
	return ThemeDB.fallback_font


static func load_font(bold: bool = false) -> Font:
	var base := load_pixel_font()
	if not bold:
		return base
	if _pixel_font_bold_cache == null:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_embolden = 0.22
		_pixel_font_bold_cache = fv
	return _pixel_font_bold_cache


static func make_panel_style(border_col: Color = COL_BORDER, bg_col: Color = COL_BG, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func make_button_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


static func create_theme() -> Theme:
	var t := Theme.new()
	var reg := load_pixel_font()
	t.default_font = reg
	t.default_font_size = 18

	t.set_stylebox("panel", "PanelContainer", make_panel_style())
	t.set_stylebox("normal", "Button", make_button_style(Color(0.06, 0.16, 0.30, 0.95), COL_BORDER))
	t.set_stylebox("hover", "Button", make_button_style(Color(0.10, 0.28, 0.48, 0.98), Color(0.55, 0.88, 1.0)))
	t.set_stylebox("pressed", "Button", make_button_style(Color(0.04, 0.12, 0.22, 1.0), COL_GOLD))
	t.set_stylebox("disabled", "Button", make_button_style(Color(0.08, 0.10, 0.14, 0.75), Color(0.28, 0.34, 0.42, 0.7)))
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.56, 0.64))
	t.set_color("font_color", "Label", COL_TEXT)
	return t


static func rarity_color(code: String) -> Color:
	if code == "legend":
		return Color(1.0, 0.38, 0.52)
	if code == "hero":
		return COL_GOLD
	if code == "rare":
		return Color(0.30, 0.85, 1.0)
	return Color(0.85, 0.90, 0.95)
