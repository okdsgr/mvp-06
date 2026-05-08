## network_manager.gd
## マッチメイキング・ゲーム状態同期を管理する。AutoLoad登録。

extends Node

signal match_found(room_id: String, is_host: bool)
signal match_failed(error: String)
signal game_state_updated(state: Dictionary)

enum MatchState { IDLE, SEARCHING, IN_MATCH }

var state: MatchState = MatchState.IDLE
var current_room_id: String = ""
var is_host: bool = false
var my_uid: String = ""
var poll_timer: Timer
const POLL_INTERVAL := 2.0

func _ready() -> void:
	poll_timer = Timer.new()
	poll_timer.wait_time = POLL_INTERVAL
	poll_timer.timeout.connect(_poll_game_state)
	add_child(poll_timer)
	FirebaseManager.auth_completed.connect(_on_auth_completed)
	FirebaseManager.auth_failed.connect(func(e): match_failed.emit(e))

func _on_auth_completed(uid: String) -> void:
	my_uid = uid

# ============================================================
# ルームコード方式（フレンド対戦）
# ============================================================
func create_room_with_code(rating: int) -> String:
	var room_id       = _generate_room_id()
	current_room_id   = room_id
	is_host           = true
	state             = MatchState.SEARCHING
	var room_data     = _make_room_data(rating)
	room_data["room_code"] = room_id
	FirebaseManager.firestore_write_completed.connect(_on_room_created, CONNECT_ONE_SHOT)
	FirebaseManager.firestore_error.connect(func(e): match_failed.emit(e), CONNECT_ONE_SHOT)
	FirebaseManager.write_document("rooms/" + room_id, room_data)
	return room_id

func join_room_with_code(room_code: String, rating: int) -> void:
	current_room_id = room_code
	is_host         = false
	FirebaseManager.firestore_read_completed.connect(_on_room_read_for_join.bind(rating), CONNECT_ONE_SHOT)
	FirebaseManager.firestore_error.connect(func(e): match_failed.emit(e), CONNECT_ONE_SHOT)
	FirebaseManager.read_document("rooms/" + room_code)

func _on_room_read_for_join(room_data: Dictionary, guest_rating: int) -> void:
	if room_data.get("status", "") != "waiting":
		match_failed.emit("Room not available")
		return
	room_data["guest_uid"]    = my_uid
	room_data["guest_rating"] = guest_rating
	room_data["status"]       = "playing"
	FirebaseManager.firestore_write_completed.connect(_on_joined_room, CONNECT_ONE_SHOT)
	FirebaseManager.write_document("rooms/" + current_room_id, room_data)

func _on_joined_room() -> void:
	state = MatchState.IN_MATCH
	poll_timer.start()
	match_found.emit(current_room_id, false)

# ============================================================
# ランダムマッチ
# ============================================================
func start_random_match(rating: int) -> void:
	if my_uid == "":
		match_failed.emit("Not authenticated")
		return
	# MVP: シンプルにルームを作って待機（BOT実装はPhase 3）
	var room_id     = _generate_room_id()
	current_room_id = room_id
	is_host         = true
	state           = MatchState.SEARCHING
	var room_data   = _make_room_data(rating)
	room_data["match_type"] = "random"
	FirebaseManager.firestore_write_completed.connect(_on_room_created, CONNECT_ONE_SHOT)
	FirebaseManager.write_document("rooms/" + room_id, room_data)

func _on_room_created() -> void:
	poll_timer.start()

# ============================================================
# ゲーム状態同期
# ============================================================
func send_move(board_idx: int, cell_idx: int, logic: GameLogic) -> void:
	var data              = _serialize_game_state(logic)
	data["last_move_board"] = board_idx
	data["last_move_cell"]  = cell_idx
	FirebaseManager.write_document("rooms/" + current_room_id, data)

func _poll_game_state() -> void:
	if current_room_id == "":
		return
	FirebaseManager.firestore_read_completed.connect(_on_state_polled, CONNECT_ONE_SHOT)
	FirebaseManager.read_document("rooms/" + current_room_id)

func _on_state_polled(data: Dictionary) -> void:
	if state == MatchState.SEARCHING:
		if data.get("status", "") == "playing":
			state = MatchState.IN_MATCH
			match_found.emit(current_room_id, is_host)
		return
	game_state_updated.emit(data)

func leave_room() -> void:
	poll_timer.stop()
	if current_room_id != "":
		FirebaseManager.delete_document("rooms/" + current_room_id)
	current_room_id = ""
	state           = MatchState.IDLE

# ============================================================
# ユーティリティ
# ============================================================
func _generate_room_id() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var id    = ""
	for i in range(6):
		id += chars[randi() % chars.length()]
	return id

func _make_room_data(rating: int) -> Dictionary:
	return {
		"host_uid":        my_uid,
		"host_rating":     rating,
		"guest_uid":       "",
		"guest_rating":    0,
		"status":          "waiting",
		"created_at":      Time.get_unix_time_from_system(),
		"board_state":     "",
		"sb_winners":      "",
		"current_player":  1,
		"active_board":    -1,
		"last_move_board": -1,
		"last_move_cell":  -1,
		"winner":          0,
		"free_moves_host":  0,
		"free_moves_guest": 0,
		"move_count":      0,
	}

func _serialize_game_state(logic: GameLogic) -> Dictionary:
	var boards_flat = []
	for bi in range(9):
		for ci in range(9):
			boards_flat.append(logic.small_boards[bi][ci])
	return {
		"board_state":    JSON.stringify(boards_flat),
		"sb_winners":     JSON.stringify(logic.small_board_winner),
		"current_player": logic.current_player,
		"active_board":   logic.active_board,
		"winner":         logic.global_winner,
		"move_count":     logic.move_history.size(),
		"status":         "playing" if logic.global_winner == 0 else "finished",
	}

func deserialize_game_state(data: Dictionary, logic: GameLogic) -> void:
	var boards_flat = JSON.parse_string(data.get("board_state", "[]"))
	if boards_flat is Array and boards_flat.size() == 81:
		for bi in range(9):
			for ci in range(9):
				logic.small_boards[bi][ci] = boards_flat[bi * 9 + ci]
	var sb_winners = JSON.parse_string(data.get("sb_winners", "[]"))
	if sb_winners is Array and sb_winners.size() == 9:
		logic.small_board_winner = sb_winners
	logic.current_player = data.get("current_player", 1)
	logic.active_board   = data.get("active_board", -1)
	logic.global_winner  = data.get("winner", 0)
