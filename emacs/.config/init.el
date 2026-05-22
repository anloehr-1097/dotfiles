(setq user-full-name "Andreas Loehr"
      user-mail-address "andreas.loehr97@gmail.com")

(add-to-list 'load-path "~/.config/emacs/custom_elisp/")
(require 'ob-dot2tex)

;; setting directory program based on operating system
    (defun set-insert-directory-program ()
  "Set `insert-directory-program' based on the operating system."
  (interactive)
  (setq insert-directory-program
        (cond
         ((eq system-type 'gnu/linux) "ls")
         ((eq system-type 'darwin) "gls")
         ((eq system-type 'windows-nt) "dir")
         (t "ls"))))

;; Call the function to set insert-directory-program
(set-insert-directory-program)

;; The default is 800 kilobytes.  Measured in bytes.
(setq gc-cons-threshold (* 50 1000 1000))

(defun efs/display-startup-time ()
  (message "Emacs loaded in %s with %d garbage collections."
           (format "%.2f seconds"
                   (float-time
                    (time-subtract after-init-time before-init-time)))
           gcs-done))

  (add-hook 'emacs-startup-hook #'efs/display-startup-time)
  (defvar efs/default-font-size 100)
  (defvar efs/default-variable-font-size 100)
 ;; (setq insert-directory-program "gls" dired-use-ls-dired t)
  (setq dired-listing-switches "-al --group-directories-first")

(setq default-frame-alist
      '((font . "Iosevka Nerd Font-22")
        (width . 50)
        (height . 50)))
(setq visible-bell nil)
(setq ring-bell-function 'ignore)

;; Initialize package sources
  (require 'package)

  (setq package-archives '(("melpa" . "https://melpa.org/packages/")
                           ("org" . "https://orgmode.org/elpa/")
                           ("elpa" . "https://elpa.gnu.org/packages/")))

  (add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/"))
(add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/"))

  (package-initialize)
  (unless package-archive-contents
    (package-refresh-contents))

    ;; Initialize use-package on non-Linux platforms
  (unless (package-installed-p 'use-package)
    (package-install 'use-package))

  (require 'use-package)
  (setq use-package-always-ensure t)

(use-package auto-package-update
  :custom
  (auto-package-update-interval 30)
  (auto-package-update-prompt-before-update t)
  (auto-package-update-hide-results t)
  :config
  (auto-package-update-maybe)
  (auto-package-update-at-time "09:00"))

;; NOTE: If you want to move everything out of the ~/.emacs.d folder
;; reliably, set `user-emacs-directory` before loading no-littering!
;(setq user-emacs-directory "~/.cache/emacs")

(use-package no-littering)

;; no-littering doesn't set this by default so we must place
;; auto save files in the same path as it uses for sessions
(setq auto-save-file-name-transforms
      `((".*" ,(no-littering-expand-var-file-name "auto-save/") t)))

(setq inhibit-startup-message t)

(scroll-bar-mode -1)        ; Disable visible scrollbar
(tool-bar-mode -1)          ; Disable the toolbar
(tooltip-mode 1)           ; Disable tooltips
(set-fringe-mode 10)        ; Give some breathing room

(menu-bar-mode -1)            ; Disable the menu bar

;; Set up the visible bell
(setq visible-bell t)

(column-number-mode)
;; (global-display-line-numbers-mode t)

;; ;; Disable line numbers for some modes
;; (dolist (mode '(org-mode-hook
;;                 term-mode-hook
;;                 shell-mode-hook
;;                 treemacs-mode-hook
;;                 eshell-mode-hook
;;                 pdf-view-mode-hook))
;;   (add-hook mode (lambda () (display-line-numbers-mode 0))))

(set-face-attribute 'default nil :font "Iosevka Nerd Font-18" :height efs/default-font-size)

;; Set the fixed pitch face
(set-face-attribute 'fixed-pitch nil :font "Iosevka Nerd Font-18" :height efs/default-font-size)

;; Set the variable pitch face
(set-face-attribute 'variable-pitch nil :font "Iosevka Nerd Font-18" :height efs/default-variable-font-size :weight 'regular)

(use-package undo-tree
  :ensure t
  :config
  (global-undo-tree-mode))

(use-package smart-comment
  :ensure t)

;; Make ESC quit prompts
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

(use-package general
  :after evil
  :config
  ;; SPC leader key
  (general-create-definer space-leader
  :states '(normal visual emacs)
  :keymaps 'override
  :prefix "SPC")

(space-leader
  ;;:states '(normal visual emacs)
  ;;:keymaps 'override
  "f" '(:ignore t :which-key "find")
  "ff" 'counsel-find-file
  "fs" 'rgrep
  "fb" 'swiper
  "e" '(:ignore t :which-key "emacs-specific")
  "ee" 'eval-region
  "eb" 'eval-buffer
  "b" 'counsel-switch-buffer
  "k" 'kill-buffer
  "s" 'avy-goto-char)

  (general-create-definer efs/leader-keys
    :keymaps '(normal insert visual emacs)
    :prefix "SPC"
    :global-prefix "C-SPC")

  (efs/leader-keys
    "t"  '(:ignore t :which-key "toggles")
    "tl" '(counsel-load-theme :which-key "choose theme")
    "fde" '(lambda () (interactive) (find-file (expand-file-name "~/.emacs.d/emacs_conf.org")))))

(use-package evil
  :after counsel
  :init
  (setq evil-search-module 'evil-search)
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-C-i-jump t)
  :config
  (evil-mode 1)
  (evil-set-leader nil (kbd "SPC"))
  ; buffer select, buffer list, find file, delete window
  (evil-define-key 'normal 'global (kbd "<leader>b") 'counsel-switch-buffer)
  (evil-define-key 'normal 'global (kbd "<leader>B") 'list-buffers)
  (evil-define-key 'normal 'global (kbd "<leader>ff") 'find-file)
  (evil-define-key 'normal 'global (kbd "<leader>fs") 'rgrep)
  ; (evil-define-key 'normal 'global (kbd "<leader>0") 'delete-window) ;
  ; definition jumping (gd already goes to definition)
  (evil-define-key 'normal 'global (kbd "gD") 'xref-pop-marker-stack)
  ; allow replacement only in selection for visual block mode
  ;; (evil-define-key 'visual 'global (kbd "<leader>vbr")
  ;;   'evil-visual-replace-replace-regexp)
  ;;
  ; commenting
  (evil-define-key '(normal visual) 'global (kbd "gc") 'smart-comment)
  ; indentation
  ; (evil-define-key '(normal visual) 'global (kbd "gi") 'indent-region)
  ;; tabbing
  (evil-define-key '(normal visual) 'global (kbd "<leader>to") 'tab-new)
  (evil-define-key '(normal visual) 'global (kbd "<leader>tn") 'tab-next)
  (evil-define-key '(normal visual) 'global (kbd "<leader>tp") 'tab-previous)
  (evil-define-key '(normal visual) 'global (kbd "<leader>tx") 'tab-close)
  (evil-define-key '(normal) 'global (kbd "S-RET") 'org-insert-item)

  ; statusline commands (available as ":<command>")
  (evil-ex-define-cmd "done" 'save-buffers-kill-emacs)
  (evil-ex-define-cmd "at"   'open-ansi-term)
  (evil-ex-define-cmd "rb"   'rename-buffer)  
  (evil-ex-define-cmd "hsp"  'split-window-below)
  (evil-ex-define-cmd "sw"   'rotate-frame)
  (evil-ex-define-cmd "tp"   'transpose-frame)
  (evil-ex-define-cmd "rshp" 'reshape-window)

  (define-key evil-insert-state-map (kbd "C-g") 'evil-normal-state)
  (define-key evil-insert-state-map (kbd "C-h") 'evil-delete-backward-char-and-join)

  ;; Use visual line motions even outside of visual-line-mode buffers
  (evil-global-set-key 'motion "j" 'evil-next-visual-line)
  (evil-global-set-key 'motion "k" 'evil-previous-visual-line)

  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dashboard-mode 'normal)
  (evil-set-undo-system 'undo-tree))


(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

(use-package fzf
:config
(setq fzf/args "-x --color bw --print-query --margin=1,0 --no-hscroll"
      fzf/executable "fzf"
      fzf/git-grep-args "-i --line-number %s"
      ;; command used for `fzf-grep-*` functions
      ;; example usage for ripgrep:
      ;; fzf/grep-command "rg --no-heading -nH"
      fzf/grep-command "grep -nrH"
      ;; If nil, the fzf buffer will appear at the top of the window
      fzf/position-bottom t
      fzf/window-height 15))

(use-package wgrep
  :ensure t)

(use-package command-log-mode
  :commands command-log-mode)

(defun black-bg ()
  (set-background-color "black")
  )

(use-package doom-themes
  :ensure t
  :init (load-theme 'doom-tokyo-night t)
  :hook ('black-bg))



  ;; (use-package gruber-darker-theme
  ;;   :ensure t
  ;;   :config
  ;;   (load-theme 'gruber-darker t)
  ;;   (set-background-color "black"))

                                        ; (load-theme 'gruber-darker t)
                                        ;(set-background-color "black")

(use-package all-the-icons)

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :custom ((doom-modeline-height 15)))

(use-package dashboard
  :ensure t
  :config
  (dashboard-setup-startup-hook))

  (setq dashboard-banner-logo-title "Dashboard")
  (setq dashboard-startup-banner 'logo)
  (setq dashboard-center-content t)

  ;; To disable shortcut "jump" indicators for each section, set
  (setq dashboard-show-shortcuts t)
  (setq dashboard-items '((recents  . 5)
                      (bookmarks . 5)
                      (projects . 5)
                      (agenda . 5)
                      (registers . 5)))
  ;; use all-the-icons package
  (setq dashboard-icon-type 'all-the-icons)
  (setq dashboard-filter-agenda-entry 'dashboard-no-filter-agenda)
  (setq dashboard-heading-icons '((recents . "history")
                              (bookmarks . "bookmark")
                              (agenda    . "calendar")
                              (projects  . "rocket")
                              (registers . "database")))
  (setq dashboard-set-heading-icons t)
  (setq dashboard-set-file-icons t)
  (setq dashboard-set-navigator t)
  (setq dashboard-init-info "Welcome to Emacs!")

(setq display-line-numbers-type 'relative)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'org-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

(add-hook 'doc-view-mode
          (lambda ()
            (display-line-numbers-mode -1)))

(with-eval-after-load 'pdf-tools
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (progn
                (display-line-numbers-mode -1)
                (tooltip-mode -1)
                (setq use-system-tooltips nil)
                (setq pdf-annot-activate-created-annotations 'minibuffer)
                ))))

(use-package which-key
  :defer 0
  :diminish which-key-mode
  :config
  (which-key-mode)
  (setq which-key-idle-delay 1))

(use-package flycheck
  :ensure t
  :init (global-flycheck-mode)
  )

(use-package vertico
  :ensure t
  :config
  (vertico-mode 1)
  )

  (general-define-key
   :keymaps '(normal visual emacs)
   :prefix "SPC"
   "fb" 'swiper)

(use-package counsel
  :bind (("C-x b" . 'counsel-switch-buffer)
         ("C-x d" . 'counsel-dired)
         :map minibuffer-local-map
         ("C-r" . 'counsel-minibuffer-history)
         )
  :custom
  (counsel-linux-app-format-function #'counsel-linux-app-format-function-name-only)
  :config
  (counsel-mode 1))

(use-package ido
  :ensure t
  :config
  (ido-mode t))

(use-package ivy-prescient
  :after counsel
  :custom
  (ivy-prescient-enable-filtering nil)
  :config
  ;; Uncomment the following line to have sorting remembered across sessions!
  ;(prescient-persist-mode 1)
  (ivy-prescient-mode 1))

(use-package helpful
  :commands (helpful-callable helpful-variable helpful-command helpful-key)
  :custom
  (counsel-describe-function-function #'helpful-callable)
  (counsel-describe-variable-function #'helpful-variable)
  :bind
  ([remap describe-function] . counsel-describe-function)
  ([remap describe-command] . helpful-command)
  ([remap describe-variable] . counsel-describe-variable)
  ([remap describe-key] . helpful-key))

(use-package hydra
  :defer t)

(defhydra hydra-text-scale (:timeout 4)
  "scale text"
  ("j" text-scale-increase "in")
  ("k" text-scale-decrease "out")
  ("f" nil "finished" :exit t))

(efs/leader-keys
  "st" '(hydra-text-scale/body :which-key "scale text"))

(use-package djvu
  :ensure t)

(use-package popup
  :ensure t)

(use-package clippy)

(global-set-key (kbd "C-c s") 'shell-command)

(use-package yasnippet
  :ensure t
  :diminish yas-minor-mode
  :config
  (setq yas-snippet-dirs (list (expand-file-name "~/.config/emacs/snippets")))
  (yas-global-mode 1)
  :bind ("C-c e" . yas-expand))

(defun efs/org-font-setup ()
    ;; Replace list hyphen with dot
    (font-lock-add-keywords 'org-mode
                            '(("^ *\\([-]\\) "
                               (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "•"))))))

    ;; Set faces for heading levels
    (dolist (face '((org-level-1 . 1.2)
                    (org-level-2 . 1.1)
                    (org-level-3 . 1.05)
                    (org-level-4 . 1.0)
                    (org-level-5 . 1.1)
                    (org-level-6 . 1.1)
                    (org-level-7 . 1.1)
                    (org-level-8 . 1.1)))
      (set-face-attribute (car face) nil :font "Cantarell" :weight 'regular :height (cdr face)))

    ;; Ensure that anything that should be fixed-pitch in Org files appears that way
    (set-face-attribute 'org-block nil    :foreground nil :inherit 'fixed-pitch :height 2.0)
    (set-face-attribute 'org-table nil    :inherit 'fixed-pitch :height 2.0)
    (set-face-attribute 'org-formula nil  :inherit 'fixed-pitch :height 2.0)
    (set-face-attribute 'org-code nil     :inherit '(shadow fixed-pitch) :height 2.0)
    (set-face-attribute 'org-table nil    :inherit '(shadow fixed-pitch))
    (set-face-attribute 'org-verbatim nil :inherit '(shadow fixed-pitch) :height 2.0)
    (set-face-attribute 'org-special-keyword nil :inherit '(font-lock-comment-face fixed-pitch) :height 2.0)
    (set-face-attribute 'org-meta-line nil :inherit '(font-lock-comment-face fixed-pitch) :height 2.0)
    (set-face-attribute 'org-checkbox nil  :inherit 'fixed-pitch :height 2.0)
    (set-face-attribute 'line-number nil :inherit 'fixed-pitch :height 2.0)
    (set-face-attribute 'line-number-current-line nil :inherit 'fixed-pitch :height 2.0))
;; set org directory
(setq org-directory "~/org/")

(defun efs/org-mode-setup ()
  (org-indent-mode)
  (variable-pitch-mode 0)
  (visual-line-mode 1))

(use-package org
  :pin org
  :commands (org-capture org-agenda)
  :hook (org-mode . efs/org-mode-setup)
  :config
  (setq org-ellipsis " ▾")
  (setq org-agenda-start-with-log-mode t)
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)
  ;; Load org-agenda-files from manifest instead of hardcoding
  (when (locate-library "org-agenda-manifest")
    (require 'org-agenda-manifest)
    (org-agenda-manifest-setup))
  :bind ("C-c l" . org-store-link))

(require 'org-habit)
(add-to-list 'org-modules 'org-habit)
(setq org-habit-graph-column 60)

(setq org-todo-keywords
      '((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!)")
	(sequence "BACKLOG(b)" "PLAN(p)" "READY(r)" "ACTIVE(a)" "REVIEW(v)" "WAIT(w@/!)" "HOLD(h)" "|" "COMPLETED(c)" "CANC(k@)")))

(setq org-refile-targets
      (org-agenda-manifest--merge-refile-targets
       '(("~/org/Archive.org" :maxlevel . 1)
	("~/research/backlog.org" :maxlevel . 3)
	("~/research/planning.org" :maxlevel . 3)
	("~/research/paperlist.org" :maxlevel . 3)
	("~/org/Journal.org" :maxlevel . 3))))

;; Save Org buffers after refiling!
(advice-add 'org-refile :after 'org-save-all-org-buffers)

(setq org-tag-alist
      '(("Diffusion" . ?d)
	("DistributionalRL" . ?D)
	("Quantization" . ?Q)
	("Compression" . ?C)
	("CriticLearning" . ?c)
	("planning" . ?p)
	("publish" . ?P)
	("note" . ?n)
	("idea" . ?i)
	))

;; Configure custom agenda views
(setq org-agenda-custom-commands
      '(("d" "Dashboard"
	 ((agenda "" ((org-deadline-warning-days 7)))
	  (todo "NEXT"
		((org-agenda-overriding-header "Next Tasks")))
	  (tags-todo "agenda/ACTIVE" ((org-agenda-overriding-header "Active Projects")))))

	("n" "Next Tasks"
	 ((todo "NEXT"
		((org-agenda-overriding-header "Next Tasks")))))

	("W" "Work Tasks" tags-todo "+work-email")

	;; Low-effort next actions
	("e" tags-todo "+TODO=\"NEXT\"+Effort<15&+Effort>0"
	 ((org-agenda-overriding-header "Low Effort Tasks")
	  (org-agenda-max-todos 20)
	  (org-agenda-files org-agenda-files)))

	("w" "Workflow Status"
	 ((todo "WAIT"
		((org-agenda-overriding-header "Waiting on External")
		 (org-agenda-files org-agenda-files)))
	  (todo "REVIEW"
		((org-agenda-overriding-header "In Review")
		 (org-agenda-files org-agenda-files)))
	  (todo "PLAN"
		((org-agenda-overriding-header "In Planning")
		 (org-agenda-todo-list-sublevels nil)
		 (org-agenda-files org-agenda-files)))
	  (todo "BACKLOG"
		((org-agenda-overriding-header "Project Backlog")
		 (org-agenda-todo-list-sublevels nil)
		 (org-agenda-files org-agenda-files)))
	  (todo "READY"
		((org-agenda-overriding-header "Ready for Work")
		 (org-agenda-files org-agenda-files)))
	  (todo "ACTIVE"
		((org-agenda-overriding-header "Active Projects")
		 (org-agenda-files org-agenda-files)))
	  (todo "COMPLETED"
		((org-agenda-overriding-header "Completed Projects")
		 (org-agenda-files org-agenda-files)))
	  (todo "CANC"
		((org-agenda-overriding-header "Cancelled Projects")
		 (org-agenda-files org-agenda-files)))))))



(setq org-capture-templates
      `(("t" "Tasks / Projects")
	("tt" "Task" entry (file+olp "~/org/Tasks.org" "Inbox")
         "* TODO %?\n  %U\n  %a\n  %i" :empty-lines 1)

	("j" "Journal Entries")
	("jj" "Journal" entry
         (file+olp+datetree "~/org/Journal.org")
         "\n* %<%I:%M %p> - Journal :journal:\n\n%?\n\n"
         ;; ,(dw/read-file-as-string "~/Notes/Templates/Daily.org")
         :clock-in :clock-resume
         :empty-lines 1)
	("jm" "Meeting" entry
         (file+olp+datetree "~/org/Journal.org")
         "* %<%I:%M %p> - %a :meetings:\n\n%?\n\n"
         :clock-in :clock-resume
         :empty-lines 1)

	("w" "Workflows")
	("we" "Checking Email" entry (file+olp+datetree "~/org/Journal.org")
         "* Checking Email :email:\n\n%?" :clock-in :clock-resume :empty-lines 1)

	("m" "Metrics Capture")
	("mw" "Weight" table-line (file+headline "~/org/Metrics.org" "Weight")
	 "| %U | %^{Weight} | %^{Notes} |" :kill-buffer t)

	("a" "Anki")
	("aa" "Anki Add Basic And Reverse Card" entry (file+olp "~/org/anki/russian.org" "Captured") "** %^{Card Name} \n*** Front \n %^{English} \n*** Back \n%?"
	 )
	))



(define-key global-map (kbd "C-c j")
	    (lambda () (interactive) (org-capture nil "jj")))

(efs/org-font-setup)
(setq org-format-latex-options (plist-put org-format-latex-options :scale 2.0))

(global-set-key (kbd "C-c c") 'org-agenda)

(setq diary-file "~/KeepInSync/diary")

(use-package org-bullets
  :hook (org-mode . org-bullets-mode)
  :custom
  (org-bullets-bullet-list '("♔" "♕" "♜" "♝" "♞" "♟" "♻")))

;;(use-package org-superstar
    ;;:ensure t
    ;;:hook (org-mode . org-superstar-mode))

(defun efs/org-mode-visual-fill ()
  (setq visual-fill-column-width 100
        visual-fill-column-center-text t)
  (visual-fill-column-mode 1))

(use-package visual-fill-column
  :hook (org-mode . efs/org-mode-visual-fill))

;(use-package org-modern
  ;:after org
  ;:ensure t
  ;:hook (org-mode . org-modern-mode))

(defvar org-babel-export-directory "~/org/babel-exports"
    "Directory to save org-babel generated files.")

(setq org-image-actual-width nil)

(defun org-babel-execute:dot2tex (body params)
  "Execute a DOT block, convert to LaTeX with dot2tex, then convert to PNG with pdflatex and Ghostscript."
  (let* ((out-file (or (cdr (assoc :file params))
                       (error "You need to specify a :file parameter")))
         (export-dir (file-name-as-directory org-babel-export-directory))
         (out-file-full (expand-file-name out-file export-dir))
         (temp-dot (make-temp-file "graph" nil ".dot" export-dir))
         (temp-tex (make-temp-file "graph" nil ".tex" export-dir))
         (temp-pdf (make-temp-file "graph" nil ".pdf" export-dir))
         (background-color (or (cdr (assoc :bg-color params)) "white"))) ;; Set background color
    (unless (file-exists-p export-dir)
      (make-directory export-dir t))

    ;; Write DOT code to temp file
    (with-temp-file temp-dot
      (insert body))

    ;; LaTeX preamble for background color
    (let ((latex-preamble (format "\\usepackage{tikz}\\definecolor{background}{rgb}{1,1,1}\\pagecolor{background}")))
      
      ;; Run dot2tex with the preamble to generate the .tex file
      (org-babel-eval
       (format "dot2tex -tmath --margin 0pt --figpreamble='%s' %s > %s"
               latex-preamble temp-dot temp-tex) "")

      ;; Run pdflatex to convert .tex to .pdf
      (org-babel-eval
       (format "pdflatex -output-directory=%s -jobname=%s %s"
               (file-name-directory temp-pdf)
               (file-name-base temp-pdf)
               temp-tex) "")

      ;; Convert the PDF to PNG with Ghostscript, ensuring no transparency
      (org-babel-eval
       (format "gs -dBATCH -dNOPAUSE -dSAFER -sDEVICE=pngalpha -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -r300 -sOutputFile=%s %s"
               out-file-full temp-pdf) "")

      ;; Clean up temporary files
      (delete-file temp-dot)
      (delete-file temp-tex)
      (delete-file temp-pdf)
      (delete-file (concat (file-name-sans-extension temp-pdf) ".aux"))
      (delete-file (concat (file-name-sans-extension temp-pdf) ".log"))
      nil)))

(with-eval-after-load 'org
  (org-babel-do-load-languages
      'org-babel-load-languages
      '((emacs-lisp . t)
      (python . t)
      (dot . t)
      (dot2tex . t)
      (latex . t)
      (plantuml . t)
      )
)

  ; (push '("conf-unix" . conf-unix) org-src-lang-modes)
  ; (push '("dot" . graphviz-dot) org-src-lang-modes)

 )

(with-eval-after-load 'org
  ;; This is needed as of Org 9.2
  (require 'org-tempo)

  (add-to-list 'org-structure-template-alist '("sh" . "src shell"))
  (add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))
  (add-to-list 'org-structure-template-alist '("py" . "src python")))

;; Automatically tangle our Emacs.org config file when we save it
(defun efs/org-babel-tangle-config ()
  (when (string-equal (file-name-directory (buffer-file-name))
                      (expand-file-name user-emacs-directory))
    ;; Dynamic scoping to the rescue
    (let ((org-confirm-babel-evaluate nil))
      (org-babel-tangle))))

(add-hook 'org-mode-hook (lambda () (add-hook 'after-save-hook #'efs/org-babel-tangle-config)))

(use-package plantuml-mode
    :ensure t
    :config
    (setq plantuml-default-exec-mode 'jar)
    (add-to-list 'org-src-lang-modes '("plantuml" . plantuml))
    (setq plantuml-jar-path "/opt/homebrew/Cellar/plantuml/1.2026.2/libexec/plantuml.jar")
(setq org-plantuml-jar-path (expand-file-name "/opt/homebrew/Cellar/plantuml/1.2026.2/libexec/plantuml.jar"))

   )

(use-package org-contrib
  :after org
  :config
  (require 'ox-extra)
  (ox-extras-activate '(latex-header-blocks ignore-headlines))
  (with-eval-after-load 'ox-latex
    ;; Import ox-latex to get org-latex-classes and other functionality
    ;; for exporting to LaTeX from org
    (setq org-latex-pdf-process
          '("pdflatex -interaction nonstopmode -output-directory %o %f"
            "bibtex %b"
            "pdflatex -interaction nonstopmode -output-directory %o %f"
            "pdflatex -interaction nonstopmode -output-directory %o %f"))
    (setq org-latex-with-hyperref nil) ;; stop org adding hypersetup{author..} to latex export
    ;; (setq org-latex-prefer-user-labels t)
    ;; delete unwanted file extensions after latexMK
    (setq org-latex-logfiles-extensions
          '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm" "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "xmpi" "run.xml" "bcf" "acn" "acr" "alg" "glg" "gls" "ist"))
    (unless (boundp 'org-latex-classes)
      (setq org-latex-classes nil)))
  )

(use-package ox-hugo
  :ensure t)

(use-package emacsql
  :ensure t)

;; (use-package emacsql-sqlite
;;   :ensure t)


  (use-package org-roam
    :after org
    :init
    (setq org-roam-database-connector 'sqlite-builtin)
    :config
    (setq org-roam-directory (file-truename "~/org-roam"))
    (org-roam-db-autosync-mode)
    (global-set-key (kbd "C-c r i") 'org-roam-node-insert)
    (global-set-key (kbd "C-c r c") 'org-roam-capture)
    (global-set-key (kbd "C-c r f") 'org-roam-node-find)
    )


  (use-package org-roam-ui
    :after org-roam
    :ensure t)

(defun efs/lsp-mode-setup ()
    (setq lsp-headerline-breadcrumb-segments '(path-up-to-project file symbols))
    (lsp-headerline-breadcrumb-mode))

  (use-package lsp-mode
    :commands (lsp lsp-deferred)
    :hook (lsp-mode . efs/lsp-mode-setup)
    :init
    (setq lsp-keymap-prefix "C-c l")  ;; Or 'C-l', 's-l'
    :config
    (lsp-enable-which-key-integration t))

;; configs for lsp
(setq lsp-eldoc-enable-hover t)
;; (setq lsp-ui-doc-show-with-cursor t)
;; you could manually request them via `lsp-signature-activate`
(setq lsp-signature-auto-activate t)
(setq lsp-signature-render-documentation nil)

(use-package lsp-ui
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-position 'bottom))

(use-package lsp-treemacs
  :after lsp)

(use-package lsp-ivy
  :ensure t
  :after lsp
  :commands lsp-ivy-workspace-symbol)

;(lsp-register-client
   ;(make-lsp-client :new-connection (lsp-tramp-connection "clangd")
                    ;:major-modes '(c-mode c++-mode)
                    ;:remote? t
                    ;:server-id 'clangd-remote))

(use-package dap-mode
  ;; Uncomment the config below if you want all UI panes to be hidden by default!
  ;; :custom
  ;; (lsp-enable-dap-auto-configure nil)
  ;; :config
  ;; (dap-ui-mode 1)
  :commands dap-debug
  :config
  ;; Set up Node debugging
  ;;(require 'dap-node)
  ;;(dap-node-setup) ;; Automatically installs Node debug adapter if needed

  ;; Bind `C-c l d` to `dap-hydra` for easy access
  (general-define-key
    :keymaps 'lsp-mode-map
    :prefix lsp-keymap-prefix
    "d" '(dap-hydra t :wk "debugger")))

(setq dap-auto-configure-mode t)
(setq dap-auto-configure-features '(sessions locals controls tooltip))

;; (require 'dap-cpptools)
;; (dap-cpptools-setup)


(use-package cmake-mode
  :ensure t)

(use-package python-mode
  :ensure t
  :hook (python-mode . lsp-deferred)
  ;; NOTE: Set these if Python 3 is called "python3" on your system!
  ;; (python-shell-interpreter "python3")
  ;; (dap-python-executable "python3")
  )

  (require  'dap-python)
  (setq dap-python-debugger 'debugpy)

(use-package pyvenv
  :after python-mode
  :config
  (pyvenv-mode 0))

(use-package pipenv
  :ensure t
  :after python-mode
  )

(use-package flycheck-mypy
  :ensure t
  :after python-mode
  )

;; Setting conda path depending on location of homebrew
(let (
      (primary-path "/usr/local/Caskroom/miniconda/base/")
      (fallback-path "/opt/homebrew/Caskroom/miniconda/base/")
        )
  (if (file-exists-p primary-path)
      (setq conda-path primary-path)
    (setq conda-path fallback-path)
      )
  )


  (use-package conda
    :ensure t)


  (custom-set-variables
   '(conda-anaconda-home conda-path)
   )

(use-package cuda-mode
  :ensure t)

(use-package haskell-mode
  :ensure t)

(use-package company
  :after lsp-mode
  :hook ((lsp-mode prog-mode org-mode text-mode) . company-mode)
  :bind (:map company-active-map
         ("<tab>" . company-complete-selection))
        (:map lsp-mode-map
         ("<tab>" . company-indent-or-complete-common))
  :custom
  (company-minimum-prefix-length 3)
  (company-idle-delay 0.0))

(use-package company-box
  :hook (company-mode . company-box-mode))

(use-package projectile
  :diminish projectile-mode
  :config (projectile-mode)
  :custom ((projectile-completion-system 'ivy))
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :init
  ;; NOTE: Set this to the folder where you keep your Git repos!
  (setq projectile-project-search-path
        (list (cons (expand-file-name "~/Projects") 2)
              (cons (expand-file-name "~/research") 1)
              (cons (expand-file-name "~/org-roam") 1)
              (cons (expand-file-name "~/org") 1)
                      ))
  ;; (when (file-directory-p "~/Code")
  ;;   (setq projectile-project-search-path '("~/Code")))
  (setq projectile-switch-project-action #'projectile-dired))

(use-package counsel-projectile
  :after projectile
  :config (counsel-projectile-mode))


(general-create-definer projectile-bindings
  :prefix "SPC")

(projectile-bindings
  :states '(normal visual emacs)
  "fp" 'projectile-find-file
  )

(expand-file-name "~")

(use-package magit
  :commands magit-status
  :config
  (global-set-key (kbd "C-c m s") 'magit-status)
  (global-set-key (kbd "C-c m l") 'magit-log)
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;; NOTE: Make sure to configure a GitHub token before using this package!
;; - https://magit.vc/manual/forge/Token-Creation.html#Token-Creation
;; - https://magit.vc/manual/ghub/Getting-Started.html#Getting-Started
(use-package forge
  :after magit)

(use-package evil-owl
  :after evil
  :config
  (setq evil-owl-max-string-length 500)
  (add-to-list 'display-buffer-alist
               '("*evil-owl*"
                 (display-buffer-in-side-window)
                 (side . bottom)
                 (window-height . 0.3)))
  (setq evil-owl-local-mark-format " %m: [l: %-5l, c: %-5c]\n    %s")
  (setq evil-owl-global-mark-format " %m: [l: %-5l, c: %-5c] %b\n    %s")
  (setq evil-owl-max-string-length 50)
  (evil-owl-mode))

(with-eval-after-load 'tramp (add-to-list 'tramp-remote-path 'tramp-own-remote-path))
(customize-set-variable 'tramp-verbose 6 "Enable remote command traces")
                                        ; (customize-set-variable 'tramp-connection-properties (list (regexp-quote "/sshx:user@host:") "remote-shell" "/usr/bin/bash") "remote shell")
(with-eval-after-load 'tramp (add-to-list 'tramp-connection-properties
                                          (list (regexp-quote "/sshx:user@host:")
                                                "remote-shell" "/usr/bin/bash")))
                                        ;(add-to-list 'tramp-connection-properties
                                        ;(list (regexp-quote "/sshx:user@host:")
                                        ;"remote-shell" "/usr/bin/bash"));
                                        ;(add-to-list 'tramp-remote-path 'tramp-own-remote-path)
                                        ;(customize-set-variable 'tramp-encoding-shell "/usr/bin/bash")
(with-eval-after-load 'tramp 
  (add-to-list 'tramp-connection-properties
               (list (regexp-quote "/ssh:andy@192.168.178.60:")
                     "remote-shell" "/usr/bin/zsh")))


(with-eval-after-load 'tramp
  (add-to-list 'tramp-connection-properties
               (list (regexp-quote "/sshx:andy@192.168.178.60:")
                     "remote-shell" "/usr/bin/zsh"))
  )
(with-eval-after-load 'tramp
  (customize-set-variable 'tramp-encoding-shell "/bin/zsh")
  )

(use-package evil-nerd-commenter
  :bind ("M-/" . evilnc-comment-or-uncomment-lines))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package evil-surround
  :ensure t
  :config
  (global-evil-surround-mode 1))

(use-package pdf-tools
  :ensure t
  :config
  (pdf-tools-install)

  (custom-set-variables
   '(pdf-tools-handle-upgrades t))

(space-leader
  "p" '(:ignore t :which-key "find")
  "ph" 'pdf-annot-add-highlight-markup-annotation
  "pt" 'pdf-annot-add-text-annotation)

(setq pdf-annot-activate-created-annotations 'minibuffer)
  )

(use-package nov
  :ensure t)

  (use-package org-noter)

  (use-package org-pdftools)

  (use-package org-noter-pdftools)
    ;;:after org-noter
;;     :config
;;     ;; Add a function to ensure precise note is inserted
;;     (defun org-noter-pdftools-insert-precise-note (&optional toggle-no-questions)
;;     (interactive "P")
;;     (org-noter--with-valid-session
;;      (let ((org-noter-insert-note-no-questions (if toggle-no-questions
;;                                                    (not org-noter-insert-note-no-questions)
;;                                                  org-noter-insert-note-no-questions))
;;            (org-pdftools-use-isearch-link t)
;;            (org-pdftools-use-freepointer-annot t))
;;        (org-noter-insert-note (org-noter--get-precise-info)))))

;;   ;; fix https://github.com/weirdNox/org-noter/pull/93/commits/f8349ae7575e599f375de1be6be2d0d5de4e6cbf
;;   (defun org-noter-set-start-location (&optional arg)
;;     "When opening a session with this document, go to the current location.
;; With a prefix ARG, remove start location."
;;     (interactive "P")
;;     (org-noter--with-valid-session
;;      (let ((inhibit-read-only t)
;;            (ast (org-noter--parse-root))
;;            (location (org-noter--doc-approx-location (when (called-interactively-p 'any) 'interactive))))
;;        (with-current-buffer (org-noter--session-notes-buffer session)
;;          (org-with-wide-buffer
;;           (goto-char (org-element-property :begin ast))
;;           (if arg
;;               (org-entry-delete nil org-noter-property-note-location)
;;             (org-entry-put nil org-noter-property-note-location
;;                            (org-noter--pretty-print-location location))))))))
;;   (with-eval-after-load 'pdf-annot
;;     (add-hook 'pdf-annot-activate-handler-functions #'org-noter-pdftools-jump-to-note)))

(use-package ein
  :ensure t
  )

(use-package dash
  :ensure t)
(use-package s
  :ensure t)
(use-package editorconfig
  :ensure t)

(add-to-list 'load-path "~/.config/emacs/copilot.el")

(use-package copilot
  :ensure t
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB" . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("C-TAB" . copilot-accept-completion-by-word)
              ("C-n" . copilot-next-completion)
              ("C-p" . copilot-previous-completion)))

(use-package graphviz-dot-mode
  :ensure t)

(use-package tex
  :ensure auctex)

(use-package auctex
  :ensure t)

(use-package company-auctex
  :ensure t)

(use-package auto-complete-auctex
  :ensure t
  :defer t
  )

(use-package magic-latex-buffer
  :ensure t
  :defer t
  )

;;(latex-preview-pane-enable)
(setq TeX-auto-save t)
(setq TeX-parse-self t)
(setq-default TeX-master nil)

(with-eval-after-load 'tex
  (add-to-list 'TeX-view-program-list '("Sioyek" "sioyek %o"))
  (setq TeX-view-program-selection '((output-pdf "Sioyek"))))

(with-eval-after-load 'org
  (add-to-list 'org-file-apps '("\\.pdf\\'" . "sioyek %s")))

(use-package org-latex-impatient
  :defer t
  :hook (org-mode . org-latex-impatient-mode)
  :init
  (setq org-latex-impatient-tex2svg-bin
	;;location of tex2svg executable
	(concat conda-path "bin/tex2svg")))


(setq org-latex-pdf-process
      '("latexmk -f -pdf -interaction=nonstopmode -output-directory=%o %f"))

(defun trim-dollar-spaces ()
  "Replace '$' and '$' with '$' in the current buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward " \\$\\|\\$" nil t)
      (replace-match "$" nil t))))

(general-define-key
 :keymaps '(normal visual insert)
 :prefix "C-c"
 "f" 'trim-dollar-spaces)

(use-package term
  :commands term
  :config
  (setq explicit-shell-file-name "zsh") ;; Change this to zsh, etc
  ;;(setq explicit-zsh-args '())         ;; Use 'explicit-<shell>-args for shell-specific args

  ;; Match the default Bash shell prompt.  Update this if you have a custom prompt
  (setq term-prompt-regexp "^[^#$%>\n]*[#$%>] *"))

(use-package eterm-256color
  :hook (term-mode . eterm-256color-mode))

(use-package vterm
  :commands vterm
  :config
  (setq term-prompt-regexp "^[^#$%>\n]*[#$%>] *")  ;; Set this to match your custom shell prompt
  (setq vterm-shell "zsh")                       ;; Set this to customize the shell to launch
  (setq vterm-max-scrollback 10000))

(when (eq system-type 'windows-nt)
  (setq explicit-shell-file-name "powershell.exe")
  (setq explicit-powershell.exe-args '()))

(defun efs/configure-eshell ()
  ;; Save command history when commands are entered
  (add-hook 'eshell-pre-command-hook 'eshell-save-some-history)

  ;; Truncate buffer for performance
  (add-to-list 'eshell-output-filter-functions 'eshell-truncate-buffer)

  ;; Bind some useful keys for evil-mode
  (evil-define-key '(normal insert visual) eshell-mode-map (kbd "C-r") 'counsel-esh-history)
  (evil-define-key '(normal insert visual) eshell-mode-map (kbd "<home>") 'eshell-bol)
  (evil-normalize-keymaps)

  (setq eshell-history-size         10000
        eshell-buffer-maximum-lines 10000
        eshell-hist-ignoredups t
        eshell-scroll-to-bottom-on-input t))

(use-package eshell-git-prompt
  :after eshell)

(use-package eshell
  :hook (eshell-first-time-mode . efs/configure-eshell)
  :config

  (with-eval-after-load 'esh-opt
    (setq eshell-destroy-buffer-when-process-dies t)
    (setq eshell-visual-commands '("htop" "zsh" "vim")))

  (eshell-git-prompt-use-theme 'powerline))

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :bind (("C-x C-j" . dired-jump))
  :custom ((dired-listing-switches "-agho --group-directories-first"))
  :config
  (evil-collection-define-key 'normal 'dired-mode-map
    "h" 'dired-single-up-directory
    "l" 'dired-single-buffer))

;;(use-package dired-single
  ;;:commands (dired dired-jump))

(use-package all-the-icons-dired
  :hook (dired-mode . all-the-icons-dired-mode))

(use-package dired-open
  :commands (dired dired-jump)
  :config
  ;; Doesn't work as expected!
  ;;(add-to-list 'dired-open-functions #'dired-open-xdg t)
  (setq dired-open-extensions '(("png" . "feh")
                                ("mkv" . "mpv"))))

;; (use-package dired-hide-dotfiles
;;   :hook (dired-mode . dired-hide-dotfiles-mode)
;;   :config
;;   (evil-collection-define-key 'normal 'dired-mode-map
;;     "H" 'dired-hide-dotfiles-mode))

(global-auto-revert-mode 1)

;; Make gc pauses faster by decreasing the threshold.
(setq gc-cons-threshold (* 2 1000 1000))

(use-package marginalia
  :ensure t
  :config
  (marginalia-mode))

(use-package embark
  :ensure t
  :bind
  (("C-x C-e" . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
  :init
  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Show the Embark target at point via Eldoc. You may adjust the
  ;; Eldoc strategy, if you want to see the documentation from
  ;; multiple providers. Beware that using this can be a little
  ;; jarring since the message shown in the minibuffer can be more
  ;; than one line, causing the modeline to move up and down:

  ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
  ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

  :config
  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

;; Consult users will also want the embark-consult package.
(use-package consult
  :ensure t
  )


(space-leader
  "f r" 'consult-find)
 


(use-package embark-consult
  :ensure t ; only need to install it, embark loads it after consult if found
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package async
  :ensure t)

(defun org-ref-arxiv-download-and-store (arxiv-number)
  "Download and store a paper from arXiv using its ARXIV-NUMBER."
  (interactive "sEnter arXiv number: ")
  (let* ((pdf-url (format "https://arxiv.org/pdf/%s.pdf" arxiv-number))))
  (arxiv-get-pdf-add-bibtex-entry arxiv-number
                                  "~/research/references.bib" "~/research/paper-pdfs/")
  (message "Paper downloaded and stored: %s" pdf-url))

(use-package elfeed
  :ensure t
  :config
  (setq elfeed-db-directory (expand-file-name "elfeed" user-emacs-directory))
  (setq elfeed-show-entry-switch 'display-buffer)
  (defun my/elfeed-entry-to-arxiv ()
    "Fetch an arXiv paper into the local library from the current elfeed entry."
    (interactive)
    (let* ((link (elfeed-entry-link elfeed-show-entry))
           (match-idx (string-match "arxiv.org/abs/\\([0-9.]*\\)" link))
           (matched-arxiv-number (match-string 1 link)))
      (when matched-arxiv-number
        (message "Going to arXiv: %s" matched-arxiv-number)
        (arxiv-get-pdf-add-bibtex-entry matched-arxiv-number "~/research/references.bib" "~/research/paper-pdfs/"))))
  (define-key elfeed-show-mode-map (kbd "C-c d p") 'my/elfeed-entry-to-arxiv)
  )

(use-package elfeed-org
  :after elfeed
  :config
  (setq rmh-elfeed-org-files (list "~/.config/emacs/elfeed.org"))
  (elfeed-org)
  )

;; (use-package elfeed-goodies
;;   :ensure t
;;   :config
;;   (setq elfeed-goodies:entry-line-format
;;         '("%-20{[%s]%}" ;; Date
;;           "%-65{%t}" ;; Title
;;           "%5{%s}" ;; Score
;;           "%7{[%f]%}" ;; Feed
;;           "%-10{%T%}" ;; Tags
;;           ))
;;   (elfeed-goodies/setup))

(use-package elfeed-score
  :ensure t
  :config
  (progn
    (setq elfeed-score-serde-score-file "~/.config/emacs/elfeed.score")
    (elfeed-score-enable)
    (define-key elfeed-search-mode-map "=" elfeed-score-map) 
    ))

  (general-create-definer elfeed-keybinds-set
    :keymaps '(normal visual elfeed-search-mode)
    :prefix "SPC")

  (elfeed-keybinds-set
   "x"  '(:ignore t :which-key "elfeed mngmt")
   "xs" 'elfeed-score-map
   )

; (setq elfeed-search-print-entry-function #'elfeed-goodies/entry-line-draw)

  ;;   (use-package elfeed-score
  ;;     :ensure t
  ;;     :after elfeed
  ;;     :config
  ;;     (elfeed-score-load-score-file "~/.config/emacs/elfeed.score") 
  ;;     (setq elfeed-search-print-entry-function #'elfeed-score-print-entry)
  ;;     ;;(setq elfeed-score-serde-score-file "~/.config/emacs/elfeed.score")
  ;;     (progn
  ;;       (elfeed-score-enable)
  ;;       (define-key elfeed-search-mode-map "=" elfeed-score-map)
  ;;       )
  ;;     )
  ;; (use-package elfeed-score
  ;;   :ensure t)

(use-package org-ref
  :after org
  :config
  (setq bibtex-dialect 'biblatex)
  ;;(setq bibtex-completion-pdf-field "file")
  (setq bibtex-completion-bibliography '("~/research/references.bib")
        bibtex-completion-library-path '("~/research/paper-pdfs/")
        bibtex-completion-notes-path "~/research/notes/"
        bibtex-completion-notes-template-multiple-files "*${author-or-editor},${title},${journal}, (${year}) :${=type=}: \n\nSee [[cite:&${=key=}]]\n"

        bibtex-completion-additional-search-fields '(keywords)
        bibtex-completion-display-formats
        '((article       . "${=has-pdf=:1}${=has-note=:1}${year:4}${author:36}${title:*}${journal:40}")
          (inbook        . "${=has-pdf=:1}${=has-note=:1}${year:4}${author:36}${title:*} Chapter${chapter:32}")
          (incollection  . "${=has-pdf=:1}${=has-note=:1}${year:4}${author:36}${title:*}${booktitle:40}")
          (inproceedings . "${=has-pdf=:1}${=has-note=:1}${year:4}${author:36}${title:*}${booktitle:40}")
          (t             . "${=has-pdf=:1}${=has-note=:1}${year:4}${author:36}${title:*}"))
  ;;       bibtex-completion-pdf-open-function
  ;;       (lambda (fpath)
  ;;         (call-process "open" nil 0 nil fpath))
	  )
  (require 'org-ref-ivy)
  (require 'openalex)
  (setq oa-api-key (getenv "OPEN_ALEX_API_KEY"))
  )

(use-package ivy-bibtex
  :ensure t)

  (general-create-definer ref-keybinds-set
    :keymaps '(normal visual emacs bibtex-mode-map)
    :prefix "SPC")

  (ref-keybinds-set
   "r"  '(:ignore t :which-key "ref mgmt")
   "rh" 'org-ref-bibtex-hydra/body
   "ri" 'org-ref-insert-link
   "rd" 'org-ref-arxiv-download-and-store
   "rs" 'ivy-bibtex
   )

  ;; (general-create-definer ivy-ref-keybinds-set
  ;;   ;; :keymaps '(normal visual emacs bibtex-mode-map)
  ;;   :keymaps '(normal visual emacs)
  ;;   :prefix "SPC")

  ;; (ivy-ref-keybinds-set
  ;;  "r"  '(:ignore t :which-key "ref mgmt")
  ;;  "rs" 'ivy-bibtex)

(use-package citar
:ensure t
;;:config
;;(setq citar-notes-paths '("~/research/notes/"))
:custom
(citar-bibliography
 '("~/research/references.bib")))


(use-package citar-embark
:ensure t
:after citar embark
:no-require
:config (citar-embark-mode))


(use-package citar-org-roam
  :after (citar org-roam)
:config (citar-org-roam-mode))

(use-package org-roam-bibtex
:after org-roam
:config
(require 'org-ref)) ; optional: if using Org-ref v2 or v3 citation links

(general-create-definer citar-keybindings
  ;; :keymaps '(normal visual emacs bibtex-mode-map)
  :keymaps '(normal visual emacs)
  :prefix "SPC")

(citar-keybindings
 "r"  '(:ignore t :which-key "ref mgmt")
 "rc" 'citar-open)

;; (setq package-vc-install-prompt nil)
;; (package-vc-install
;;  '(anki-editor . (:url "https://github.com/anki-editor/anki-editor")))

(unless (package-installed-p 'vc-use-package)
  (package-vc-install "https://github.com/slotThe/vc-use-package"))
(require 'vc-use-package)

(use-package anki-editor
  :vc (:fetcher github :repo anki-editor/anki-editor)
  :ensure t
  )

  (general-create-definer anki-keybinds-set
    :keymaps '(normal visual emacs)
    :prefix "SPC")

  (ref-keybinds-set
   "a"  '(:ignore t :which-key "anki")
   "ai" 'anki-editor-insert-note
   "ap" '(:ignore t :which "push")
   "apn" 'anki-editor-push-note-at-point
   "apa" ' anki-editor-push-new-notes)

(defun my-daemon-frame-setup (frame)
  ;; Custom setup function run on emacsclient frames
  (message "New emc frame created.")
  (select-frame (selected-frame))
  (set-background-color "black")
  (set-frame-font "Iosevka Nerd Font-22")
  )

;; (add-hook 'server-after-make-frame-hook #'my-daemon-frame-setup)


;; (when (daemonp)
;;   (message "Home directory: %s" (getenv "HOME"))

;;   )

;; (defun setup-theme (frame)
;; (with-selected-frame frame
;;   (load-theme 'gruber-darker t)
;;   (set-background-color "black")))

;; (if (daemonp)
;;     (add-hook 'after-make-frame-functions #'setup-theme)
;;   (setup-theme (selected-frame)))

;; (defun load-init-file ()
;;   "Load a init file."
;;   (interactive)
;;   (load-file "~/.config/emacs/init.el"))


;; (evil-define-key 'normal 'global (kbd "<leader>cl")
;;   'load-init-file)

(require 'server)
(unless (server-running-p)
  (server-start))

(use-package google-translate
  :ensure t)

(setq google-translate-default-source-language "auto")


; keybinds for translate
(general-define-key
  :keymaps '(normal visual emacs)
  :prefix "SPC"
  "l" 'google-translate-at-point)

(use-package plantuml-mode
  :ensure t
  :config 
  ;; Sample executable configuration
  (setq plantuml-executable-path "/usr/bin/plantuml")
  (setq plantuml-default-exec-mode 'executable)
  (setq org-plantuml-exec-mode 'executable)
  (setq org-plantuml-executable-path "/usr/bin/plantuml")
  (setq org-plantuml-jar-path "/home/anloehr/.local/bin/plantuml.jar"))

(with-eval-after-load 'bibtex-completion
  (setq bibtex-completion-pdf-open-function
        (lambda (fpath)
          (start-process "sioyek" nil "sioyek" fpath))))

(use-package openwith
  :ensure t
  :config
  (openwith-mode 1)
  (setq openwith-associations
      '(("\\.pdf\\'" "sioyek" (file))))
  )
