;;; arduino-cli-mode.el --- Arduino-CLI command wrapper -*- lexical-binding: t -*-

;; Original Package
;; Copyright © 2023
;; Author: Carlo Dormeletti
;; URL: https://github.com/onekk/emacs/arduino-cli-mode
;; Version: 20240623
;; Package-Requires: ((emacs "25.1"))
;; Created: 2023-11-16
;; Keywords: processes tools

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; arduino-cli-mode is an Emacs minor mode for using the excellent new
;; Arduino command line interface in an Emacs-native fashion.
;;
;; It is a subset of the code at:
;;    https://github.com/motform/arduino-cli-modes
;;    Copyright © 2019 Author: Love Lagerkvist
;;
;; It is aimed mainly to compile the ino file and do some other minor
;; things, like to list:
;; - boards
;; - cores
;; - libraries
;; 
;; For more information on arduino-cli itself,
;; see https://github.com/arduino/arduino-cli
;;
;; Tested against arduino-cli >= 1.0.0 on Linux

;;; Code:

(require 'compile)
(require 'json)
(require 'map)
(require 'seq)
(require 'subr-x)

(eval-when-compile (require 'cl-lib))

;;; Customization
(defgroup arduino-cli nil
  "Arduino-cli-mode functions and settings."
  :group  'tools
  :prefix "arduino-cli-"
  :link   '(url-link https://github.com/onekk/emacs/arduino-cli-mode)
  )

(defcustom arduino-cli-mode-keymap-prefix (kbd "C-c C-a")
  "Arduino-cli keymap prefix."
  :group 'arduino-cli
  :type  'string)

(defcustom arduino-cli-defcmd "arduino-cli"
  "Default command to use."
  :group 'arduino-cli
  :type  'string)

(defcustom arduino-cli-config-file nil
  "Default configuration file path."
  :group 'arduino-cli
  :type  'string)

(defcustom arduino-cli-verify nil
  "Verify uploaded binary after the upload."
  :group 'arduino-cli
  :type  'boolean)

(defcustom arduino-cli-warnings nil
  "Set GCC warning level, can be nil (default), 'default, 'more or 'all."
  :group 'arduino-cli
  :type  'boolean)

(defcustom arduino-cli-verbosity nil
  "Set arduino-cli verbosity level, can be nil (default), 'quiet or 'verbose."
  :group 'arduino-cli
  :type  'boolean)

(defcustom arduino-cli-compile-only-verbosity t
  "If true (default), only apply verbosity setting to compilation."
  :group 'arduino-cli
  :type 'boolean)

;;; Internal functions
(define-compilation-mode arduino-cli-compilation-mode "arduino-cli-compilation"
  "Arduino-cli specific `compilation-mode' derivative."
  (setq-local compilation-scroll-output t)
  (require 'ansi-color))

(defun arduino-cli--?map-put (m v k)
  "Puts V in M under K when V, else return M."
  (if v (setf (map-elt m k) v)) m)

(defun arduino-cli--verify ()
  "Get verify bool."
  (when arduino-cli-verify " -t"))

(defun arduino-cli--verbosity ()
  "Get the current verbosity level."
  (pcase arduino-cli-verbosity
    ('quiet   " --quiet")
    ('verbose " --verbose")))

(defun arduino-cli--warnings ()
  "Get the current warnings level."
  (when arduino-cli-warnings
    (concat " --warnings " (symbol-name arduino-cli-warnings))))

(defun arduino-cli--general-flags ()
  "Add flags to CMD, if set."
  (concat (unless arduino-cli-compile-only-verbosity
            (arduino-cli--verbosity))))

(defun arduino-cli--compile-flags ()
  "Add flags to CMD, if set."
  (concat (arduino-cli--warnings)
          (arduino-cli--verbosity)))

(defun arduino-cli--add-flags (mode cmd)
  "Add general and MODE flags to CMD, if set."
  (concat cmd (pcase mode
                ('compile (arduino-cli--compile-flags))
                (_        (arduino-cli--general-flags)))))

(defun arduino-cli--compile (cmd)
  "Run arduino-cli CMD in 'arduino-cli-compilation-mode."
  (let* ((cmd  (concat arduino-cli-defcmd  " " cmd " " (shell-quote-argument default-directory)))
         (cmd* (arduino-cli--add-flags 'compile cmd)))
    (save-some-buffers (not compilation-ask-about-save) (lambda () default-directory))
    (compilation-start cmd* 'arduino-cli-compilation-mode)))

(defun arduino-cli--message (cmd &rest path)
  "Run arduino-cli CMD in PATH (if provided) and print as message."
  (let* ((default-directory (shell-quote-argument (if path (car path) default-directory)))
         (cmd  (concat arduino-cli-defcmd " " cmd))
         (cmd* (arduino-cli--add-flags 'message cmd))
         (out  (shell-command-to-string cmd*)))
    (message out)))

(defun arduino-cli--arduino? (usb-device)
  "Return USB-DEVICE if it is an Arduino, nil otherwise."
  (assoc 'boards usb-device))

(defun arduino-cli--cmd-json (cmd)
  "Get the result of CMD as JSON-style alist."
  (let* ((cmmd (concat arduino-cli-defcmd " " cmd " --format json")))
    (thread-first cmmd shell-command-to-string json-read-from-string)))

(defun arduino-cli--default-board ()
  "Get the default Arduino board, if available."
  (thread-first '()
    (arduino-cli--?map-put arduino-cli-default-fqbn 'FQBN)
    (arduino-cli--?map-put arduino-cli-default-port 'address)))

(defun arduino-cli--cores ()
  "Get installed Arduino cores."
  (let* ((cores    (arduino-cli--cmd-json "core list"))
         (id-pairs (seq-map (lambda (m) (assoc 'ID m)) cores))
         (ids      (seq-map #'cdr id-pairs)))
    (if ids ids
      (error "ERROR: No cores installed"))))

(defun arduino-cli--libs ()
  "Get installed Arduino libraries."
  (let* ((libs      (arduino-cli--cmd-json "lib list"))
         (lib-names (seq-map (lambda (lib) (cdr (assoc 'name (assoc 'library lib)))) libs)))
    (if lib-names lib-names
      (error "ERROR: No libraries installed"))))

(defun arduino-cli--select (xs msg)
  "Select option from XS, prompted by MSG."
  (completing-read msg xs))


;;; User commands
(defun arduino-cli-compile ()
  "Compile Arduino project."
  (interactive)
  (let* (
          (cmd (concat "compile " "")))
    (arduino-cli--compile cmd)))

(defun arduino-cli-compile-and-upload ()
  "Compile and upload Arduino project."
  (interactive)
  (let* (
         (cmd   (concat "compile " "--upload")))
    (arduino-cli--compile cmd)))

(defun arduino-cli-upload ()
  "Upload Arduino project."
  (interactive)
  (let* (
         (cmd (concat "upload" "" )))
    (arduino-cli--compile cmd)))

(defun arduino-cli-board-list ()
  "Show list of connected Arduino boards."
  (interactive)
  (arduino-cli--message "board list"))

(defun arduino-cli-board-listall ()
  "Show list of Arduino boards."
  (interactive)
  (arduino-cli--message "board listall"))

(defun arduino-cli-core-list ()
  "Show list of installed Arduino cores."
  (interactive)
  (arduino-cli--message "core list"))

(defun arduino-cli-lib-list ()
  "Show list of installed Arduino libraries."
  (interactive)
  (arduino-cli--message "lib list"))

(defun arduino-cli-new-sketch ()
  "Create a new Arduino sketch."
  (interactive)
  (let* ((name (read-string "Sketch name: "))
         (path (read-directory-name "Sketch path: "))
         (cmd  (concat "sketch new " name)))
    (arduino-cli--message cmd path)))

;; Insert a command to create a  with a content:
(defun arduino-cli-new-sketch-yaml ()
  "Create a new sketch.yaml in sketch directory."
  (interactive)
  (let* (
          (sketch-yaml (concat (file-name-directory buffer-file-name) "/sketch.yaml")))
          ;;(fqbn (read-string "Board name: "))
    (message "Writing `%s'..." sketch-yaml)
    (with-temp-file sketch-yaml
      (insert "# sketch.yaml \n")
      (insert "default_fqbn: arduino:avr:uno \n")
      (insert "# default_port: /dev/ttyACM0\n")
      ;; (insert (format "default_profile: %s \n" (file-name-base buffer-file-name)))
     )
   )
  )


;;arduino:avr:uno
; 

(defun arduino-cli-config-init ()
  "Create a new Arduino config."
  (interactive)
  (when (y-or-n-p "Init will override any existing config files, are you sure? ")
    (arduino-cli--message "config init")))

(defun arduino-cli-config-dump ()
  "Dump the current Arduino config."
  (interactive)
  (arduino-cli--message "config dump"))

(defun arduino-cli-config-edit ()
  "Edit the current Arduino config."
  (interactive)
  (find-file arduino-cli-config-file))


;;; Minor mode
(defvar arduino-cli-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") #'arduino-cli-compile)
    (define-key map (kbd "b") #'arduino-cli-compile-and-upload)
    (define-key map (kbd "u") #'arduino-cli-upload)
    (define-key map (kbd "n") #'arduino-cli-new-sketch)
    (define-key map (kbd "l") #'arduino-cli-board-list)
    map)
  "Keymap for arduino-cli mode commands after `arduino-cli-mode-keymap-prefix'.")
(fset 'arduino-cli-command-map arduino-cli-command-map)

(defvar arduino-cli-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map arduino-cli-mode-keymap-prefix 'arduino-cli-command-map)
    map)
  "Keymap for arduino-cli mode.")


(easy-menu-define arduino-cli-menu arduino-cli-mode-map
  "Menu for arduino-cli."
  `("Arduino-CLI"
    ("Sketch"
      ["New sketch" arduino-cli-new-sketch]
      ["New sketch.yaml" arduino-cli-new-sketch-yaml]
    )
    "--"
    ["Open Project Directory" (find-file (file-name-directory buffer-file-name))]
    ["Compile Project"            arduino-cli-compile]
    ["Upload Project"             arduino-cli-compile-and-upload]
    ["Compile and Upload Project" arduino-cli-upload]
    "--"
    ["Board list"       arduino-cli-board-list]
    ["Board listall"    arduino-cli-board-listall]
    ["Core list"        arduino-cli-core-list]
    ["Library list"      arduino-cli-lib-list]
    "--" 
    ("Config"
      ["Config init" arduino-cli-config-init]
      ["Config dump" arduino-cli-config-dump]
      ["Edit config" arduino-cli-config-edit]
    )
    ))

;;;###autoload
(define-derived-mode arduino-cli-mode c++-mode "arduino"
  "Major mode for editing Arduino code."
  ;; try to integrate treesitter
  ;;(when (treesit-ready-p 'arduino)
  ;;  (treesit-parser-create 'arduino)
  ;; set some variables
  (set (make-local-variable 'c-basic-offset) 4)
  (set (make-local-variable 'tab-width) 4)
  :lighter " arduino-cli"
  :keymap   arduino-cli-mode-map
  :group   'arduino-cli
  :require 'arduino-cli  
)

(provide 'arduino-cli-mode)
;;; arduino-cli-mode.el ends here
