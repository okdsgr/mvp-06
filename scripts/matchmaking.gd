## matchmaking.gd
## マッチメイキング画面。ランダムマッチ・ルームコード対戦の両方に対応。

extends Control

# --- UIノード参照 ---
@onready var title_label:       Label         = $MainContainer/TitleLabel
@onready var room_list:         VBoxContainer = $MainContainer/ScrollContainer/RoomList
@onready var create_room_btn:   Button        = $MainContainer/ButtonContainer/CreateRoomButton
@onready var refresh_btn:       Button        = $MainContainer/ButtonContainer/RefreshButton

# --- 状態 ---
var _room_code_dialog: Window = null

func _ready() -> void:
	create_room_btn.pressed.connect(_on_create_room_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	NetworkManager.match_found.connect(_on_match_found)
	NetworkManager.match_failed.connect(_on_match_failed)
	_apply_theme()
	_build_ui()
	# 認証してからルーム一覧を取得
	if FirebaseManager.id_token == "":
		FirebaseManager.auth_completed.connect(_on_auth_done, CONNECT_ONE_SHOT)
		FirebaseManager.sign_in_anonymous()
	else:
		_refresh_ui()

func _on_auth_done(_uid: String) -> void:
	_refresh_ui()

func _apply_theme() -> void:
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", ThemeConfig.UI_FONT_COLOR)

# ============================================================
# UI構築
# ============================================================
func _build_ui() -> void:
	# ランダムマッチボタンを追加
	var random_btn = _make_button("RANDOM MATCH", ThemeConfig.P1_COLOR)
	random_btn.pressed.connect(_on_random_match_pressed)
	$MainContainer/ButtonContainer.add_child(random_btn)

	# ルームコード入力エリアを追加
	var code_container = HBoxContainer.new()
	code_container.alignment = BoxContainer.ALIGNMENT_CENTER
	code_container.add_theme_constant_override("separation", 12)
	$MainContainer.add_child(code_container)

	var code_input = LineEdit.new()
	code_input.name             = "CodeInput"
	code_input.placeholder_text = "Enter Room Code"
	code_input.max_length       = 6
	code_input.custom_minimum_size = Vector2(180, 48)
	code_input.add_theme_font_size_override("font_size", 20)
	code_container.add_child(code_input)

	var join_btn = _make_button("JOIN", ThemeConfig.P2_COLOR)
	join_btn.custom_minimum_size = Vector2(80, 48)
	join_btn.pressed.connect(_on_join_pressed)
	code_container.add_child(join_btn)

func _make_button(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(160, 52)
	btn.add_theme_font_size_override("font_size", 20)
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = color.darkened(0.1)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sbox.set("corner_radius_" + corner, 10)
	var hbox = sbox.duplicate()
	hbox.bg_color = color.lightened(0.15)
	var pbox = sbox.duplicate()
	pbox.bg_color = color.darkened(0.25)
	btn.add_theme_stylebox_override("normal",  sbox)
	btn.add_theme_stylebox_override("hover",   hbox)
	btn.add_theme_stylebox_override("pressed", pbox)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ============================================================
# ボタンコールバック
# ============================================================
func _on_create_room_pressed() -> void:
	var rating  = RatingManager.my_profile.get("rating", 1000)
	var room_id = NetworkManager.create_room_with_code(rating)
	_show_waiting_dialog(room_id)

func _on_random_match_pressed() -> void:
	var rating = RatingManager.my_profile.get("rating", 1000)
	NetworkManager.start_random_match(rating)
	_show_status("Searching for opponent...")

func _on_join_pressed() -> void:
	var code_input = get_node_or_null("MainContainer/CodeInput")
	if code_input == null:
		# HBoxContainerの中を探す
		for child in $MainContainer.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is LineEdit:
						code_input = sub
						break
	if code_input == null or code_input.text.strip_edges() == "":
		_show_status("Please enter a room code")
		return
	var code   = code_input.text.strip_edges().to_upper()
	var rating = RatingManager.my_profile.get("rating", 1000)
	NetworkManager.join_room_with_code(code, rating)
	_show_status("Joining room %s..." % code)

func _on_refresh_pressed() -> void:
	_refresh_ui()

# ============================================================
# マッチング結果
# ============================================================
func _on_match_found(room_id: String, _is_host: bool) -> void:
	print("Match found! room=", room_id)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_match_failed(error: String) -> void:
	_show_status("Error: " + error)

# ============================================================
# 待機ダイアログ（ルームコード表示）
# ============================================================
func _show_waiting_dialog(room_code: String) -> void:
	if _room_code_dialog:
		_room_code_dialog.queue_free()
	var dialog = Window.new()
	dialog.title            = "Waiting for opponent"
	dialog.size             = Vector2i(320, 200)
	dialog.position         = Vector2i(80, 320)
	dialog.unresizable      = true
	dialog.close_requested.connect(func():
		NetworkManager.leave_room()
		dialog.queue_free())
	add_child(dialog)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	dialog.add_child(vbox)

	var lbl = Label.new()
	lbl.text                 = "Room Code:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl)

	var code_lbl = Label.new()
	code_lbl.text                 = room_code
	code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_lbl.add_theme_font_size_override("font_size", 40)
	code_lbl.add_theme_color_override("font_color", ThemeConfig.P1_COLOR)
	vbox.add_child(code_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text                 = "Share this code with your friend"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(sub_lbl)

	dialog.popup_centered()
	_room_code_dialog = dialog

# ============================================================
# ステータス表示
# ============================================================
func _show_status(msg: String) -> void:
	# room_listの先頭に一時表示
	for child in room_list.get_children():
		child.queue_free()
	var lbl = Label.new()
	lbl.text                 = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", ThemeConfig.UI_FONT_COLOR)
	room_list.add_child(lbl)

func _refresh_ui() -> void:
	_show_status("Ready to play")
