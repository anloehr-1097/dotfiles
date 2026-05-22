;;; org-agenda-manifest.el --- Dynamic org-agenda file management with global/local split

;;; Commentary:
;; This module provides functions to manage org-agenda files from separate global and local manifests.
;; Instead of hardcoding agenda files in init.el, this reads them from:
;;   ~/.org-agenda/global.org  - Files synced across machines
;;   ~/.org-agenda/local.org   - Machine-specific files
;; 
;; Both manifest files are simple org-mode files with bullet points listing file paths.
;; File paths can be relative to home (~/) or absolute.
;; 
;; Usage:
;;   (org-agenda-manifest-setup)  ;; Initialize org-agenda-files from both manifests
;;   (org-agenda-manifest-add-file file &optional local)  ;; Add to global (default) or local
;;   (org-agenda-manifest-remove-file file)  ;; Remove from whichever manifest has it
;;   (org-agenda-manifest-toggle-file file)  ;; Move file between global and local

;;; Code:

(require 'org-agenda)
(require 'subr-x)

(defvar org-agenda-manifest-dir (expand-file-name "~/.org-agenda")
  "Directory containing manifest files.")

(defvar org-agenda-manifest-global-file 
  (expand-file-name "global.org" org-agenda-manifest-dir)
  "Path to the global org-agenda manifest file (synced across machines).")

(defvar org-agenda-manifest-local-file
  (expand-file-name "local.org" org-agenda-manifest-dir)
  "Path to the local org-agenda manifest file (machine-specific).")

(defvar org-agenda-manifest-refile-maxlevel 3
  "Outline depth used for refiling targets derived from the global manifest.")

(defun org-agenda-manifest--expand-path (path)
  "Expand PATH to absolute path, handling ~ expansion."
  (expand-file-name path))

(defun org-agenda-manifest--file-exists-p (path)
  "Check if file at PATH exists."
  (file-exists-p (org-agenda-manifest--expand-path path)))

(defun org-agenda-manifest--parse-manifest-file (manifest-file)
  "Parse MANIFEST-FILE and return list of valid file paths.
Returns only files that exist. Skips invalid/non-existent paths."
  (if (not (file-exists-p manifest-file))
      nil
    (with-temp-buffer
      (insert-file-contents manifest-file)
      (let ((files nil))
        (goto-char (point-min))
        (while (re-search-forward "^[[:space:]]*-[[:space:]]+\\(.*\\)$" nil t)
          (let* ((path (string-trim (match-string 1)))
                 (expanded (org-agenda-manifest--expand-path path)))
            (if (file-exists-p expanded)
                (push expanded files)
              (message "Warning: agenda file not found: %s" path))))
        (reverse files)))))

(defun org-agenda-manifest--read-global ()
  "Read and return list of global agenda files."
  (org-agenda-manifest--parse-manifest-file org-agenda-manifest-global-file))

(defun org-agenda-manifest--read-local ()
  "Read and return list of local agenda files."
  (org-agenda-manifest--parse-manifest-file org-agenda-manifest-local-file))

(defun org-agenda-manifest--read-all ()
  "Read and merge all agenda files (global + local).
Returns combined list with global files first, then local files."
  (let ((global (org-agenda-manifest--read-global))
        (local (org-agenda-manifest--read-local)))
    (append global local)))

(defun org-agenda-manifest-refile-targets ()
  "Return `org-refile-targets` entries for files in the global manifest."
  (mapcar (lambda (file)
            (cons file `(:maxlevel . ,org-agenda-manifest-refile-maxlevel)))
          (org-agenda-manifest--read-global)))

(defun org-agenda-manifest--merge-refile-targets (targets)
  "Merge TARGETS with manifest-backed refile targets, replacing overlaps."
  (let ((manifest-files (org-agenda-manifest--read-global))
        (filtered nil)
        (dynamic-targets (org-agenda-manifest-refile-targets)))
    (dolist (target targets)
      (unless (member (car target) manifest-files)
        (push target filtered)))
    (append (nreverse filtered) dynamic-targets)))

(defun org-agenda-manifest--sync-org-state ()
  "Refresh the live Org agenda and refile configuration from manifests."
  (setq org-agenda-files (org-agenda-manifest--read-all))
  (setq org-refile-targets
        (org-agenda-manifest--merge-refile-targets org-refile-targets)))

(defun org-agenda-manifest--which-manifest (file)
  "Determine which manifest FILE is in.
Returns 'global, 'local, or nil if not found."
  (let ((expanded (org-agenda-manifest--expand-path file)))
    (cond
      ((member expanded (org-agenda-manifest--read-global)) 'global)
      ((member expanded (org-agenda-manifest--read-local)) 'local)
      (t nil))))

(defun org-agenda-manifest--write-manifest (files manifest-file)
  "Write FILES list to MANIFEST-FILE, preserving header and structure."
  (with-temp-buffer
    ;; Read existing manifest to preserve header
    (when (file-exists-p manifest-file)
      (insert-file-contents manifest-file)
      (goto-char (point-min))
      ;; Find the "** Agenda Files" section (or similar)
      (if (re-search-forward "^\\*\\*" nil t)
          (progn
            (end-of-line)
            (delete-region (point) (point-max)))
        ;; If no section found, keep whole file and append to end
        (goto-char (point-max))))
    
    (unless (buffer-modified-p)
      ;; Create new manifest structure if file didn't exist or was empty
      (if (string-match "local" manifest-file)
          (progn
            (insert "* Org Agenda Files (Local)\n\n")
            (insert "Machine-specific agenda files that don't sync across machines.\n")
            (insert "Add or remove file paths below as needed.\n\n")
            (insert "** Local Agenda Files\n"))
        (progn
          (insert "* Org Agenda Files\n\n")
          (insert "Global agenda files synced across machines via Syncthing.\n")
          (insert "Add or remove file paths below as needed.\n\n")
          (insert "** Agenda Files\n"))))
    
    ;; Add the files
    (dolist (file files)
      (insert "\n- " file))
    
    (insert "\n")
    
    ;; Write to file
    (write-region (point-min) (point-max) manifest-file nil 'quiet)))

(defun org-agenda-manifest--setup ()
  "Initialize org-agenda-files from global and local manifests."
  (let ((files (org-agenda-manifest--read-all)))
    (org-agenda-manifest--sync-org-state)
    (let ((global-count (length (org-agenda-manifest--read-global)))
          (local-count (length (org-agenda-manifest--read-local))))
      (message "Loaded org-agenda-files: %d global + %d local = %d total" 
               global-count local-count (length files)))))

(defun org-agenda-manifest-add-file (file &optional local)
  "Add FILE to manifest (global by default, or local if LOCAL is non-nil).
Checks if file exists before adding."
  (let ((expanded (org-agenda-manifest--expand-path file)))
    (if (not (file-exists-p expanded))
        (error "File does not exist: %s" file)
      (let* ((target-manifest (if local 
                                  org-agenda-manifest-local-file
                                org-agenda-manifest-global-file))
             (current-files (org-agenda-manifest--parse-manifest-file target-manifest)))
        ;; Add to front
        (unless (member expanded current-files)
          (let ((updated-files (cons expanded current-files)))
            (org-agenda-manifest--write-manifest updated-files target-manifest)
            ;; Also update the live org-agenda and refile settings
            (org-agenda-manifest--sync-org-state)))
        (message "Added %s to %s agenda manifest" 
                 file (if local "local" "global"))))))

(defun org-agenda-manifest-remove-file (file)
  "Remove FILE from whichever manifest contains it."
  (let ((expanded (org-agenda-manifest--expand-path file))
        (manifest-location (org-agenda-manifest--which-manifest file)))
    (if (not manifest-location)
        (message "File not found in any manifest: %s" file)
      (let* ((target-manifest (if (eq manifest-location 'global)
                                  org-agenda-manifest-global-file
                                org-agenda-manifest-local-file))
             (current-files (org-agenda-manifest--parse-manifest-file target-manifest))
             (updated-files (remove expanded current-files)))
        (when (not (equal current-files updated-files))
          (org-agenda-manifest--write-manifest updated-files target-manifest)
          ;; Also update the live org-agenda and refile settings
          (org-agenda-manifest--sync-org-state)
          (message "Removed %s from %s agenda manifest" 
                   file (if (eq manifest-location 'global) "global" "local")))))))

(defun org-agenda-manifest-toggle-file (file)
  "Move FILE between global and local manifests.
If in global, move to local. If in local, move to global."
  (let ((location (org-agenda-manifest--which-manifest file)))
    (unless location
      (error "File not found in any manifest: %s" file))
    (let ((local-p (eq location 'local)))
      ;; Remove from current location
      (org-agenda-manifest-remove-file file)
      ;; Add to opposite location
      (org-agenda-manifest-add-file file (not local-p))
      ;; Report what was done
      (message "Moved %s from %s to %s manifest"
               file 
               (if local-p "local" "global")
               (if local-p "global" "local")))))

(defun org-agenda-manifest-refresh ()
  "Refresh org-agenda-files from both manifests."
  (interactive)
  (org-agenda-manifest--setup)
  (message "Refreshed org-agenda-files from manifests"))

(defun org-agenda-manifest-list-files ()
  "Display list of all agenda files, grouped by global and local."
  (interactive)
  (let ((global (org-agenda-manifest--read-global))
        (local (org-agenda-manifest--read-local))
        (buf (get-buffer-create "*Org Agenda Manifests*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Org Agenda Files\n")
        (insert "================\n\n")
        
        (insert "GLOBAL FILES (synced via Syncthing):\n")
        (insert (format "  Count: %d\n" (length global)))
        (dolist (f global)
          (insert (format "  - %s\n" f)))
        
        (insert "\nLOCAL FILES (machine-specific):\n")
        (insert (format "  Count: %d\n" (length local)))
        (dolist (f local)
          (insert (format "  - %s\n" f)))
        
        (insert (format "\nTotal: %d files\n" (+ (length global) (length local)))))
      (display-buffer buf))))

;;;###autoload
(defun org-agenda-manifest-setup ()
  "Setup org-agenda-files from global and local manifest files.
Call this in your init.el instead of setting org-agenda-files directly."
  ;; Create directory if it doesn't exist
  (unless (file-exists-p org-agenda-manifest-dir)
    (make-directory org-agenda-manifest-dir t))
  
  ;; Initialize org-agenda-files
  (org-agenda-manifest--setup)
  
  ;; Hook into org-agenda operations to keep manifests in sync
  (advice-add 'org-agenda-file-to-front :after 
    (lambda (file &rest _)
      (when file
        (let* ((expanded (expand-file-name file))
               (all-files (org-agenda-manifest--read-all)))
          (unless (member expanded all-files)
            ;; Add to global by default
            (let ((global-files (org-agenda-manifest--read-global)))
              (let ((updated-files (cons expanded global-files)))
                (org-agenda-manifest--write-manifest updated-files 
                                                     org-agenda-manifest-global-file)
                (org-agenda-manifest--sync-org-state))))))))
  
  (advice-add 'org-agenda-remove-file :after
    (lambda (file &rest _)
      (when file
        (let ((location (org-agenda-manifest--which-manifest file)))
          (when location
            (let* ((target-manifest (if (eq location 'global)
                                        org-agenda-manifest-global-file
                                      org-agenda-manifest-local-file))
                   (expanded (expand-file-name file))
                   (current-files (org-agenda-manifest--parse-manifest-file target-manifest))
                   (updated-files (remove expanded current-files)))
              (when (not (equal current-files updated-files))
                (org-agenda-manifest--write-manifest updated-files target-manifest)
                (org-agenda-manifest--sync-org-state)))))))))

(provide 'org-agenda-manifest)
;;; org-agenda-manifest.el ends here
