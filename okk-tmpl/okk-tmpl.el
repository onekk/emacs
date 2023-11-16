;;; okk-tmpl.el --- File templates
;;
;; Copyright (C) 2023 Dormeletti Carlo
;; based on file-template.el Copyright (C) 2007 Scott Frazer
;; link: https://www.emacswiki.org/emacs/file-template.el
;;
;; Author: Dormeletti Carlo <@gmail.com>
;; Maintainer: Dormeletti Carlo <@gmail.com>
;; Created: 17/10/2023
;; Version: 1.0
;;
;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;;
;; Insert template into buffer, performing tag expansions.
;;
;; See `okk-tmpl-tag-alist' for predefined tags.
;;
;;; Usage:
;;
;; Add this to your .emacs
;;
;;
;; (defvar okk-tmpl-dir <template-directory>)
;; (autoload 'okk-tmpl-insert "okk-tmpl" nil t)
;;
;;
;;; Change log:
;;
;; 17/10/2023 -- v1.0 - Initial creation
;; 19/10/2023 -- v1.1 - Start refining things, deleted automation
;; 03/11/2023 -- v1.2 - Added a way to skip parsing between tags %j %je

;;; Code:

(require 'custom)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Custom variables

(defgroup okk-tmpl nil
  "*Okk templates."
  :group 'okk-tmpl)

(defcustom okk-tmpl-login-name (user-login-name)
  "*User's login name."
  :group 'okk-tmpl
  :type 'string)

(defcustom okk-tmpl-full-name (user-full-name)
  "*User's full name."
  :group 'okk-tmpl
  :type 'string)

(defcustom okk-tmpl-num-prefix "0"
  "*String used as prefix for numerical days and months.
Suggested values are \" \", \"0\" and \"\"."
  :group 'okk-tmpl
  :type 'string)

(defcustom okk-tmpl-insert-hook nil
  "*List of functions to call after inserting a template."
  :group 'okk-tmpl
  :type 'hook)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Internal variables


(defvar okk-tmpl-history nil
  "Minibuffer history list for templates.")

(defvar okk-tmpl-prompt-start-point nil
  "Starting point for prompt string.")

(defvar okk-tmpl-prompted-strings nil
  "Strings prompted for (to fill in %1-%9 later in template).")

(defvar okk-tmpl-eval-start-point nil
  "Starting point for eval string.")

(defvar okk-tmpl-tag-alist
  '(("a" . user-mail-address)
    ("b" . (file-name-nondirectory (buffer-file-name)))
    ("d" . (okk-tmpl-pad-num-string (okk-tmpl-get-date-item 'day)))
    ("e" . (file-name-extension (buffer-file-name)))
    ("E" . (upcase (or (file-name-extension (buffer-file-name)) "")))
    ("f" . (buffer-file-name))
    ("j" . (okk-tmpl-skip))
    ("n" . (file-name-sans-extension (file-name-nondirectory (buffer-file-name))))
    ("N" . (upcase (file-name-sans-extension (file-name-nondirectory (buffer-file-name)))))
    ("m" . (okk-tmpl-get-month-num))
    ("M" . (okk-tmpl-get-date-item 'month))
    ("p" . (file-name-directory (buffer-file-name)))
    ("q" . (fill-paragraph nil))
    
    ("u" . okk-tmpl-login-name)
    ("U" . okk-tmpl-full-name)
    ("y" . (substring (okk-tmpl-get-date-item 'year) -2))
    ("Y" . (okk-tmpl-get-date-item 'year))
    ("[" . (okk-tmpl-start-prompt))
    ("]" . (okk-tmpl-finish-prompt))
    ("1" . (okk-tmpl-get-nth-prompted 1))
    ("2" . (okk-tmpl-get-nth-prompted 2))
    ("3" . (okk-tmpl-get-nth-prompted 3))
    ("4" . (okk-tmpl-get-nth-prompted 4))
    ("5" . (okk-tmpl-get-nth-prompted 5))
    ("6" . (okk-tmpl-get-nth-prompted 6))
    ("7" . (okk-tmpl-get-nth-prompted 7))
    ("8" . (okk-tmpl-get-nth-prompted 8))
    ("9" . (okk-tmpl-get-nth-prompted 9))
    ("(" . (okk-tmpl-start-eval))
    (")" . (okk-tmpl-finish-eval))
    ("%" . "%")
    )
  
  "Lookup table mapping % tags to variable/function.  Return a string
to be inserted into the buffer; non-strings are ignored.  Predefined
tags are:

 %u       user's login name
 %U       user's full name
 %a       user's mail address (from the variable `user-mail-address')
 %f       file name with path
 %b       file name without path
 %n       file name without path and extension
 %N       file name without path and extension, capitalized
 %e       file extension
 %E       file extension capitalized
 %p       file directory
 %j       skip tags until %je is found
 %d       day
 %m       month
 %M       abbreviated month name
 %y       last two digits of year
 %Y       year
 %q       `fill-paragraph'
 %[ %]    prompt user for a string
 %1-%9    refer to the nth strings prompted for with %[ %]
 %( %)    elisp form to be evaluated
 %%       inserts %


Note: %j is deleted but following character are not deleted. While the whole line
containing %je is deleted.
")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Functions

(defun okk-tmpl-get-date-item (item)
  "item can be 'day, 'month, or 'year."
  (let ((time-string (current-time-string)))
    (when (string-match "^\\w+\\s-+\\(\\w+\\)\\s-+\\([0-9]+\\)\\s-+[0-9]+:[0-9]+:[0-9]+\\s-+\\([0-9]+\\)" time-string)
      (cond
       ((equal item 'day)
        (match-string 2 time-string))
       ((equal item 'month)
        (match-string 1 time-string))
       ((equal item 'year)
        (match-string 3 time-string))))))

(defun okk-tmpl-get-month-num ()
  "Get month as a number."
  (let ((month (okk-tmpl-get-date-item 'month))
        (month-names '("Dec" "Nov" "Oct" "Sep" "Aug" "Jul" "Jun" "May" "Apr" "Mar" "Feb" "Jan")))
    (catch 'found
      (while month-names
        (if (string= month (car month-names))
            (throw 'found (okk-tmpl-pad-num-string (int-to-string (length month-names))))
          (setq month-names (cdr month-names)))))))

(defun okk-tmpl-pad-num-string (num-string)
  "Pad out a number string."
  (let ((result (concat okk-tmpl-num-prefix num-string)))
    (if (> (length result) 2)
        (substring result -2)
      result)))

(defun okk-tmpl-get-nth-prompted (n)
  "Get nth prompted string."
  (if (> n (length okk-tmpl-prompted-strings))
      (error "There are only %d prompted strings so far, and you tried to expand %%%d"
             (length okk-tmpl-prompted-strings) n)
    (nth (1- n) okk-tmpl-prompted-strings)))

(defun okk-tmpl-start-prompt ()
  "Start prompting for input."
  (if okk-tmpl-prompt-start-point
      (error "Nested prompts are not allowed")
    (setq okk-tmpl-prompt-start-point (point))))

(defun okk-tmpl-finish-prompt ()
  "Finish prompting for input."
  (if (not okk-tmpl-prompt-start-point)
      (error "No matching %%[")
    (let ((prompt (buffer-substring okk-tmpl-prompt-start-point (point))) answer)
      (delete-region okk-tmpl-prompt-start-point (point))
      (setq answer (read-string prompt))
      (setq okk-tmpl-prompted-strings (append okk-tmpl-prompted-strings (list answer)))
      (setq okk-tmpl-prompt-start-point nil)
      answer)))

(defun okk-tmpl-start-eval ()
  "Start eval of elisp."
  (if okk-tmpl-eval-start-point
      (error "Nested evals are not allowed")
    (setq okk-tmpl-eval-start-point (point))))

(defun okk-tmpl-finish-eval ()
  "Finish eval of elisp."
  (if (not okk-tmpl-eval-start-point)
      (error "No matching %%(")
    (let ((form (buffer-substring okk-tmpl-eval-start-point (point))))
      (delete-region okk-tmpl-eval-start-point (point))
      (save-excursion
        (save-restriction
          (setq okk-tmpl-eval-start-point nil)
          (eval (car (read-from-string form))))))))

(defun okk-tmpl-skip ()
  "Skip to %je tag avoid parsing"
  (search-forward "%je" nil t)
  ;; delete %je point is after the search
  ;;(delete-char -3)
  ;; delete line on which point is
  (delete-region (progn (forward-line 0) (point)) (progn (forward-line 1) (point)))
  )


;;;###autoload

(defun okk-tmpl-insert (template)
  "Insert template into buffer, performing tag expansions.
See `okk-tmpl-tag-alist' for list of predefined tags."

  (interactive (list (read-file-name "Template file to insert: " okk-tmpl-dir nil t)))
  (setq okk-tmpl-prompt-start-point nil)
  (setq okk-tmpl-prompted-strings '())
  (setq okk-tmpl-eval-start-point nil)
  (save-restriction
    (narrow-to-region (point) (point))
    (insert-file-contents template)
    (let (char result)
      (while (search-forward "%" nil t)
        (delete-char -1)
        (setq char (char-after))
        (delete-char 1)
        (setq result (assoc (char-to-string char) okk-tmpl-tag-alist))
        (if (not result)
            (error "Unknown tag %%%c" char)
          (setq result (eval (cdr result)))
          (when (stringp result)
            (insert result))))
    )
    (run-hooks 'okk-tmpl-insert-hook))
  )


(provide 'okk-tmpl)
;;; okk-tmpl.el ends here
