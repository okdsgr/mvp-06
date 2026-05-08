## rating_manager.gd
## ELOレーティング計算・ユーザープロフィール管理。AutoLoad登録。

extends Node

signal profile_loaded(profile: Dictionary)
signal profile_saved

const INITIAL_RATING := 1000
const K_BEGINNER     := 40
const K_NORMAL       := 20
const K_MASTER       := 10
const BEGINNER_GAMES := 30
const STREAK_BONUS   := {3: 5, 5: 10, 10: 20}

var my_profile: Dictionary = {}

func _ready() -> void:
	FirebaseManager.auth_completed.connect(_on_auth_ready)

func _on_auth_ready(_uid: String) -> void:
	load_profile()

func load_profile() -> void:
	var uid = FirebaseManager.local_id
	if uid == "":
		return
	FirebaseManager.firestore_read_completed.connect(_on_profile_loaded, CONNECT_ONE_SHOT)
	FirebaseManager.read_document("users/" + uid)

func _on_profile_loaded(data: Dictionary) -> void:
	if data.is_empty():
		my_profile = _create_default_profile()
		save_profile()
	else:
		my_profile = data
	profile_loaded.emit(my_profile)

func save_profile() -> void:
	var uid = FirebaseManager.local_id
	if uid == "":
		return
	FirebaseManager.firestore_write_completed.connect(
		func(): profile_saved.emit(), CONNECT_ONE_SHOT)
	FirebaseManager.write_document("users/" + uid, my_profile)

func _create_default_profile() -> Dictionary:
	return {
		"uid":            FirebaseManager.local_id,
		"rating":         INITIAL_RATING,
		"total_games":    0,
		"wins":           0,
		"losses":         0,
		"draws":          0,
		"current_streak": 0,
		"max_streak":     0,
		"daily_streak":   0,
		"last_win_date":  "",
		"monthly_wins":   0,
		"weekly_wins":    0,
		"created_at":     Time.get_unix_time_from_system(),
	}

func expected_score(my_rating: int, opp_rating: int) -> float:
	return 1.0 / (1.0 + pow(10.0, float(opp_rating - my_rating) / 400.0))

func get_k(total_games: int, rating: int) -> int:
	if total_games < BEGINNER_GAMES:
		return K_BEGINNER
	if rating >= 1800:
		return K_MASTER
	return K_NORMAL

func calc_rating_delta(my_rating: int, opp_rating: int, result: float, total_games: int, win_streak: int) -> int:
	var k     = get_k(total_games, my_rating)
	var exp   = expected_score(my_rating, opp_rating)
	var delta = int(round(float(k) * (result - exp)))
	if result == 1.0:
		for streak_req in STREAK_BONUS:
			if win_streak >= streak_req:
				delta += STREAK_BONUS[streak_req]
	return delta

func apply_match_result(opp_rating: int, result_for_me: float) -> int:
	var old_rating  = my_profile.get("rating", INITIAL_RATING)
	var total_games = my_profile.get("total_games", 0)
	var win_streak  = my_profile.get("current_streak", 0)
	var delta       = calc_rating_delta(old_rating, opp_rating, result_for_me, total_games, win_streak)
	my_profile["rating"]      = max(0, old_rating + delta)
	my_profile["total_games"] = total_games + 1
	if result_for_me == 1.0:
		my_profile["wins"]           = my_profile.get("wins", 0) + 1
		my_profile["current_streak"] = win_streak + 1
		my_profile["monthly_wins"]   = my_profile.get("monthly_wins", 0) + 1
		my_profile["weekly_wins"]    = my_profile.get("weekly_wins", 0) + 1
		if my_profile["current_streak"] > my_profile.get("max_streak", 0):
			my_profile["max_streak"] = my_profile["current_streak"]
		_update_daily_streak()
	elif result_for_me == 0.0:
		my_profile["losses"]         = my_profile.get("losses", 0) + 1
		my_profile["current_streak"] = 0
	else:
		my_profile["draws"]          = my_profile.get("draws", 0) + 1
		my_profile["current_streak"] = 0
	save_profile()
	return delta

func _update_daily_streak() -> void:
	var today     = Time.get_date_string_from_system()
	var last      = my_profile.get("last_win_date", "")
	if last == today:
		return
	var yesterday = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	if last == yesterday:
		my_profile["daily_streak"] = my_profile.get("daily_streak", 0) + 1
	else:
		my_profile["daily_streak"] = 1
	my_profile["last_win_date"] = today

func get_rank(rating: int) -> String:
	if rating >= 2100: return "XATATRON"
	if rating >= 1800: return "Master"
	if rating >= 1500: return "Expert"
	if rating >= 1200: return "Advanced"
	return "Beginner"

func get_max_tables(rating: int) -> int:
	match get_rank(rating):
		"XATATRON": return 30
		"Master":   return 20
		"Expert":   return 10
		"Advanced": return 5
		_:          return 3
