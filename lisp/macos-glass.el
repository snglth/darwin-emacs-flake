;;; macos-glass.el --- Ghostty-like macOS glass frame -*- lexical-binding: t; -*-

;; Enables the liquid-glass frame provided by the `frame-transparency' +
;; `ns-glass-effect' patches in this flake (see README).  Load it from your
;; init, e.g.:
;;
;;   (add-to-list 'load-path "/path/to/darwin-emacs-flake/lisp")
;;   (require 'macos-glass)
;;   (macos-glass-set-style 'regular)   ; or 'clear
;;
;; It is a no-op off macOS, and degrades gracefully on an Emacs built WITHOUT
;; the glass patches: it detects whether the running binary exports the
;; `ns-glass-material' symbol and, if not, falls back to plain
;; transparency + background blur (which only need the `frame-transparency'
;; patch).  The native glass effect itself also needs the macOS 26 SDK at
;; build time.

;;; Code:

(defgroup macos-glass nil
  "Ghostty-like macOS glass frame."
  :group 'frames
  :prefix "macos-glass-")

(defcustom macos-glass-style 'regular
  "Active glass preset.  One of the keys in `macos-glass-presets'."
  :type 'symbol
  :group 'macos-glass)

(defcustom macos-glass-transparent-titlebar t
  "Whether to make the titlebar transparent (`ns-transparent-titlebar')."
  :type 'boolean
  :group 'macos-glass)

(defcustom macos-glass-alpha-elements '(ns-alpha-all)
  "Which frame elements render with transparency (`ns-alpha-elements').

NOTE: `ns-alpha-glyphs' is all-or-nothing.  The patch forces EVERY glyph
background fill to the frame's `alpha-background', overriding each face's
own alpha.  So you cannot keep default text transparent while making the
selection/`region'/`hl-line' opaque by tweaking this list:

  - with `ns-alpha-glyphs'  -> default text is glassy, but selection
    highlights are also forced near-invisible at a low `alpha-background';
  - without `ns-alpha-glyphs' -> selection is opaque, but so is ALL text
    (every glyph gets an opaque background box).

To keep the glass look AND a visible selection, leave this at
`(ns-alpha-all)' and raise `alpha-background' via
`macos-glass-min-readable-alpha' instead.

Available elements: `ns-alpha-all', `ns-alpha-default' (default face
background), `ns-alpha-fringe', `ns-alpha-box', `ns-alpha-stipple',
`ns-alpha-relief', `ns-alpha-glyphs'."
  :type '(repeat symbol)
  :group 'macos-glass)

(defcustom macos-glass-min-readable-alpha 0.12
  "Lower bound applied to each preset's `alpha-background'.

Because `ns-alpha-glyphs' ties selection/`region'/`hl-line' visibility to
`alpha-background' (see `macos-glass-alpha-elements'), a near-zero alpha
like 0.01 makes those highlights invisible.  Clamping up to this value
keeps them legible while staying translucent.  Set to 0.0 to honour the
preset's raw alpha (maximum glass, faint selection)."
  :type 'number
  :group 'macos-glass)

(defconst macos-glass-presets
  '((regular
     :material regular
     :alpha 0.01
     :blur 0
     :tint-opacity 0.05
     :saturation 1.4
     :inactive-opacity 0.05
     :corner-radius 2
     :fallback-alpha 0.70
     :fallback-blur 30)
    (clear
     :material clear
     :alpha 0.01
     :blur 0
     :tint-opacity 0.01
     :saturation 1.2
     :inactive-opacity nil
     :corner-radius 0
     :fallback-alpha 0.58
     :fallback-blur 40))
  "Built-in glass presets.
Each entry maps a style name to a plist of frame-parameter values.
The `:fallback-*' values are used on an Emacs built without the glass
patches (plain transparency + blur instead of native glass).")

(defun macos-glass--preset (style)
  "Return the plist for STYLE, or signal an error."
  (or (alist-get style macos-glass-presets)
      (user-error "Unknown glass style: %s" style)))

(defvar macos-glass--native-build-cache 'unknown
  "Memoized result of `macos-glass--native-build-p'.")

(defun macos-glass--native-build-p ()
  "Return non-nil if the running Emacs honors the glass frame parameters.
Probes at runtime: the patched C handler signals an error for an
unknown `ns-glass-material' value, whereas an unpatched Emacs silently
stores any value.  This works regardless of how Emacs was launched
\(direct binary, daemon, or `-with-packages' wrapper), unlike inspecting
the executable on disk.  Requires a graphic frame; the result is cached."
  (cond
   ;; Already determined on a real graphic frame.
   ((not (eq macos-glass--native-build-cache 'unknown))
    macos-glass--native-build-cache)
   ;; Cannot probe yet (non-darwin, or a daemon/TTY with no GUI frame).
   ;; Return nil but DO NOT cache, so the first graphic frame re-probes.
   ((not (and (eq system-type 'darwin) (display-graphic-p)))
    nil)
   (t
    (setq macos-glass--native-build-cache
          (let ((saved (frame-parameter nil 'ns-glass-material)))
            (unwind-protect
                (condition-case nil
                    (progn
                      (set-frame-parameter
                       nil 'ns-glass-material 'macos-glass--probe)
                      ;; No error => unpatched: it just stored the value.
                      nil)
                  (error t))
              (set-frame-parameter nil 'ns-glass-material saved)))))))

(defun macos-glass--frame-parameters (style)
  "Compute the frame parameter alist for STYLE.
On a non-glass build, only transparency/blur parameters are returned,
using the preset's fallback values."
  (let* ((preset (macos-glass--preset style))
         (native (macos-glass--native-build-p)))
    (append
     `((ns-transparent-titlebar . ,macos-glass-transparent-titlebar)
       (alpha-background
        . ,(max macos-glass-min-readable-alpha
                (if native
                    (plist-get preset :alpha)
                  (plist-get preset :fallback-alpha))))
       (ns-background-blur
        . ,(if native
               (plist-get preset :blur)
             (plist-get preset :fallback-blur)))
       (ns-alpha-elements . ,macos-glass-alpha-elements))
     (when native
       `((ns-glass-material . ,(plist-get preset :material))
         (ns-glass-tint-opacity . ,(plist-get preset :tint-opacity))
         (ns-glass-saturation . ,(plist-get preset :saturation))
         (ns-glass-inactive-opacity . ,(plist-get preset :inactive-opacity))
         (ns-glass-corner-radius . ,(plist-get preset :corner-radius)))))))

(defun macos-glass--apply (&optional frame)
  "Apply the active glass style to FRAME (defaults to the selected frame)."
  (with-selected-frame (or frame (selected-frame))
    (pcase-dolist (`(,param . ,value)
                   (macos-glass--frame-parameters macos-glass-style))
      (set-frame-parameter nil param value))))

;;;###autoload
(defun macos-glass-set-style (style)
  "Switch to glass preset STYLE and apply it to all frames."
  (interactive
   (list (intern
          (completing-read
           "Glass style: "
           (mapcar (lambda (p) (symbol-name (car p))) macos-glass-presets)
           nil t nil nil (symbol-name macos-glass-style)))))
  (setq macos-glass-style style)
  (let ((parameters (macos-glass--frame-parameters style)))
    (setq default-frame-alist
          (append parameters
                  (seq-remove (lambda (p) (assq (car p) parameters))
                              default-frame-alist)))
    (modify-all-frames-parameters parameters)))

;;;###autoload
(defun macos-glass-enable ()
  "Enable the glass frame and ensure new/daemon frames inherit it."
  (interactive)
  (when (eq system-type 'darwin)
    (dolist (parameter (macos-glass--frame-parameters macos-glass-style))
      (add-to-list 'default-frame-alist parameter))
    (add-hook 'after-make-frame-functions #'macos-glass--apply)
    ;; Non-daemon GUI startup fires neither hook above for the initial frame.
    (if (daemonp)
        nil
      (add-hook 'window-setup-hook #'macos-glass--apply))
    (when (display-graphic-p)
      (macos-glass--apply))))

;; Enable on load when running on macOS.
(when (eq system-type 'darwin)
  (macos-glass-enable))

(provide 'macos-glass)

;;; macos-glass.el ends here
