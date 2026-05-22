;;;  package --- Summary
; Custom org babel fun
;;; Commentary:
(require 'ob)

(defun org-babel-execute:dot2tex (body params)
  "Execute a block of Dot code with dot2tex."
  (let* ((out-file (or (cdr (assq :file params))
                       (error "You need to specify a :file parameter")))
         (cmdline (or (cdr (assq :cmdline params)) ""))
         (cmd (format "dot2tex -o %s %s" (org-babel-process-file-name out-file) cmdline)))
    (org-babel-eval cmd body)
    nil))

(add-to-list 'org-src-lang-modes '("dot2tex" . graphviz-dot))

(provide 'ob-dot2tex)
