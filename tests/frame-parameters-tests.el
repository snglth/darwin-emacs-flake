;;; frame-parameters-tests.el --- Frame parameter regression tests -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest frame-parameters-geometry ()
  (dolist (parameter '(width height))
    (let ((value (frame-parameter nil parameter)))
      (should (integerp value))
      (should (> value 0)))))

(ert-deftest frame-parameters-ns-round-trip ()
  (skip-unless (eq system-type 'darwin))
  ;; Use a batch frame so the test does not need a window server.
  (should noninteractive)
  (dolist (entry '((undecorated-round . t)
                   (ns-background-blur . 0)
                   (ns-alpha-elements . (ns-alpha-all))
                   (ns-glass-material . regular)
                   (ns-glass-tint-opacity . 0.05)
                   (ns-glass-saturation . 1.4)
                   (ns-glass-inactive-opacity . 0.05)
                   (ns-glass-corner-radius . 2)))
    (let* ((parameter (car entry))
           (value (cdr entry))
           (saved (frame-parameter nil parameter)))
      (unwind-protect
          (progn
            (set-frame-parameter nil parameter value)
            (should (equal (frame-parameter nil parameter) value)))
        (set-frame-parameter nil parameter saved)))))

;;; frame-parameters-tests.el ends here
