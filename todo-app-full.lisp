;;;; ============================================================
;;;; Todo App - Level 24-B (Multi-user)
;;;; マルチユーザー対応 Todo アプリ
;;;;
;;;; 使い方:
;;;;   1. (ql:quickload '(:hunchentoot :cl-who :ironclad :babel))
;;;;   2. (load "todo-app-full.lisp")
;;;;   3. (todo-app:start-server)
;;;;   4. http://localhost:8080/
;;;; ============================================================

(ql:quickload '(:hunchentoot :cl-who :ironclad :babel))

(defpackage :todo-app
  (:use :cl :cl-who)
  (:import-from :hunchentoot
                :define-easy-handler
                :easy-acceptor
                :content-type*
                :post-parameter
                :get-parameter
                :redirect
                :session-value
                :start-session
                :request-uri*
                :request-method*
                :script-name*)
  (:export :start-server :stop-server :save-data :load-data))

(in-package :todo-app)

;;; ==========================================================
;;; データ構造
;;; ==========================================================

;;; ユーザー
(defstruct user
  (id 0 :type integer)
  (username "" :type string)
  (password-hash "" :type string)
  (created-at (get-universal-time) :type integer))

;;; Todo
(defstruct todo
  (id 0 :type integer)
  (user-id 0 :type integer)
  (title "" :type string)
  (done nil :type boolean)
  (public nil :type boolean)
  (created-at (get-universal-time) :type integer))

;;; コメント (comment は予約語)
(defstruct comment*
  (id 0 :type integer)
  (todo-id 0 :type integer)
  (user-id 0 :type integer)
  (content "" :type string)
  (created-at (get-universal-time) :type integer))

;;; ==========================================================
;;; インメモリデータベース
;;; ==========================================================

(defvar *users* '())
(defvar *todos* '())
(defvar *comments* '())

(defvar *next-user-id* 1)
(defvar *next-todo-id* 1)
(defvar *next-comment-id* 1)

(defun gen-user-id ()
  (prog1 *next-user-id* (incf *next-user-id*)))

(defun gen-todo-id ()
  (prog1 *next-todo-id* (incf *next-todo-id*)))

(defun gen-comment-id ()
  (prog1 *next-comment-id* (incf *next-comment-id*)))

;;; ==========================================================
;;; パスワード処理
;;; ==========================================================

;;; SHA-256 ハッシュ化
(defun hash-password (password)
  (let ((digest (ironclad:make-digest :sha256)))
    (ironclad:update-digest digest 
                            (babel:string-to-octets password :encoding :utf-8))
    (ironclad:byte-array-to-hex-string 
     (ironclad:produce-digest digest))))

;;; パスワード検証
(defun verify-password (password hash)
  (string= (hash-password password) hash))

;;; ==========================================================
;;; ユーザー CRUD
;;; ==========================================================

(defun create-user (username password)
  (let ((user (make-user :id (gen-user-id)
                         :username username
                         :password-hash (hash-password password))))
    (push user *users*)
    user))

(defun find-user-by-name (username)
  (find username *users* :key #'user-username :test #'string=))

(defun find-user-by-id (id)
  (find id *users* :key #'user-id))

(defun username-exists-p (username)
  (not (null (find-user-by-name username))))

(defun authenticate (username password)
  (let ((user (find-user-by-name username)))
    (when (and user (verify-password password (user-password-hash user)))
      user)))

;;; ==========================================================
;;; セッション管理
;;; ==========================================================

(defun current-user ()
  (let ((user-id (session-value :user-id)))
    (when user-id
      (find-user-by-id user-id))))

(defun login (user)
  (start-session)
  (setf (session-value :user-id) (user-id user)))

(defun logout ()
  (setf (session-value :user-id) nil))

(defun logged-in-p ()
  (not (null (current-user))))

;;; ==========================================================
;;; Todo CRUD
;;; ==========================================================

(defun add-todo (user-id title &key (public nil))
  (let ((todo (make-todo :id (gen-todo-id)
                         :user-id user-id
                         :title title
                         :public public)))
    (push todo *todos*)
    todo))

(defun user-todos (user-id)
  (remove-if-not (lambda (todo)
                   (= (todo-user-id todo) user-id))
                 *todos*))

(defun public-todos ()
  (remove-if-not #'todo-public *todos*))

(defun find-todo (id)
  (find id *todos* :key #'todo-id))

(defun toggle-todo (id user-id)
  (let ((todo (find-todo id)))
    (when (and todo (= (todo-user-id todo) user-id))
      (setf (todo-done todo) (not (todo-done todo)))
      todo)))

(defun toggle-public (id user-id)
  (let ((todo (find-todo id)))
    (when (and todo (= (todo-user-id todo) user-id))
      (setf (todo-public todo) (not (todo-public todo)))
      todo)))

(defun delete-todo (id user-id)
  (let ((todo (find-todo id)))
    (when (and todo (= (todo-user-id todo) user-id))
      (setf *todos* (remove id *todos* :key #'todo-id))
      t)))

;;; ==========================================================
;;; コメント CRUD
;;; ==========================================================

(defun add-comment (todo-id user-id content)
  (let ((comment (make-comment* :id (gen-comment-id)
                                :todo-id todo-id
                                :user-id user-id
                                :content content)))
    (push comment *comments*)
    comment))

(defun todo-comments (todo-id)
  (sort (remove-if-not (lambda (c)
                         (= (comment*-todo-id c) todo-id))
                       *comments*)
        #'<
        :key #'comment*-created-at))

;;; ==========================================================
;;; 永続化
;;; ==========================================================

(defparameter *data-dir* "data/")

(defun ensure-data-dir ()
  (ensure-directories-exist *data-dir*))

(defun save-data ()
  (ensure-data-dir)
  (with-open-file (out (merge-pathnames "users.dat" *data-dir*)
                       :direction :output :if-exists :supersede)
    (print (list *users* *next-user-id*) out))
  (with-open-file (out (merge-pathnames "todos.dat" *data-dir*)
                       :direction :output :if-exists :supersede)
    (print (list *todos* *next-todo-id*) out))
  (with-open-file (out (merge-pathnames "comments.dat" *data-dir*)
                       :direction :output :if-exists :supersede)
    (print (list *comments* *next-comment-id*) out))
  (format t "Data saved.~%"))

(defun load-data ()
  (ensure-data-dir)
  (let ((path (merge-pathnames "users.dat" *data-dir*)))
    (when (probe-file path)
      (with-open-file (in path)
        (let ((data (read in)))
          (setf *users* (first data)
                *next-user-id* (second data))))))
  (let ((path (merge-pathnames "todos.dat" *data-dir*)))
    (when (probe-file path)
      (with-open-file (in path)
        (let ((data (read in)))
          (setf *todos* (first data)
                *next-todo-id* (second data))))))
  (let ((path (merge-pathnames "comments.dat" *data-dir*)))
    (when (probe-file path)
      (with-open-file (in path)
        (let ((data (read in)))
          (setf *comments* (first data)
                *next-comment-id* (second data))))))
  (format t "Data loaded.~%"))

;;; 自動保存マクロ
(defmacro with-save (&body body)
  `(prog1 (progn ,@body)
     (save-data)))

;;; ==========================================================
;;; HTML 生成
;;; ==========================================================

(defparameter *css*
  "
* { box-sizing: border-box; }
body { 
  font-family: system-ui, sans-serif; 
  max-width: 800px; 
  margin: 0 auto; 
  padding: 20px;
  background: #f0f2f5;
}
header {
  background: #1a73e8;
  color: white;
  padding: 15px 20px;
  margin: -20px -20px 20px -20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
header a { color: white; margin-left: 15px; text-decoration: none; }
header a:hover { text-decoration: underline; }
h1, h2 { color: #333; }
.card {
  background: white;
  padding: 20px;
  margin: 15px 0;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}
.todo-item {
  padding: 15px;
  margin: 10px 0;
  border-radius: 8px;
  background: #fafafa;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 5px;
}
.todo-item.done { opacity: 0.6; }
.todo-item.done .title { text-decoration: line-through; }
.title { flex: 1; margin: 0 15px; min-width: 200px; }
.title a { color: #1a73e8; text-decoration: none; }
.title a:hover { text-decoration: underline; }
.meta { color: #666; font-size: 0.9em; }
.public-badge {
  background: #4CAF50;
  color: white;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 0.8em;
}
.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  margin: 2px;
}
.btn-primary { background: #1a73e8; color: white; }
.btn-success { background: #4CAF50; color: white; }
.btn-danger { background: #f44336; color: white; }
.btn-secondary { background: #757575; color: white; }
form.inline { display: inline; }
label { display: block; margin-top: 10px; color: #555; }
input[type=text], input[type=password], textarea {
  width: 100%;
  padding: 10px;
  margin: 5px 0 15px 0;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 16px;
}
textarea { resize: vertical; }
.comment {
  padding: 10px;
  margin: 10px 0;
  border-left: 3px solid #1a73e8;
  background: #f8f9fa;
}
.comment .author { font-weight: bold; }
.comment .date { color: #666; font-size: 0.8em; }
.error { color: #f44336; margin: 10px 0; padding: 10px; background: #ffebee; border-radius: 4px; }
.success { color: #4CAF50; margin: 10px 0; padding: 10px; background: #e8f5e9; border-radius: 4px; }
.checkbox-label { display: inline; margin-left: 5px; }
")

;;; ページレイアウトマクロ
(defmacro with-page ((title) &body body)
  `(with-html-output-to-string (s nil :prologue t)
     (:html
      (:head
       (:meta :charset "utf-8")
       (:meta :name "viewport" :content "width=device-width, initial-scale=1")
       (:title ,title)
       (:style (str *css*)))
      (:body
       (:header
        (:a :href "/" (:strong "Todo App"))
        (:nav
         (if (logged-in-p)
             (htm
              (:span (fmt "~A" (user-username (current-user))))
              (:a :href "/mypage" "MyPage")
              (:a :href "/logout" "Logout"))
             (htm
              (:a :href "/login" "Login")
              (:a :href "/register" "Register")))))
       ,@body))))

;;; ヘルパー
(defun format-time (universal-time)
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time universal-time)
    (declare (ignore sec))
    (format nil "~4,'0D/~2,'0D/~2,'0D ~2,'0D:~2,'0D"
            year month day hour min)))

(defun split-uri (uri)
  (remove "" (uiop:split-string uri :separator "/") :test #'string=))

;;; ==========================================================
;;; ハンドラ: 認証
;;; ==========================================================

;;; ログインページ & 処理
(define-easy-handler (login-handler :uri "/login") ()
  (setf (content-type*) "text/html; charset=utf-8")
  ;; POSTリクエストの場合：認証処理
  (when (eq (request-method*) :post)
    (let* ((username (post-parameter "username"))
           (password (post-parameter "password"))
           (user (authenticate username password)))
      (if user
          (progn
            (login user)
            (redirect "/mypage"))
          (redirect "/login?error=Invalid%20username%20or%20password"))
      (return-from login-handler)))
  ;; GETリクエストの場合：フォーム表示
  (let ((error-msg (get-parameter "error")))
    (with-page ("Login")
      (:div :class "card"
        (:h2 "Login")
        (when error-msg
          (htm (:p :class "error" (str error-msg))))
        (:form :action "/login" :method "post"
          (:label "Username")
          (:input :type "text" :name "username" :required t)
          (:label "Password")
          (:input :type "password" :name "password" :required t)
          (:button :type "submit" :class "btn btn-primary" "Login"))
        (:p (:a :href "/register" "Create account"))))))

;;; 登録ページ & 処理
(define-easy-handler (register-handler :uri "/register") ()
  (setf (content-type*) "text/html; charset=utf-8")
  ;; POSTリクエストの場合：登録処理
  (when (eq (request-method*) :post)
    (let ((username (post-parameter "username"))
          (password (post-parameter "password")))
      (cond
        ((or (null username) (< (length username) 1))
         (redirect "/register?error=Username%20required"))
        ((or (null password) (< (length password) 4))
         (redirect "/register?error=Password%20must%20be%204%2B%20chars"))
        ((username-exists-p username)
         (redirect "/register?error=Username%20already%20taken"))
        (t
         (let ((user (with-save (create-user username password))))
           (login user)
           (redirect "/mypage"))))
      (return-from register-handler)))
  ;; GETリクエストの場合：フォーム表示
  (let ((error-msg (get-parameter "error")))
    (with-page ("Register")
      (:div :class "card"
        (:h2 "Create Account")
        (when error-msg
          (htm (:p :class "error" (str error-msg))))
        (:form :action "/register" :method "post"
          (:label "Username")
          (:input :type "text" :name "username" :required t)
          (:label "Password (4+ characters)")
          (:input :type "password" :name "password" :required t)
          (:button :type "submit" :class "btn btn-primary" "Register"))
        (:p (:a :href "/login" "Already have an account?"))))))

;;; ログアウト
(define-easy-handler (logout-action :uri "/logout") ()
  (logout)
  (redirect "/"))

;;; ==========================================================
;;; ハンドラ: トップページ
;;; ==========================================================

(define-easy-handler (index :uri "/") ()
  (setf (content-type*) "text/html; charset=utf-8")
  (with-page ("Todo App")
    (:h1 "Public Todos")
    (let ((todos (public-todos)))
      (if todos
          (htm
           (:div :class "card"
            (dolist (todo todos)
              (let ((owner (find-user-by-id (todo-user-id todo))))
                (htm
                 (:div :class (format nil "todo-item~@[ done~]" (todo-done todo))
                   (:span :class "title"
                     (:a :href (format nil "/view?id=~A" (todo-id todo))
                       (str (todo-title todo))))
                   (:span :class "meta"
                     (fmt "by ~A" (if owner (user-username owner) "Unknown")))))))))
          (htm
           (:div :class "card"
             (:p "No public todos yet.")))))))

;;; ==========================================================
;;; ハンドラ: マイページ
;;; ==========================================================

(define-easy-handler (mypage :uri "/mypage") ()
  (unless (logged-in-p)
    (redirect "/login")
    (return-from mypage))
  (setf (content-type*) "text/html; charset=utf-8")
  (let* ((user (current-user))
         (todos (user-todos (user-id user))))
    (with-page ("My Page")
      (:h1 "My Page")
      
      ;; 追加フォーム
      (:div :class "card"
        (:h2 "Add Todo")
        (:form :action "/todo/add" :method "post"
          (:label "Title")
          (:input :type "text" :name "title" 
                  :placeholder "What do you want to do?" :required t)
          (:label
           (:input :type "checkbox" :name "public" :value "1")
           (:span :class "checkbox-label" "Make public"))
          (:br)(:br)
          (:button :type "submit" :class "btn btn-primary" "Add")))
      
      ;; Todo 一覧
      (:div :class "card"
        (:h2 "My Todos")
        (if todos
            (htm
             (dolist (todo todos)
               (htm
                (:div :class (format nil "todo-item~@[ done~]" (todo-done todo))
                  (when (todo-public todo)
                    (htm (:span :class "public-badge" "Public")))
                  (:span :class "title" (str (todo-title todo)))
                  ;; Done/Undo
                  (:form :action "/todo/toggle" :method "post" :class "inline"
                    (:input :type "hidden" :name "id" :value (todo-id todo))
                    (:button :type "submit" :class "btn btn-success"
                      (str (if (todo-done todo) "Undo" "Done"))))
                  ;; Public/Private
                  (:form :action "/todo/public" :method "post" :class "inline"
                    (:input :type "hidden" :name "id" :value (todo-id todo))
                    (:button :type "submit" :class "btn btn-secondary"
                      (str (if (todo-public todo) "Private" "Public"))))
                  ;; Delete
                  (:form :action "/todo/delete" :method "post" :class "inline"
                    (:input :type "hidden" :name "id" :value (todo-id todo))
                    (:button :type "submit" :class "btn btn-danger" "Del"))))))
            (htm
             (:p "No todos yet. Add one!")))))))

;;; ==========================================================
;;; ハンドラ: Todo 操作
;;; ==========================================================

(define-easy-handler (add-todo-action :uri "/todo/add") ()
  (unless (logged-in-p) (redirect "/login") (return-from add-todo-action))
  (let ((title (post-parameter "title"))
        (public (post-parameter "public"))
        (user (current-user)))
    (when (and title (> (length title) 0))
      (with-save
        (add-todo (user-id user) title :public (not (null public))))))
  (redirect "/mypage"))

(define-easy-handler (toggle-todo-action :uri "/todo/toggle") ()
  (unless (logged-in-p) (redirect "/login") (return-from toggle-todo-action))
  (let ((id (ignore-errors (parse-integer (post-parameter "id"))))
        (user (current-user)))
    (when id
      (with-save (toggle-todo id (user-id user)))))
  (redirect "/mypage"))

(define-easy-handler (public-todo-action :uri "/todo/public") ()
  (unless (logged-in-p) (redirect "/login") (return-from public-todo-action))
  (let ((id (ignore-errors (parse-integer (post-parameter "id"))))
        (user (current-user)))
    (when id
      (with-save (toggle-public id (user-id user)))))
  (redirect "/mypage"))

(define-easy-handler (delete-todo-action :uri "/todo/delete") ()
  (unless (logged-in-p) (redirect "/login") (return-from delete-todo-action))
  (let ((id (ignore-errors (parse-integer (post-parameter "id"))))
        (user (current-user)))
    (when id
      (with-save (delete-todo id (user-id user)))))
  (redirect "/mypage"))

;;; ==========================================================
;;; ハンドラ: Todo 詳細・コメント
;;; ==========================================================

;;; Todo詳細ページ（/view?id=123 形式）
(define-easy-handler (todo-detail :uri "/view") ()
  (setf (content-type*) "text/html; charset=utf-8")
  (let* ((id (ignore-errors (parse-integer (get-parameter "id"))))
         (todo (when id (find-todo id))))
    (if (and todo (todo-public todo))
        (let ((owner (find-user-by-id (todo-user-id todo)))
              (comments (todo-comments id)))
          (with-page ((todo-title todo))
            (:div :class "card"
              (:h1 (str (todo-title todo)))
              (:p :class "meta"
                (fmt "by ~A / ~A"
                     (if owner (user-username owner) "Unknown")
                     (format-time (todo-created-at todo))))
              (when (todo-done todo)
                (htm (:p (:strong "[Completed]")))))
            
            (:div :class "card"
              (:h2 "Comments")
              (if comments
                  (dolist (c comments)
                    (let ((author (find-user-by-id (comment*-user-id c))))
                      (htm
                       (:div :class "comment"
                         (:span :class "author"
                           (str (if author (user-username author) "Unknown")))
                         (:span :class "date"
                           (fmt " - ~A" (format-time (comment*-created-at c))))
                         (:p (str (comment*-content c)))))))
                  (htm (:p "No comments yet.")))
              
              (if (logged-in-p)
                  (htm
                   (:h3 "Add Comment")
                   (:form :action "/comment/add" :method "post"
                     (:input :type "hidden" :name "todo-id" :value id)
                     (:textarea :name "content" :rows "3" 
                                :placeholder "Write a comment..." :required t)
                     (:button :type "submit" :class "btn btn-primary" "Post")))
                  (htm
                   (:p (:a :href "/login" "Login") " to comment"))))))
        (with-page ("Not Found")
          (:div :class "card"
            (:p "Todo not found or not public."))))))

(define-easy-handler (add-comment-action :uri "/comment/add") ()
  (unless (logged-in-p) (redirect "/login") (return-from add-comment-action))
  (let ((todo-id (ignore-errors (parse-integer (post-parameter "todo-id"))))
        (content (post-parameter "content"))
        (user (current-user)))
    (when (and todo-id content (> (length content) 0))
      (with-save (add-comment todo-id (user-id user) content)))
    (redirect (format nil "/view?id=~A" todo-id))))

;;; ==========================================================
;;; サーバー管理
;;; ==========================================================

(defvar *server* nil)

(defun start-server (&optional (port 8080))
  (when *server* (hunchentoot:stop *server*))
  (load-data)
  (setf *server* (make-instance 'easy-acceptor :port port))
  (hunchentoot:start *server*)
  (format t "~%>>> Todo App started~%")
  (format t "    http://localhost:~A/~%~%" port))

(defun stop-server ()
  (when *server*
    (save-data)
    (hunchentoot:stop *server*)
    (setf *server* nil)
    (format t "Server stopped~%")))

;;; ==========================================================
;;; 起動メッセージ
;;; ==========================================================

(format t "~%todo-app-full.lisp loaded.~%")
(format t "Usage: (todo-app:start-server)~%")
