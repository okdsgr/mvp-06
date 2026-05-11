## firebase_config.gd
## Firebase接続設定。APIキーなどの定数を管理する。
## ⚠️ このファイルはGitで管理しません。
## firebase_config.template.gd をコピーしてAPIキーを入力してください。

class_name FirebaseConfig

const API_KEY    := "YOUR_API_KEY_HERE"
const PROJECT_ID := "xatatron"
const BASE_URL   := "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents"
const AUTH_URL   := "https://identitytoolkit.googleapis.com/v1/accounts"
