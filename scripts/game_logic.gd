## game_logic.gd
## Ultimate Tic-Tac-Toeのルールエンジン。UIゼロ・純粋ロジックのみ。
## 外部からはこのクラスのメソッドを呼ぶだけでゲーム状態を管理できる。

class_name GameLogic

# --- 定数 ---
const PLAYER_NONE = 0
const PLAYER_ONE  = 1  # ⭕
const PLAYER_TWO  = 2  # ❌
const BOARD_ANY   = -1 # どの小盤にも打てる状態

# --- 勝利パターン（小盤・大盤共通） ---
const WIN_PATTERNS: Array = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],  # 横
	[0, 3, 6], [1, 4, 7], [2, 5, 8],  # 縦
	[0, 4, 8], [2, 4, 6],             # 斜め
]

# --- ゲーム状態 ---
## small_boards[board_idx][cell_idx] = PLAYER_NONE / PLAYER_ONE / PLAYER_TWO
var small_boards: Array = []
## small_board_winner[board_idx] = PLAYER_NONE / PLAYER_ONE / PLAYER_TWO / -1(引き分け)
var small_board_winner: Array = []
## 大盤の勝者
var global_winner: int = PLAYER_NONE
## 現在の手番
var current_player: int = PLAYER_ONE
## 次に打てる小盤のインデックス（BOARD_ANYなら任意）
var active_board: int = BOARD_ANY
## 全手の履歴 [{board, cell, player}]
var move_history: Array = []

func _init() -> void:
	reset()

## ゲームをリセットして初期状態に戻す
func reset() -> void:
	small_boards = []
	small_board_winner = []
	for i in range(9):
		small_boards.append([0, 0, 0, 0, 0, 0, 0, 0, 0])
		small_board_winner.append(PLAYER_NONE)
	global_winner = PLAYER_NONE
	current_player = PLAYER_ONE
	active_board = BOARD_ANY
	move_history = []

## 指定マスに打てるか判定
func can_place(board_idx: int, cell_idx: int) -> bool:
	if global_winner != PLAYER_NONE:
		return false
	if active_board != BOARD_ANY and active_board != board_idx:
		return false
	if small_board_winner[board_idx] != PLAYER_NONE:
		return false
	if small_boards[board_idx][cell_idx] != PLAYER_NONE:
		return false
	return true

## 手を打つ。成功したらtrueを返す。
func place(board_idx: int, cell_idx: int) -> bool:
	if not can_place(board_idx, cell_idx):
		return false

	small_boards[board_idx][cell_idx] = current_player
	move_history.append({
		"board": board_idx,
		"cell": cell_idx,
		"player": current_player,
	})

	# 小盤の勝者チェック
	var sb_winner = _check_winner(small_boards[board_idx])
	if sb_winner != PLAYER_NONE:
		small_board_winner[board_idx] = sb_winner
	elif _is_board_full(small_boards[board_idx]):
		small_board_winner[board_idx] = -1  # 引き分け

	# 大盤の勝者チェック
	global_winner = _check_winner(small_board_winner)

	# 次の手番の打てる盤を決定
	if global_winner == PLAYER_NONE:
		_update_active_board(cell_idx)

	# 手番交代
	current_player = PLAYER_TWO if current_player == PLAYER_ONE else PLAYER_ONE

	return true

## 直前の手を1手戻す
func undo() -> bool:
	if move_history.is_empty():
		return false

	var last = move_history.pop_back()
	small_boards[last["board"]][last["cell"]] = PLAYER_NONE

	# 小盤の勝者を再計算
	small_board_winner[last["board"]] = _check_winner(small_boards[last["board"]])
	if small_board_winner[last["board"]] == PLAYER_NONE:
		if not _is_board_full(small_boards[last["board"]]):
			small_board_winner[last["board"]] = PLAYER_NONE

	# 大盤の勝者を再計算
	global_winner = _check_winner(small_board_winner)

	# 手番を戻す
	current_player = last["player"]

	# active_boardを再計算
	if move_history.is_empty():
		active_board = BOARD_ANY
	else:
		var prev = move_history.back()
		_update_active_board(prev["cell"])

	return true

## 勝者を返す（PLAYER_NONE=未決, PLAYER_ONE, PLAYER_TWO）
## boardは9要素配列。small_board_winner用に-1(引き分け)はPLAYER_NONEとして扱う。
func _check_winner(board: Array) -> int:
	for pattern in WIN_PATTERNS:
		var a = board[pattern[0]]
		var b = board[pattern[1]]
		var c = board[pattern[2]]
		if a == b and b == c and a != PLAYER_NONE and a != -1:
			return a
	return PLAYER_NONE

func _is_board_full(board: Array) -> bool:
	for cell in board:
		if cell == PLAYER_NONE:
			return false
	return true

func _update_active_board(next_board_idx: int) -> void:
	# 次に打つべき盤がすでに決着済みなら任意
	if small_board_winner[next_board_idx] != PLAYER_NONE:
		active_board = BOARD_ANY
	else:
		active_board = next_board_idx

## デバッグ用: 盤面を文字列で返す
func debug_print() -> void:
	print("=== GameLogic State ===")
	print("Player: %d | Active board: %d | Winner: %d" % [current_player, active_board, global_winner])
	for i in range(9):
		print("Board[%d] winner=%d | %s" % [i, small_board_winner[i], str(small_boards[i])])
