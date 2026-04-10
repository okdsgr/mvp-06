## game_board.gd
## Ultimate Tic-Tac-Toeの盤面描画・タッチ/クリック入力を担当。
## デザインはThemeConfigから取得する。ロジックはGameLogicに委譲する。

extends Node2D

var logic: GameLogic = GameLogic.new()
var board_rect: Rect2
var _default_font: Font

func _ready() -> void:
	_default_font = ThemeDB.fallback_font
	logic.reset()
	_update_board_rect()
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
		(vp.y - side) * 0.5,
		side, side
	)

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

func _pos_to_board_cell(pos: Vector2):
	if not board_rect.has_point(pos):
		return null
	var rel   = pos - board_rect.position
	var third = board_rect.size / 3.0
	var bx    = clamp(floori(rel.x / third.x), 0, 2)
	var by    = clamp(floori(rel.y / third.y), 0, 2)
	var board_idx   = by * 3 + bx
	var local_rel   = rel - Vector2(bx * third.x, by * third.y)
	var ninth = third / 3.0
	var cx    = clamp(floori(local_rel.x / ninth.x), 0, 2)
	var cy    = clamp(floori(local_rel.y / ninth.y), 0, 2)
	var cell_idx = cy * 3 + cx
	return [board_idx, cell_idx]

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
				var cx         = ci % 3
				var cy_        = ci / 3
				var cell_rect  = Rect2(origin + Vector2(cx * ninth.x, cy_ * ninth.y), ninth)
				var cell_owner = logic.small_boards[bi][ci]
				if cell_owner == GameLogic.PLAYER_ONE:
					_draw_circle_symbol(cell_rect, ThemeConfig.P1_COLOR,
						ThemeConfig.P1_LINE_WIDTH, ThemeConfig.P1_MARGIN)
				elif cell_owner == GameLogic.PLAYER_TWO:
					_draw_cross_symbol(cell_rect, ThemeConfig.P2_COLOR,
						ThemeConfig.P2_LINE_WIDTH, ThemeConfig.P2_MARGIN)

	_draw_global_grid()
	_draw_status()

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
	var lw    = ThemeConfig.WINNER_LINE_WIDTH
	var mg    = ThemeConfig.WINNER_MARGIN
	if winner == GameLogic.PLAYER_ONE:
		_draw_circle_symbol(rect, color, lw, mg)
	else:
		_draw_cross_symbol(rect, color, lw, mg)

func _draw_status() -> void:
	if _default_font == null:
		return
	var vp   = get_viewport_rect().size
	var fs   = ThemeConfig.STATUS_FONT_SIZE
	var text: String
	if logic.global_winner == GameLogic.PLAYER_ONE:
		text = "Player 1 Win!"
	elif logic.global_winner == GameLogic.PLAYER_TWO:
		text = "Player 2 Win!"
	else:
		text = "Player %d's turn" % logic.current_player
	var tw  = _default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos = Vector2((vp.x - tw) * 0.5, board_rect.position.y * 0.5 + fs * 0.4)
	draw_string(_default_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		ThemeConfig.UI_FONT_COLOR)

# ============================================================
# 外部API
# ============================================================
func restart() -> void:
	logic.reset()
	queue_redraw()

func undo() -> void:
	logic.undo()
	queue_redraw()
