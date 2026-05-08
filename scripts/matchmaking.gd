## matchmaking.gd
## マッチメイキング画面。ランダムマッチ・ルームコード対戦の両方に対応。

extends Control

@onready var title_label:     Label         = $MainContainer/TitleLabel
@onready var room_list:       VBoxContainer = $MainContainer/ScrollContainer/RoomList
@onready var create_room_btn: Button        = $MainContainer/ButtonContainer/CreateRoomButton
@onready var refresh_btn:     Button        = $MainContainer/ButtonContainer/RefreshButton

func _ready() -> void:
	NetworkManager.match_found.connect(_on_match_found)
	NetworkManager.match_failed.connect(_on_match_failed)

	# 既存ボタンにスタイルを適用
	_apply_style(create_room_btn, Color(0.3, 0.65, 1.0))
	_apply_style(refresh_btn,     Color(0.45, 0.45, 0.5))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", ThemeConfig.UI_FONT_COLOR)

	_build_extra_ui()

	if FirebaseManager.id_token == "":
		FirebaseManager.auth_completed.connect(_on_auth_done, CONNECT_ONE_SHOT)
		FirebaseManager.auth_failed.connect(func(e): _show_status("Auth error: " + e), CONNECT_ONE_SHOT)
		FirebaseManager.sign_in_anonymous()
	else:
		_show_status("Ready")

	create_room_btn.pressed.connect(_on_create_room_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)

func _on_auth_done(_uid: String) -> void:
	_show_status("Ready")

# ============================================================
# UI構築
# ============================================================
func _build_extra_ui() -> void:
	# ランダムマッチボタン
	var random_btn = _make_button("RANDOM MATCH", Color(0.2, 0.7, 0.45))
	random_btn.custom_minimum_size = Vector2(320, 56)
	$MainContainer/ButtonContainer.add_child(random_btn)
	random_btn.pressed.connect(_on_random_match_pressed)

	# ルームコード入力エリア
	var code_row = HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 12)
	$MainContainer.add_child(code_row)

	var code_input = LineEdit.new()
	code_input.name             = "CodeInput"
	code_input.placeholder_text = "Enter Room Code"
	code_input.max_length       = 6
	code_input.custom_minimum_size = Vector2(200, 52)
	code_input.add_theme_font_size_override("font_size", 22)
	code_row.add_child(code_input)

	var join_btn = _make_button("JOIN", ThemeConfig.P2_COLOR)
	join_btn.custom_minimum_size = Vector2(96, 52)
	join_btn.pressed.connect(_on_join_pressed)
	code_row.add_child(join_btn)

func _apply_style(btn: Button, color: Color) -> void:
	btn.add_theme_font_size_override("font_size", 20)
	var sbox = _make_stylebox(color.darkened(0.1))
	var hbox = _make_stylebox(color.lightened(0.15))
	var pbox = _make_stylebox(color.darkened(0.25))
	btn.add_theme_stylebox_override("normal",  sbox)
	btn.add_theme_stylebox_override("hover",   hbox)
	btn.add_theme_stylebox_override("pressed", pbox)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_left  = 10
	s.corner_radius_bottom_right = 10
	return s

func _make_button(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	_apply_style(btn, color)
	return btn

# ============================================================
# ボタンコールバック
# ============================================================
func _on_create_room_pressed() -> void:
	if FirebaseManager.id_token == "":
		_show_status("Authenticating...")
		return
	var rating  = RatingManager.my_profile.get("rating", 1000)
	var room_id = NetworkManager.create_room_with_code(rating)
	_show_waiting_dialog(room_id)

func _on_random_match_pressed() -> void:
	if FirebaseManager.id_token == "":
		_show_status("Authenticating...")
		return
	_show_status("Searching for opponent...")
	var rating = RatingManager.my_profile.get("rating", 1000)
	# Firestoreで待機中ルームを検索して参加、なければ作成
	_find_or_create_random_room(rating)

func _find_or_create_random_room(rating: int) -> void:
	# waiting状態のrandomルームを探す（簡易版：固定パスでチェック）
	var queue_path = "matchmaking_queue/random_" + str(rating / 200 * 200)
	FirebaseManager.firestore_read_completed.connect(
		_on_queue_checked.bind(rating, queue_path), CONNECT_ONE_SHOT)
	FirebaseManager.firestore_error.connect(
		_on_queue_not_found.bind(rating, queue_path), CONNECT_ONE_SHOT)
	FirebaseManager.read_document(queue_path)

func _on_queue_checked(data: Dictionary, rating: int, queue_path: String) -> void:
	var room_id    = data.get("room_id", "")
	var host_uid   = data.get("host_uid", "")
	if room_id != "" and host_uid != FirebaseManager.local_id:
		# 待機中ルームを発見 → 参加してキューを削除
		FirebaseManager.delete_document(queue_path)
		NetworkManager.join_room_with_code(room_id, rating)
		_show_status("Found opponent! Joining...")
	else:
		# 待機中ルームなし → 自分がホストとして作成してキューに登録
		_create_random_room_and_queue(rating, queue_path)

func _on_queue_not_found(_error: String, rating: int, queue_path: String) -> void:
	_create_random_room_and_queue(rating, queue_path)

func _create_random_room_and_queue(rating: int, queue_path: String) -> void:
	var room_id = NetworkManager.create_room_with_code(rating)
	var queue_data = {
		"room_id":   room_id,
		"host_uid":  FirebaseManager.local_id,
		"rating":    rating,
		"created_at": Time.get_unix_time_from_system(),
	}
	FirebaseManager.write_document(queue_path, queue_data)
	_show_status("Waiting for opponent...\nRoom: " + room_id)

func _on_join_pressed() -> void:
	var code_input = _find_code_input()
	if code_input == null or code_input.text.strip_edges() == "":
		_show_status("Please enter a room code")
		return
	var code   = code_input.text.strip_edges().to_upper()
	var rating = RatingManager.my_profile.get("rating", 1000)
	NetworkManager.join_room_with_code(code, rating)
	_show_status("Joining room %s..." % code)

func _on_refresh_pressed() -> void:
	_show_status("Ready")

func _find_code_input() -> LineEdit:
	for child in $MainContainer.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is LineEdit:
					return sub
	return null

# ============================================================
# マッチング結果
# ============================================================
func _on_match_found(room_id: String, _is_host: bool) -> void:
	print("Match found! room=", room_id)
	if _room_code_dialog != null:
		_room_code_dialog.queue_free()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_match_failed(error: String) -> void:
	_show_status("Error: " + error)

# ============================================================
# 待機ダイアログ
# ============================================================
var _room_code_dialog: Window = null

func _show_waiting_dialog(room_code: String) -> void:
	if _room_code_dialog:
		_room_code_dialog.queue_free()

	var dialog = Window.new()
	dialog.title       = "Waiting for opponent"
	dialog.size        = Vector2i(320, 220)
	dialog.unresizable = true
	dialog.close_requested.connect(func():
		NetworkManager.leave_room()
		dialog.queue_free()
		_room_code_dialog = null)
	add_child(dialog)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	dialog.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "Share this code:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl)

	var code_lbl = Label.new()
	code_lbl.text = room_code
	code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_lbl.add_theme_font_size_override("font_size", 44)
	code_lbl.add_theme_color_override("font_color", ThemeConfig.P1_COLOR)
	vbox.add_child(code_lbl)

	var sub = Label.new()
	sub.text = "Waiting for opponent..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(sub)

	dialog.popup_centered()
	_room_code_dialog = dialog

# ============================================================
# ステータス表示
# ============================================================
func _show_status(msg: String) -> void:
	for child in room_list.get_children():
		child.queue_free()
	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", ThemeConfig.UI_FONT_COLOR)
	room_list.add_child(lbl)
