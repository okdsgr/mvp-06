## game_board.gd
## 盤面描画・入力・UI（ボタン・勝利演出）を担当。
## デザインはThemeConfigから取得。ロジックはGameLogicに委譲。

extends Node2D

var logic: GameLogic = GameLogic.new()
var board_rect: Rect2
var _default_font: Font

# 勝利演出
var _win_alpha: float = 0.0
var _win_tween: Tween = null

# UIボタン（CanvasLayer経由）
var _restart_btn: Button
var _undo_btn: Button

func _ready() -> void:
	_default_font = ThemeDB.fallback_font
	logic.reset()
	_update_board_rect()
	_setup_ui()
	queue_redraw()
	get_tree().get_root().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_update_board_rect()
	queue_redraw()

func _update_board_rect() -> void:
	var vp   = get_viewport_rect().size
	var side = min(vp.x, vp.y) * 0.92
	board_rect = Rect2(
		(vp.x - side) * 0.5,
		(vp.y - side) * 0.15 + vp.y * 0.08,
		side, side
	)

# ============================================================
# UI セットアップ
# ============================================================
func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var vp    = get_viewport_rect().size
	var btn_w = 160.0
	var btn_h = 56.0
	var gap   = 24.0
	var total = btn_w * 2 + gap
	var base_x = (vp.x - total) * 0.5
	var btn_y  = vp.y * 0.94

	_restart_btn = _make_button("RESTART", Color(0.3, 0.65, 1.0))
	_restart_btn.position = Vector2(base_x, btn_y)
	_restart_btn.size     = Vector2(btn_w, btn_h)
	_restart_btn.pressed.connect(_on_restart)
	canvas.add_child(_restart_btn)

	_undo_btn = _make_button("UNDO", Color(0.7, 0.7, 0.75))
	_undo_btn.position = Vector2(base_x + btn_w + gap, btn_y)
	_undo_btn.size     = Vector2(btn_w, btn_h)
	_undo_btn.pressed.connect(_on_undo)
	canvas.add_child(_undo_btn)

	var back_btn = _make_button("TITLE", Color(0.5, 0.5, 0.55))
	back_btn.position = Vector2(16, 16)
	back_btn.size     = Vector2(100, 44)
	back_btn.pressed.connect(_on_back_to_title)
	canvas.add_child(back_btn)

func _make_button(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 22)
	var normal = StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.1)
	normal.corner_radius_top_left     = 12
	normal.corner_radius_top_right    = 12
	normal.corner_radius_bottom_left  = 12
	normal.corner_radius_bottom_right = 12
	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.15)
	hover.corner_radius_top_left     = 12
	hover.corner_radius_top_right    = 12
	hover.corner_radius_bottom_left  = 12
	hover.corner_radius_bottom_right = 12
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.25)
	pressed_style.corner_radius_top_left     = 12
	pressed_style.corner_radius_top_right    = 12
	pressed_style.corner_radius_bottom_left  = 12
	pressed_style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ============================================================
# ボタンコールバック
# ============================================================
func _on_restart() -> void:
	logic.reset()
	_win_alpha = 0.0
	if _win_tween:
		_win_tween.kill()
	queue_redraw()

func _on_undo() -> void:
	if logic.global_winner != GameLogic.PLAYER_NONE:
		return
	logic.undo()
	queue_redraw()

func _on_back_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")

# ============================================================
# 入力
# ============================================================
func _input(event: InputEvent) -> void:
	if logic.global_winner != GameLogic.PLAYER_NONE:
		return
	var pressed := false
	var pos     := Vector2.ZERO
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		pos     = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		pos     = event.position
	if not pressed:
		return
	var result = _pos_to_board_cell(pos)
	if result == null:
		return
	if logic.place(result[0], result[1]):
		queue_redraw()
		if logic.global_winner != GameLogic.PLAYER_NONE:
			_play_win_animation()

func _pos_to_board_cell(pos: Vector2):
	if not board_rect.has_point(pos):
		return null
	var rel   = pos - board_rect.position
	var third = board_rect.size / 3.0
	var bx    = clamp(floori(rel.x / third.x), 0, 2)
	var by    = clamp(floori(rel.y / third.y), 0, 2)
	var board_idx = by * 3 + bx
	var local_rel = rel - Vector2(bx * third.x, by * third.y)
	var ninth = third / 3.0
	var cx    = clamp(floori(local_rel.x / ninth.x), 0, 2)
	var cy    = clamp(floori(local_rel.y / ninth.y), 0, 2)
	var cell_idx = cy * 3 + cx
	return [board_idx, cell_idx]

# ============================================================
# 勝利演出
# ============================================================
func _play_win_animation() -> void:
	_win_alpha = 0.0
	if _win_tween:
		_win_tween.kill()
	_win_tween = create_tween()
	_win_tween.tween_method(_set_win_alpha, 0.0, 1.0, 0.6).set_ease(Tween.EASE_OUT)

func _set_win_alpha(v: float) -> void:
	_win_alpha = v
	queue_redraw()

# ============================================================
# 描画ユーティリティ
# ============================================================
## テキストを水平中央に描画するヘルパー
func _draw_string_centered(text: String, cy: float, fs: int, color: Color) -> void:
	var vp = get_viewport_rect().size
	var tw = _default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx = (vp.x - tw) * 0.5
	draw_string(_default_font, Vector2(cx, cy), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

# ============================================================
# 描画
# ============================================================
func _draw() -> void:
	draw_rect(get_viewport_rect(), ThemeConfig.BG_COLOR)
	var third = board_rect.size / 3.0

	for bi in range(9):
		var bx      = bi % 3
		var by      = bi / 3
		var origin  = board_rect.position + Vector2(bx * third.x, by * third.y)
		var sb_rect = Rect2(origin, third)

		_draw_board_overlay(bi, sb_rect)

		if logic.small_board_winner[bi] != GameLogic.PLAYER_NONE:
			_draw_winner_symbol(logic.small_board_winner[bi], sb_rect)
		else:
			_draw_local_grid(sb_rect)
			var ninth = third / 3.0
			for ci in range(9):
				var cx_        = ci % 3
				var cy_        = ci / 3
				var cell_rect  = Rect2(origin + Vector2(cx_ * ninth.x, cy_ * ninth.y), ninth)
				var cell_owner = logic.small_boards[bi][ci]
				if cell_owner == GameLogic.PLAYER_ONE:
					_draw_circle_symbol(cell_rect, ThemeConfig.P1_COLOR,
						ThemeConfig.P1_LINE_WIDTH, ThemeConfig.P1_MARGIN)
				elif cell_owner == GameLogic.PLAYER_TWO:
					_draw_cross_symbol(cell_rect, ThemeConfig.P2_COLOR,
						ThemeConfig.P2_LINE_WIDTH, ThemeConfig.P2_MARGIN)

	_draw_global_grid()
	_draw_status()

	if _win_alpha > 0.0 and logic.global_winner != GameLogic.PLAYER_NONE:
		_draw_win_overlay()

func _draw_board_overlay(bi: int, rect: Rect2) -> void:
	if logic.small_board_winner[bi] != GameLogic.PLAYER_NONE:
		return
	var active = logic.active_board
	if active == GameLogic.BOARD_ANY or active == bi:
		draw_rect(rect, ThemeConfig.ACTIVE_BOARD_COLOR)
	else:
		draw_rect(rect, ThemeConfig.INACTIVE_BOARD_COLOR)

func _draw_global_grid() -> void:
	var p = board_rect.position
	var s = board_rect.size
	var t = s / 3.0
	var c = ThemeConfig.GLOBAL_LINE_COLOR
	var w = ThemeConfig.GLOBAL_LINE_WIDTH
	draw_line(p + Vector2(t.x,     0), p + Vector2(t.x,     s.y), c, w)
	draw_line(p + Vector2(t.x * 2, 0), p + Vector2(t.x * 2, s.y), c, w)
	draw_line(p + Vector2(0, t.y),     p + Vector2(s.x, t.y),     c, w)
	draw_line(p + Vector2(0, t.y * 2), p + Vector2(s.x, t.y * 2), c, w)

func _draw_local_grid(rect: Rect2) -> void:
	var p = rect.position
	var t = rect.size / 3.0
	var c = ThemeConfig.LOCAL_LINE_COLOR
	var w = ThemeConfig.LOCAL_LINE_WIDTH
	draw_line(p + Vector2(t.x,     0), p + Vector2(t.x,     rect.size.y), c, w)
	draw_line(p + Vector2(t.x * 2, 0), p + Vector2(t.x * 2, rect.size.y), c, w)
	draw_line(p + Vector2(0, t.y),     p + Vector2(rect.size.x, t.y),     c, w)
	draw_line(p + Vector2(0, t.y * 2), p + Vector2(rect.size.x, t.y * 2), c, w)

func _draw_circle_symbol(rect: Rect2, color: Color, lw: float, margin: float) -> void:
	var center = rect.position + rect.size * 0.5
	var radius = rect.size.x * 0.5 * (1.0 - margin * 2.0)
	draw_arc(center, radius, 0.0, TAU, 32, color, lw)

func _draw_cross_symbol(rect: Rect2, color: Color, lw: float, margin: float) -> void:
	var m  = rect.size * margin
	var tl = rect.position + m
	var br = rect.position + rect.size - m
	draw_line(tl,                    br,                   color, lw)
	draw_line(Vector2(br.x, tl.y),  Vector2(tl.x, br.y), color, lw)

func _draw_winner_symbol(winner: int, rect: Rect2) -> void:
	if winner == -1:
		draw_rect(rect, ThemeConfig.WINNER_DRAW_COLOR)
		return
	var color = ThemeConfig.WINNER_P1_COLOR if winner == GameLogic.PLAYER_ONE else ThemeConfig.WINNER_P2_COLOR
	if winner == GameLogic.PLAYER_ONE:
		_draw_circle_symbol(rect, color, ThemeConfig.WINNER_LINE_WIDTH, ThemeConfig.WINNER_MARGIN)
	else:
		_draw_cross_symbol(rect, color, ThemeConfig.WINNER_LINE_WIDTH, ThemeConfig.WINNER_MARGIN)

func _draw_status() -> void:
	if _default_font == null or logic.global_winner != GameLogic.PLAYER_NONE:
		return
	var fs   = ThemeConfig.STATUS_FONT_SIZE
	var text = "Player %d's turn" % logic.current_player
	var cy   = board_rect.position.y * 0.5 + fs * 0.4
	_draw_string_centered(text, cy, fs, ThemeConfig.UI_FONT_COLOR)

func _draw_win_overlay() -> void:
	if _default_font == null:
		return
	var vp = get_viewport_rect().size
	var a  = _win_alpha

	# 暗転
	draw_rect(get_viewport_rect(), Color(0, 0, 0, 0.60 * a))

	var winner = logic.global_winner
	var color: Color
	var line1: String
	var line2: String
	if winner == GameLogic.PLAYER_ONE:
		color = ThemeConfig.P1_COLOR
		line1 = "Player 1"
		line2 = "Wins!"
	elif winner == GameLogic.PLAYER_TWO:
		color = ThemeConfig.P2_COLOR
		line1 = "Player 2"
		line2 = "Wins!"
	else:
		color = Color(0.7, 0.7, 0.7)
		line1 = "Draw!"
		line2 = ""

	color.a = a

	var fs      = int(vp.x * 0.16)
	var line_h  = fs * 1.15
	var total_h = line_h * (2.0 if line2 != "" else 1.0)
	var start_y = vp.y * 0.5 - total_h * 0.5 + fs * 0.8

	# グロー（影を重ねて擬似グロー）
	for offset in [5, 3]:
		var glow   = color
		glow.a     = a * 0.25
		var tw1    = _default_font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_default_font, Vector2((vp.x - tw1) * 0.5 + offset, start_y + offset),
			line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glow)
		if line2 != "":
			var tw2 = _default_font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(_default_font, Vector2((vp.x - tw2) * 0.5 + offset, start_y + line_h + offset),
				line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glow)

	# 本体
	_draw_string_centered(line1, start_y, fs, color)
	if line2 != "":
		_draw_string_centered(line2, start_y + line_h, fs, color)

	# サブテキスト
	var sub = "Tap RESTART to play again"
	var sfs = 20
	var sub_color = ThemeConfig.UI_FONT_COLOR
	sub_color.a   = a
	_draw_string_centered(sub, start_y + line_h * 2.2, sfs, sub_color)
