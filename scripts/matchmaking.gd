extends Control

@onready var room_list: VBoxContainer = $MainContainer/ScrollContainer/RoomList
@onready var create_room_button: Button = $MainContainer/ButtonContainer/CreateRoomButton
@onready var refresh_button: Button = $MainContainer/ButtonContainer/RefreshButton

func _ready() -> void:
	create_room_button.pressed.connect(_on_create_room_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	
	_apply_theme()
	_load_rooms()

func _apply_theme() -> void:
	var title_label: Label = $MainContainer/TitleLabel
	title_label.add_theme_font_size_override("font_size", 32)

func _load_rooms() -> void:
	# TODO: Phase 2 - Fetch rooms from Firestore
	print("Loading rooms...")

func _on_create_room_pressed() -> void:
	# TODO: Phase 2 - Create room logic
	print("Create room pressed")

func _on_refresh_pressed() -> void:
	_load_rooms()
