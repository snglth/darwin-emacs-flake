;;; macos-glass.el --- Ghostty-like macOS glass frame -*- lexical-binding: t; -*-

;; This file enables the liquid-glass frame that the `frame-transparency' and
;; `ns-glass-effect' patches of this flake give (see the README).  Load it
;; from your init file, for example:
;;
;;   (add-to-list 'load-path "/path/to/darwin-emacs-flake/lisp")
;;   (require 'macos-glass)
;;   (macos-glass-set-style 'regular)   ; or 'clear
;;
;; The file has no effect when Emacs does not operate on macOS.  On an Emacs
;; built WITHOUT the glass patches, it uses transparency and background blur.
;; Only the `frame-transparency' patch is necessary for these two effects.
;; `macos-glass--native-build-p' does a probe of the binary that operates, to
;; find this condition.
;;
;; That probe finds the PATCH, not the effect.  An Emacs compiled against the
;; macOS 26 SDK with a macOS 26 deployment target is also necessary for a
;; `NSGlassEffectView' frame.  If one of the two is missing, the patch stays
;; in the build, and it continues to make sure that these parameters are
;; correct.  But it shows `NSVisualEffectView' blur.  Lisp cannot show a
;; difference between the two.  Thus, on such a build, this file selects the
;; glass values and you get blur at an alpha tuned for glass.  See the README.
;; The `emacs' package of the flake builds with the two conditions.

;;; Code:

(defgroup macos-glass nil
  "Ghostty-like macOS glass frame."
  :group 'frames
  :prefix "macos-glass-")

(defcustom macos-glass-style 'regular
  "The active glass preset.  One of the keys in `macos-glass-presets'."
  :type 'symbol
  :group 'macos-glass)

(defcustom macos-glass-transparent-titlebar t
  "Non-nil makes the titlebar transparent (`ns-transparent-titlebar')."
  :type 'boolean
  :group 'macos-glass)

(defcustom macos-glass-alpha-elements '(ns-alpha-all)
  "The frame elements that show with transparency (`ns-alpha-elements').

NOTE: `ns-alpha-glyphs' applies to all glyphs or to no glyph.  The patch
sets the background fill of EVERY glyph to the `alpha-background' of the
frame, and it replaces the alpha of each face.  Thus a change to this list
cannot make the default text transparent and the selection, `region' and
`hl-line' opaque.  These are the two conditions:

  - With `ns-alpha-glyphs', the default text is glassy, but a low
    `alpha-background' also makes the selection almost invisible.
  - Without `ns-alpha-glyphs', the selection is opaque, but ALL text is
    also opaque, because each glyph gets an opaque background box.

To keep the glass effect AND a selection that you can see, keep this value
at `(ns-alpha-all)'.  Then increase `alpha-background' with
`macos-glass-min-readable-alpha'.

These are the available elements: `ns-alpha-all', `ns-alpha-default' (the
background of the default face), `ns-alpha-fringe', `ns-alpha-box',
`ns-alpha-stipple', `ns-alpha-relief', `ns-alpha-glyphs'."
  :type '(repeat symbol)
  :group 'macos-glass)

(defcustom macos-glass-min-readable-alpha 0.12
  "Minimum limit for the `alpha-background' of each preset.

`ns-alpha-glyphs' connects the selection, `region' and `hl-line' to
`alpha-background' (see `macos-glass-alpha-elements').  Thus an alpha near
to zero, such as 0.01, makes these highlights invisible.  An increase to
this limit keeps them legible and translucent.  Set this value to 0.0 to
keep the alpha of the preset, which gives maximum glass and a selection
that is difficult to see."
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
An Emacs built without the glass patches uses the `:fallback-*' values.
Such an Emacs shows transparency and blur, not `NSGlassEffectView' glass.")

(defun macos-glass--preset (style)
  "Return the plist for STYLE.
Signal an error if STYLE is unknown."
  (or (alist-get style macos-glass-presets)
      (user-error "Unknown glass style: %s" style)))

(defvar macos-glass--native-build-cache 'unknown
  "The cached result of `macos-glass--native-build-p'.")

(defun macos-glass--native-build-p ()
  "Return non-nil if the Emacs that operates has the `ns-glass-effect' patch.
This function does a probe when Emacs operates.  The patched C handler
gives an error for an unknown `ns-glass-material' value, but an Emacs
without the patch stores any value and gives no error.  An examination of
the executable file on the disk does not work for each start method.  This
probe works for a direct binary, a daemon and a `-with-packages' wrapper.
A graphic frame is necessary for the probe, and the probe keeps the result
in a cache.

A non-nil result does NOT show that Emacs gives `NSGlassEffectView' glass.
The patch always makes sure that `ns-glass-material' is correct, but it
uses the condition MAC_OS_X_VERSION_MAX_ALLOWED >= 260000 for the
`NSGlassEffectView' code.  That is a constant from the build, and this
probe cannot see it.  See the Commentary."
  (cond
   ;; The probe operated on a graphic frame before this time.
   ((not (eq macos-glass--native-build-cache 'unknown))
    macos-glass--native-build-cache)
   ;; The probe cannot operate at this time, because Emacs is not on darwin,
   ;; or it is a daemon or a TTY with no GUI frame.  Return nil and DO NOT
   ;; keep the result in the cache, thus the first graphic frame does the
   ;; probe again.
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
                      ;; No error shows that Emacs does not have the patch,
                      ;; because it only stored the value.
                      nil)
                  (error t))
              (set-frame-parameter nil 'ns-glass-material saved)))))))

(defun macos-glass--frame-parameters (style)
  "Calculate the frame parameter alist for STYLE.
On a build without glass, this function returns only the transparency
parameters and the blur parameters, with the `:fallback-*' values of the
preset."
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
  "Apply the active glass style to FRAME.
FRAME defaults to the selected frame."
  (with-selected-frame (or frame (selected-frame))
    (pcase-dolist (`(,param . ,value)
                   (macos-glass--frame-parameters macos-glass-style))
      (set-frame-parameter nil param value))))

(defun macos-glass--merge-default-frame-alist (parameters)
  "Install PARAMETERS into `default-frame-alist' and replace the same keys.
`macos-glass-enable' and `macos-glass-set-style' use this function, thus
the two functions install in the same way.  Use this function, not
`add-to-list'.  `add-to-list' puts the new value first, but it keeps an
entry that is already there for the same key.  The `assq' operation finds
the new value, but the old cons stays, and one more cons collects at each
subsequent enable."
  (setq default-frame-alist
        (append parameters
                (seq-remove (lambda (p) (assq (car p) parameters))
                            default-frame-alist))))

;;;###autoload
(defun macos-glass-set-style (style)
  "Change to the glass preset STYLE and apply it to all frames."
  (interactive
   (list (intern
          (completing-read
           "Glass style: "
           (mapcar (lambda (p) (symbol-name (car p))) macos-glass-presets)
           nil t nil nil (symbol-name macos-glass-style)))))
  (setq macos-glass-style style)
  (let ((parameters (macos-glass--frame-parameters style)))
    (macos-glass--merge-default-frame-alist parameters)
    (modify-all-frames-parameters parameters)))

;;;###autoload
(defun macos-glass-enable ()
  "Enable the glass frame.
New frames and daemon frames also get the glass parameters."
  (interactive)
  (when (eq system-type 'darwin)
    (macos-glass--merge-default-frame-alist
     (macos-glass--frame-parameters macos-glass-style))
    (add-hook 'after-make-frame-functions #'macos-glass--apply)
    ;; At a GUI start without a daemon, the first frame does not fire the two
    ;; hooks `after-make-frame-functions' and `window-setup-hook'.
    (if (daemonp)
        nil
      (add-hook 'window-setup-hook #'macos-glass--apply))
    (when (display-graphic-p)
      (macos-glass--apply))))

;; Enable at load time when Emacs operates on macOS.
(when (eq system-type 'darwin)
  (macos-glass-enable))

(provide 'macos-glass)

;;; macos-glass.el ends here
