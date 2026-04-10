## title.gd
## タイトル画面。_draw()で直接描画するシンプル実装。

extends Node2D

var _default_font: Font
var _start_btn: Button

func _ready() -> void:
	_default_font = ThemeDB.fallback_font
	RenderingServer.set_default_clear_color(ThemeConfig.BG_COLOR)
	_setup_ui()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var vp = get_viewport_rect().size

	var btn = Button.new()
	btn.name = "StartButton"
	btn.text = "START"
	btn.custom_minimum_size = Vector2(220, 64)
	btn.position = Vector2((vp.x - 220) * 0.5, vp.y * 0.62)
	btn.add_theme_font_size_override("font_size", 28)

	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.2, 0.55, 0.95)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sbox.set("corner_radius_" + corner, 14)
	var hbox = sbox.duplicate()
	hbox.bg_color = Color(0.3, 0.65, 1.0)
	var pbox = sbox.duplicate()
	pbox.bg_color = Color(0.1, 0.4, 0.8)
	btn.add_theme_stylebox_override("normal",  sbox)
	btn.add_theme_stylebox_override("hover",   hbox)
	btn.add_theme_stylebox_override("pressed", pbox)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(_on_start_pressed)
	canvas.add_child(btn)
	_start_btn = btn

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _draw() -> void:
	if _default_font == null:
		return
	var vp = get_viewport_rect().size

	# 背景
	draw_rect(Rect2(Vector2.ZERO, vp), ThemeConfig.BG_COLOR)

	# タイトル「XATATRON」を1文字ずつ色分けして描画
	# X=P2カラー、O=P1カラー、それ以外=白
	var chars = ["X", "A", "T", "A", "T", "R", "O", "N"]
	var colors = [
		ThemeConfig.P2_COLOR,   # X
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.UI_FONT_COLOR,
		ThemeConfig.P1_COLOR,   # O
		ThemeConfig.UI_FONT_COLOR,
	]
	var fs = int(vp.x * 0.155)

	# 全体幅を計算してセンタリング
	var total_w = 0.0
	for c in chars:
		total_w += _default_font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var start_x = (vp.x - total_w) * 0.5
	var title_y  = vp.y * 0.30

	var x = start_x
	for i in range(chars.size()):
		var c = chars[i]
		draw_string(_default_font, Vector2(x, title_y), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colors[i])
		x += _default_font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	# サブタイトル
	var sub    = "9 boards · think ahead"
	var sub_fs = 20
	var sub_w  = _default_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs).x
	draw_string(_default_font,
		Vector2((vp.x - sub_w) * 0.5, title_y + fs * 0.3 + sub_fs * 1.4),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs,
		Color(0.55, 0.55, 0.65))
