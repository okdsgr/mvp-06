## firebase_manager.gd
## Firebase匿名認証 + Firestore REST API を管理する。
## AutoLoadに登録して使用する。

extends Node

signal auth_completed(uid: String)
signal auth_failed(error: String)
signal firestore_read_completed(data: Dictionary)
signal firestore_write_completed
signal firestore_error(error: String)

var id_token: String = ""
var local_id: String = ""

# ============================================================
# 匿名認証
# ============================================================
func sign_in_anonymous() -> void:
	var url = FirebaseConfig.AUTH_URL + ":signUp?key=" + FirebaseConfig.API_KEY
	var body = JSON.stringify({"returnSecureToken": true})
	var headers = ["Content-Type: application/json"]
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_auth_completed.bind(req))
	req.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_auth_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		auth_failed.emit("Auth HTTP error: %d" % code)
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		auth_failed.emit("Auth JSON parse error")
		return
	var data = json.get_data()
	id_token = data.get("idToken", "")
	local_id  = data.get("localId", "")
	if id_token == "":
		auth_failed.emit("No idToken in response")
		return
	auth_completed.emit(local_id)

# ============================================================
# Firestore CRUD
# ============================================================
func read_document(path: String) -> void:
	var url = FirebaseConfig.BASE_URL + "/" + path + "?key=" + FirebaseConfig.API_KEY
	var headers = ["Authorization: Bearer " + id_token]
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_read_completed.bind(req))
	req.request(url, headers, HTTPClient.METHOD_GET)

func _on_read_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		firestore_error.emit("Read error: %d" % code)
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		firestore_error.emit("Read JSON parse error")
		return
	firestore_read_completed.emit(_parse_firestore_doc(json.get_data()))

func write_document(path: String, data: Dictionary) -> void:
	var url = FirebaseConfig.BASE_URL + "/" + path + "?key=" + FirebaseConfig.API_KEY
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token,
	]
	var body = JSON.stringify({"fields": _to_firestore_fields(data)})
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_write_completed.bind(req))
	req.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _on_write_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		firestore_error.emit("Write error: %d" % code)
		return
	firestore_write_completed.emit()

func delete_document(path: String) -> void:
	var url = FirebaseConfig.BASE_URL + "/" + path + "?key=" + FirebaseConfig.API_KEY
	var headers = ["Authorization: Bearer " + id_token]
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_delete_completed.bind(req))
	req.request(url, headers, HTTPClient.METHOD_DELETE)

func _on_delete_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		firestore_error.emit("Delete error: %d" % code)

# ============================================================
# Firestore型変換
# ============================================================
func _to_firestore_fields(data: Dictionary) -> Dictionary:
	var fields = {}
	for key in data:
		fields[key] = _to_firestore_value(data[key])
	return fields

func _to_firestore_value(val) -> Dictionary:
	if val is String:
		return {"stringValue": val}
	elif val is int:
		return {"integerValue": str(val)}
	elif val is float:
		return {"doubleValue": val}
	elif val is bool:
		return {"booleanValue": val}
	elif val is Array:
		var arr = []
		for item in val:
			arr.append(_to_firestore_value(item))
		return {"arrayValue": {"values": arr}}
	elif val is Dictionary:
		return {"mapValue": {"fields": _to_firestore_fields(val)}}
	return {"stringValue": str(val)}

func _parse_firestore_doc(doc: Dictionary) -> Dictionary:
	var result = {}
	var fields = doc.get("fields", {})
	for key in fields:
		result[key] = _parse_firestore_value(fields[key])
	return result

func _parse_firestore_value(val: Dictionary):
	if val.has("stringValue"):
		return val["stringValue"]
	elif val.has("integerValue"):
		return int(val["integerValue"])
	elif val.has("doubleValue"):
		return float(val["doubleValue"])
	elif val.has("booleanValue"):
		return val["booleanValue"]
	elif val.has("arrayValue"):
		var arr = []
		for item in val["arrayValue"].get("values", []):
			arr.append(_parse_firestore_value(item))
		return arr
	elif val.has("mapValue"):
		return _parse_firestore_doc(val["mapValue"])
	return null
