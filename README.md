# Common Lisp 入門 Level 24：Web アプリケーション開発

Common Lisp で Web アプリケーションを開発する教材です。REPL 駆動開発の利点を体感しながら、実践的な Todo アプリを構築します。

## 概要

| Level | テーマ | 内容 |
|-------|--------|------|
| 24-A | REPL 駆動開発入門 | 最小構成の Todo アプリで Lisp の開発体験を学ぶ |
| 24-B | マルチユーザー対応 | 認証・セッション・永続化を実装 |

## ファイル構成

```
.
├── README.md                      # このファイル
├── level24a-web-repl-driven.md    # Level 24-A 教材
├── level24b-multi-user-todo.md    # Level 24-B 教材
├── src/
│   ├── todo-app.lisp              # 24-A 完成コード（シンプル版）
│   └── todo-app-full.lisp         # 24-B 完成コード（フル機能版）
└── diagrams/
    └── todo-app-diagrams.md       # Mermaid 図（補足資料）
```

## 必要な環境

- **SBCL** (Steel Bank Common Lisp) 2.0 以上
- **Quicklisp** パッケージマネージャー

### 必要なライブラリ

| ライブラリ | 用途 | Level |
|-----------|------|-------|
| Hunchentoot | Web サーバー | 24-A, 24-B |
| CL-WHO | HTML 生成 | 24-A, 24-B |
| Ironclad | パスワードハッシュ | 24-B |
| Babel | 文字エンコーディング | 24-B |

## クイックスタート

### Level 24-A（シンプル版）

```lisp
;; 1. ライブラリ読み込み
(ql:quickload '(:hunchentoot :cl-who))

;; 2. アプリ読み込み
(load "src/todo-app.lisp")

;; 3. サーバー起動
(todo-app:start-server)

;; 4. ブラウザでアクセス
;;    http://localhost:8080/
```

### Level 24-B（フル機能版）

```lisp
;; 1. ライブラリ読み込み
(ql:quickload '(:hunchentoot :cl-who :ironclad :babel))

;; 2. アプリ読み込み
(load "src/todo-app-full.lisp")

;; 3. サーバー起動
(todo-app:start-server)

;; 4. ブラウザでアクセス
;;    http://localhost:8080/
```

## 学習内容

### Level 24-A で学ぶこと

```
┌─────────────────────────────────────────────────────────────┐
│  体験1: サーバーを止めずに機能追加                          │
│  体験2: エラーが起きてもプロセスが生き続ける                │
│  体験3: データを保持したままコードを改善                    │
└─────────────────────────────────────────────────────────────┘
```

- Hunchentoot による Web サーバー構築
- CL-WHO による S 式 → HTML 変換
- REPL からのライブコーディング
- インタラクティブデバッグ

### Level 24-B で学ぶこと

- ユーザー認証（登録・ログイン・ログアウト）
- セッション管理（Cookie ベース）
- パスワードのハッシュ化（SHA-256）
- データ永続化（S 式ファイル）
- マルチユーザー対応の CRUD
- コメント機能

## 従来の Web 開発との比較

| シナリオ | Node.js / Python | Common Lisp |
|----------|------------------|-------------|
| 新しいページ追加 | サーバー再起動 | **即座に反映** |
| バグ修正 | サーバー再起動 | **即座に反映** |
| 本番エラー | クラッシュ → ログ確認 | **対話的デバッグ** |
| UI 微調整 | 再起動 → データ消失 | **データ保持** |

## URL 一覧

### Level 24-A

| URL | メソッド | 機能 |
|-----|----------|------|
| `/` | GET | Todo 一覧 |
| `/add` | POST | Todo 追加 |
| `/toggle` | POST | 完了/未完了切替 |
| `/delete` | POST | Todo 削除 |

### Level 24-B

| URL | メソッド | 機能 |
|-----|----------|------|
| `/` | GET | 公開 Todo 一覧 |
| `/register` | GET/POST | ユーザー登録 |
| `/login` | GET/POST | ログイン |
| `/logout` | GET | ログアウト |
| `/mypage` | GET | マイページ |
| `/todo/add` | POST | Todo 追加 |
| `/todo/toggle` | POST | 完了/未完了切替 |
| `/todo/public` | POST | 公開/非公開切替 |
| `/todo/delete` | POST | Todo 削除 |
| `/view?id=N` | GET | Todo 詳細・コメント |
| `/comment/add` | POST | コメント追加 |

## 練習問題

### Level 24-A

1. **優先度機能**: Todo に優先度（高/中/低）を追加
2. **検索機能**: キーワードで Todo を検索
3. **期限機能**: 期限を設定し、超過した Todo を強調表示

### Level 24-B

1. **Todo 編集機能**: タイトルを後から編集
2. **いいね機能**: 公開 Todo に「いいね」
3. **検索機能**: 全体検索

## 参考資料

- [Hunchentoot Documentation](https://edicl.github.io/hunchentoot/)
- [CL-WHO Manual](https://edicl.github.io/cl-who/)
- [Ironclad - Cryptographic Library](https://github.com/sharplispers/ironclad)
- [Practical Common Lisp](https://gigamonkeys.com/book/)

## ライセンス

MIT License

## 作成者

Common Lisp 入門教材シリーズ Level 24
