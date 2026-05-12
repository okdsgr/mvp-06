## firebase_config.template.gd
## Firebase接続設定のテンプレート。
## ⚠️ このファイル自体は実行されません（class_name宣言なし）。
##
## セットアップ手順:
##   1. このファイルを scripts/firebase_config.gd という名前でコピーする
##      （firebase_config.gd は .gitignore で除外されているのでcommitされない）
##   2. コピー先で API_KEY を実際の値に書き換える
##   3. コピー先のファイル先頭付近に `class_name FirebaseConfig` の行を追加する
##
## 実体ファイル (firebase_config.gd) 側で class_name FirebaseConfig を宣言する。
## このテンプレートには class_name を書かない（重複定義によるParse Errorを避けるため）。

const API_KEY    := "YOUR_API_KEY_HERE"
const PROJECT_ID := "xatatron"
const BASE_URL   := "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents"
const AUTH_URL   := "https://identitytoolkit.googleapis.com/v1/accounts"
