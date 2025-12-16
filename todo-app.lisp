;;;; ============================================================
;;;; Todo App - Level 24-A
;;;; REPL 駆動開発を体感する
;;;;
;;;; 使い方:
;;;;   1. (load "todo-app.lisp")
;;;;   2. (todo-app:start-server)
;;;;   3. ブラウザで http://localhost:8080/
;;;; ============================================================

;;; ライブラリ読み込み
;;; - hunchentoot : Webサーバー
;;; - cl-who     : S式でHTML生成
(ql:quickload '(:hunchentoot :cl-who))

;;; パッケージ定義
;;; :use で指定したパッケージのシンボルを直接使える
;;; :export で外部に公開する関数を指定
(defpackage :todo-app
  (:use :cl :hunchentoot :cl-who)
  (:export :start-server :stop-server))

(in-package :todo-app)

;;; ==========================================================
;;; サーバー管理
;;; ==========================================================

;;; サーバーインスタンスを保持するグローバル変数
(defvar *server* nil)

;;; サーバー起動
;;; - 既存サーバーがあれば停止してから起動
;;; - easy-acceptor : Hunchentootの簡易サーバークラス
(defun start-server (&optional (port 8080))
  (when *server* (hunchentoot:stop *server*))
  (setf *server* (make-instance 'easy-acceptor :port port))
  (hunchentoot:start *server*)
  (format t "~%>>> Todo App started~%")
  (format t "    http://localhost:~A/~%~%" port))

;;; サーバー停止
(defun stop-server ()
  (when *server*
    (hunchentoot:stop *server*)
    (setf *server* nil)
    (format t "Server stopped~%")))

;;; ==========================================================
;;; データ定義
;;; ==========================================================

;;; Todo構造体
;;; defstruct で自動的に以下が生成される:
;;;   - コンストラクタ: make-todo
;;;   - アクセサ: todo-id, todo-title, todo-done, todo-created-at
;;;   - 述語: todo-p
(defstruct todo
  (id 0 :type integer)              ; 一意のID
  (title "" :type string)           ; タイトル
  (done nil :type boolean)          ; 完了フラグ
  (created-at (get-universal-time) :type integer))  ; 作成日時

;;; インメモリデータベース（リストで管理）
(defvar *todos* '())

;;; ID生成用カウンタ
(defvar *next-id* 1)

;;; 新しいIDを生成して返す
;;; prog1 : 最初の式の値を返しつつ、残りの式も実行
(defun gen-id ()
  (prog1 *next-id* (incf *next-id*)))

;;; ==========================================================
;;; CRUD操作
;;; ==========================================================

;;; Create: 新しいTodoを追加
;;; push でリストの先頭に追加（新しい順になる）
(defun add-todo (title)
  (let ((todo (make-todo :id (gen-id) :title title)))
    (push todo *todos*)
    todo))

;;; Read: 全Todo取得
(defun all-todos ()
  *todos*)

;;; Read: IDでTodo検索
;;; find : リストから条件に合う最初の要素を返す
;;; :key : 比較に使うアクセサを指定
(defun find-todo (id)
  (find id *todos* :key #'todo-id))

;;; Update: 完了状態を反転
(defun toggle-todo (id)
  (let ((todo (find-todo id)))
    (when todo
      (setf (todo-done todo) (not (todo-done todo)))
      todo)))

;;; Delete: Todoを削除
;;; remove : 条件に合う要素を除いた新しいリストを返す
(defun delete-todo (id)
  (setf *todos* (remove id *todos* :key #'todo-id))
  t)

;;; ==========================================================
;;; HTML生成
;;; ==========================================================

;;; CSSスタイル定義
(defparameter *css*
  "
body { 
  font-family: system-ui, sans-serif; 
  max-width: 600px; 
  margin: 50px auto; 
  padding: 20px;
  background: #f5f5f5;
}
h1 { color: #333; }
.stats { color: #666; margin-bottom: 20px; }
.todo-list { list-style: none; padding: 0; }
.todo-item { 
  background: white; 
  padding: 15px; 
  margin: 10px 0; 
  border-radius: 8px;
  display: flex;
  align-items: center;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
.todo-item.done { opacity: 0.6; }
.todo-item.done .title { text-decoration: line-through; }
.title { flex: 1; margin: 0 15px; }
.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  margin-left: 5px;
}
.btn-toggle { background: #4CAF50; color: white; }
.btn-delete { background: #f44336; color: white; }
.btn-add { background: #2196F3; color: white; }
form.add-form { display: flex; gap: 10px; margin: 20px 0; }
input[type=text] { 
  flex: 1; 
  padding: 10px; 
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 16px;
}
")

;;; HTMLページ生成マクロ
;;; with-html-output-to-string : HTML文字列を生成
;;; :prologue t : <!DOCTYPE html> を出力
;;; (:tag ...) : <tag>...</tag> を生成
;;; (str x) : xを文字列として出力
(defmacro with-page ((title) &body body)
  `(with-html-output-to-string (s nil :prologue t)
     (:html
      (:head 
       (:meta :charset "utf-8")
       (:title ,title)
       (:style (str *css*)))
      (:body ,@body))))

;;; ==========================================================
;;; ルーティング（ハンドラ定義）
;;; ==========================================================

;;; トップページ: Todo一覧表示
;;; define-easy-handler : URLとハンドラ関数を紐付け
;;; :uri "/" : ルートパスにマッピング
(define-easy-handler (index :uri "/") ()
  (setf (content-type*) "text/html; charset=utf-8")
  (with-page ("Todo App")
    (:h1 "Todo List")
    
    ;; 統計情報
    ;; count-if : 条件を満たす要素数をカウント
    (let* ((todos (all-todos))
           (total (length todos))
           (done (count-if #'todo-done todos)))
      (htm  ; htm : with-html-output 内でHTMLを追加出力
       (:p :class "stats"
         (fmt "Total: ~A / Done: ~A / Remaining: ~A"
              total done (- total done)))))
    
    ;; 追加フォーム
    ;; :action : 送信先URL
    ;; :method "post" : POSTリクエスト
    (:form :action "/add" :method "post" :class "add-form"
      (:input :type "text" :name "title" 
              :placeholder "Enter new todo..." 
              :required t)
      (:button :type "submit" :class "btn btn-add" "Add"))
    
    ;; Todo一覧
    ;; format の ~@[ ... ~] : 引数が非nilの場合のみ出力
    (let ((todos (all-todos)))
      (if todos
          (htm
           (:ul :class "todo-list"
            (dolist (todo todos)
              (htm
               (:li :class (format nil "todo-item~@[ done~]" (todo-done todo))
                (:span :class "title" (str (todo-title todo)))
                ;; 完了/未完了トグルボタン
                (:form :action "/toggle" :method "post" 
                       :style "display:inline"
                  (:input :type "hidden" :name "id" 
                          :value (todo-id todo))
                  (:button :type "submit" :class "btn btn-toggle"
                    (str (if (todo-done todo) "Undo" "Done"))))
                ;; 削除ボタン
                (:form :action "/delete" :method "post" 
                       :style "display:inline"
                  (:input :type "hidden" :name "id" 
                          :value (todo-id todo))
                  (:button :type "submit" :class "btn btn-delete" 
                    "Del")))))))
          (htm
           (:p "No todos yet. Add one!"))))))

;;; Todo追加アクション
;;; post-parameter : POSTデータから値を取得
;;; redirect : 指定URLにリダイレクト
(define-easy-handler (add-action :uri "/add") ()
  (let ((title (post-parameter "title")))
    (when (and title (> (length title) 0))
      (add-todo title)))
  (redirect "/"))

;;; 完了/未完了トグルアクション
;;; ignore-errors : エラー時にnilを返す
(define-easy-handler (toggle-action :uri "/toggle") ()
  (let ((id (ignore-errors (parse-integer (post-parameter "id")))))
    (when id (toggle-todo id)))
  (redirect "/"))

;;; 削除アクション
(define-easy-handler (delete-action :uri "/delete") ()
  (let ((id (ignore-errors (parse-integer (post-parameter "id")))))
    (when id (delete-todo id)))
  (redirect "/"))

;;; ==========================================================
;;; 起動メッセージ
;;; ==========================================================

(format t "~%todo-app.lisp loaded.~%")
(format t "Usage: (todo-app:start-server)~%")
