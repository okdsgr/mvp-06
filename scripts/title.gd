## title.gd
## タイトル画面。_draw()で直接描画するシンプル実装。

extends Node2D

var _default_font: Font

func _ready() -> void:
	_default_font = ThemeDB.fallback_font
	RenderingServer.set_default_clear_color(ThemeConfig.BG_COLOR)
	_setup_ui()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var vp = get_viewport_rect().size

	# ONLINE MATCH ボタン
	var online_btn = _make_btn("ONLINE MATCH", Color(0.2, 0.55, 0.95))
	online_btn.position = Vector2((vp.x - 220) * 0.5, vp.y * 0.55)
	online_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/matchmaking.tscn"))
	canvas.add_child(online_btn)

	# VS CPU ボタン
	var cpu_btn = _make_btn("VS CPU", Color(0.35, 0.65, 0.35))
	cpu_btn.position = Vector2((vp.x - 220) * 0.5, vp.y * 0.67)
	cpu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	canvas.add_child(cpu_btn)

	# LOCAL 2P ボタン
	var local_btn = _make_btn("LOCAL 2P", Color(0.5, 0.5, 0.55))
	local_btn.position = Vector2((vp.x - 220) * 0.5, vp.y * 0.79)
	local_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	canvas.add_child(local_btn)

func _make_btn(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 24)
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = color.darkened(0.1)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sbox.set("corner_radius_" + corner, 14)
	var hbox = sbox.duplicate()
	hbox.bg_color = color.lightened(0.15)
	var pbox = sbox.duplicate()
	pbox.bg_color = color.darkened(0.25)
	btn.add_theme_stylebox_override("normal",  sbox)
	btn.add_theme_stylebox_override("hover",   hbox)
	btn.add_theme_stylebox_override("pressed", pbox)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func _draw() -> void:
	if _default_font == null:
		return
	var vp = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), ThemeConfig.BG_COLOR)

	var chars  = ["X", "A", "T", "A", "T", "R", "O", "N"]
	var colors = [
		ThemeConfig.P2_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.P1_COLOR,
		ThemeConfig.UI_FONT_COLOR,
	]
	var fs = int(vp.x * 0.155)
	var total_w = 0.0
	for c in chars:
		total_w += _default_font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var start_x = (vp.x - total_w) * 0.5
	var title_y = vp.y * 0.28
	var x = start_x
	for i in range(chars.size()):
		var c = chars[i]
		draw_string(_default_font, Vector2(x, title_y), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colors[i])
		x += _default_font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	var sub    = "9 boards · think ahead"
	var sub_fs = 18
	var sub_w  = _default_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs).x
	draw_string(_default_font,
		Vector2((vp.x - sub_w) * 0.5, title_y + fs * 0.3 + sub_fs * 1.6),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs, Color(0.55, 0.55, 0.65))
