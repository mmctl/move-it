;;; move-it.el --- Text movement commands -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Matthias Meijers

;; Author: Matthias Meijers <kernel@mmeijers.com>
;; Maintainer: Matthias Meijers <kernel@mmeijers.com>
;; Created: 03 August 2025

;; Keywords: convenience
;; URL: https://github.com/mmctl/move-it

;; This file is not part of GNU Emacs.

;; This file is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation, either version 3 of the License, or (at your option) any later
;; version. This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
;; details. You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; This package provides functionality for conveniently moving around text, akin
;; to the `move-text' (https://github.com/emacsfodder/move-text) and
;; `drag-stuff' (https://github.com/rejeep/drag-stuff.el) packages.
;; Mostly implemented just for fun, and does not necessarily provide
;; much novelty compared to the above-mentioned packages (besides perhaps
;; some customization concerning the default behavior).

;;; Code:

;; Customization
(defgroup move-it nil
  "Customization group for `move-it'."
  :prefix "move-it-")

(defcustom move-it-maintain-region-start-column t
  "Maintain original starting column of region in consecutive calls to vertical
movement commands. That is, when non-nil, repeated calls to `move-it-up' and
`move-it-down' (with a selected region) will try to insert the region in the
same column as it was before the first call to these commands (so the region
will be inserted as close to its original column as possible, even when you have
moved through lines with insufficient columns). When nil, inserts region as
close as possible to column it is currently in (i.e., considers the column
before current call to command, and not the column before the first call in the
chain)."
  :type 'boolean
  :group 'move-it)

(defcustom move-it-multi-line-region-whole-lines t
  "Move whole lines whenever issuing movement commands with a region spanning
multiple lines. Currently only affects vertical movement commands."
  :type 'boolean
  :group 'move-it)


;; Internals
(defvar-local move-it--region-start-column 0)

(defun move-it--region-vertically (start end &optional arg)
  "Moves region defined by START and END lines up or down, depending on ARG
(defaults to 1 line down). With ARG, moves |ARG| lines down (up if ARG is
negative). Maintains relative position of point and mark."
  (let ((arg (or arg 1))
        (lnstart (line-number-at-pos start))
        (lnend (line-number-at-pos end)))
    (when (and (< arg 0) (<= lnstart 1))
      (user-error "Start of region on first line of buffer, cannot move up"))
    (when (and (< 0 arg) (<= (1- (line-number-at-pos (point-max))) lnend))
      (user-error "End of region on last line of buffer, cannot move down"))
    (unless (and move-it-maintain-region-start-column
                 (memq last-command '(move-it-up move-it-down)))
      (setq-local move-it--region-start-column (save-excursion
                                                 (goto-char start)
                                                 (current-column))))
    (let* ((ltmp (< (mark) (point)))
           (content (delete-and-extract-region start end)))
      (forward-line arg)
      (move-to-column move-it--region-start-column)
      (save-excursion
        (insert content)
        (set-mark (point)))
      (when ltmp
        (exchange-point-and-mark))
      (setq deactivate-mark nil))))

(defun move-it--region-horizontally (start end &optional arg)
  "Moves region defined by START and END characters left or right, depending on
ARG (defaults to 1 character right). With ARG, moves |ARG| characters right
(left if ARG is negative). Maintains relative position of point and mark."
  (let ((arg (or arg 1)))
    (when (and (< arg 0) (= start (point-min)))
      (user-error "Start of region at beginning of buffer, cannot move left"))
    (when (and (< 0 arg) (= end (point-max)))
      (user-error "End of region at end of buffer, cannot move right"))
    (let* ((ltmp (< (mark) (point)))
           (content (delete-and-extract-region start end)))
      (forward-char arg)
      (save-excursion
        (insert content)
        (set-mark (point)))
      (when ltmp
        (exchange-point-and-mark))
      (setq deactivate-mark nil))))

(defun move-it--wholeline-region-vertically (start end &optional arg)
  "Moves whole lines in region defined by START and END lines up or down,
depending on ARG (defaults to 1 line down). With ARG, moves |ARG| lines down (up
if ARG is negative). Maintains relative position of point and mark."
  (let ((arg (or arg 1))
        (down (< 0 arg))
        (lnstart (line-number-at-pos start))
        (lnend (line-number-at-pos end)))
    (when (and (< arg 0) (<= lnstart 1))
      (user-error "Start of region on first line of buffer, cannot move up"))
    (when (and down (<= (1- (line-number-at-pos (point-max))) lnend))
      (user-error "End of region on last line of buffer, cannot move down"))
    (let* ((ltmp (< (mark) (point)))
           (origstart start)
           (origend end)
           (start (save-excursion
                    (goto-char origstart)
                    (line-beginning-position)))
           (end (save-excursion
                  (goto-char origend)
                  (end-of-line)
                  (if (looking-at-p "\n") (1+ (point)) (point))))
           (rtob (- origstart start))
           (rtoe (- end origend))
           (content (delete-and-extract-region start end)))
      (forward-line arg)
      (save-excursion
        (insert content)
        (set-mark (- (point) rtoe)))
      (forward-char rtob)
      (when ltmp
        (exchange-point-and-mark))
      (setq deactivate-mark nil))))

(defun move-it--wholeline-region-horizontally (start end &optional arg)
  "Moves whole lines in region defined by START and END characters left or
right, depending on ARG (defaults to 1 character right). With ARG, moves |ARG|
characters right (left if ARG is negative). This is mostly equivalent to
`indent-rigidly', which see, but includes all lines with content in region, not
only those that start in region."
  (let* ((start (save-excursion
                  (goto-char start)
                  (line-beginning-position))))
    (indent-rigidly start end (or arg 1))
    (setq deactivate-mark nil)))

(defun move-it--line-vertically (&optional arg)
  "Moves line at point up or down, depending on ARG (defaults to 1 line down).
With ARG, moves |ARG| lines down (up if ARG is negative)."
  (let ((arg (or arg 1))
        (ln (line-number-at-pos)))
    (when (and (< arg 0) (<= ln 1))
      (user-error "On first line of buffer, cannot move up"))
    (when (and (< 0 arg) (<= (1- (line-number-at-pos (point-max))) ln))
      (user-error "On last line of buffer, cannot move down"))
    (pcase-let* ((col (current-column))
                 (`(,beg . ,end) (bounds-of-thing-at-point 'line))
                 (line (delete-and-extract-region beg end)))
      (forward-line arg)
      (save-excursion (insert line))
      (move-to-column col))))

(defun move-it--line-horizontally (&optional arg)
  "Moves line at point left or right, depending on ARG (defaults to 1 character
right). With ARG, moves |ARG| characters right (left if ARG is negative). This
is essentially equivalent to performing `indent-rigidly' on the current line,
but inserts/deletes whitespace before point when on an empty line."
  (pcase-let ((`(,beg . ,end) (bounds-of-thing-at-point 'line)))
    (if (string-empty-p (string-trim (buffer-substring-no-properties beg end)))
        (if (<= 0 arg)
            (insert (make-string arg ?\s))
          (delete-region (max beg (- (point) (abs arg))) (point)))
      (indent-rigidly beg end (or arg 1)))))


;; Region-based commands
(defun move-it-region-up (start end &optional arg)
  "Moves region defined by START and END 1 line up. With ARG, moves |ARG| lines
up instead (down if ARG is negative). If `move-it-multi-line-region-whole-lines'
is non-nil, moves lines (with content) in region as a whole whenever the region
spans multiple lines."
  (interactive "r\np")
  (if (or move-it-multi-line-region-whole-lines
          (= (line-number-at-pos start) (line-number-at-pos end)))
      (move-it--region-vertically start end (- arg))
    (move-it--wholeline-region-vertically start end (- arg))))

(defun move-it-region-down (start end &optional arg)
  "Moves region defined by START and END 1 line down. With ARG, moves |ARG|
lines down (up if ARG is negative). If `move-it-multi-line-region-whole-lines'
is non-nil, moves lines (with content) in region as a whole whenever the region
spans multiple lines."
  (interactive "r\np")
  (if (or move-it-multi-line-region-whole-lines
          (= (line-number-at-pos start) (line-number-at-pos end)))
      (move-it--region-vertically start end arg)
    (move-it--wholeline-region-vertically start end arg)))

(defun move-it-region-left (start end &optional arg)
  "Moves region defined by START and END 1 character left. With ARG, moves |ARG|
lines up instead (down if ARG is negative). Moves lines (with content) in region
as a whole whenever the region spans multiple lines."
  (interactive "r\np")
  (if (= (line-number-at-pos start) (line-number-at-pos end))
      (move-it--region-horizontally start end (- arg))
    (move-it--wholeline-region-horizontally start end (- arg))))

(defun move-it-region-right (start end &optional arg)
  "Moves region defined by START and END one character right. With ARG, moves
|ARG| lines down (up if ARG is negative). Moves lines (with content) in region
as a whole whenever the region spans multiple lines."
  (interactive "r\np")
  (if (= (line-number-at-pos start) (line-number-at-pos end))
      (move-it--region-horizontally start end arg)
    (move-it--wholeline-region-horizontally start end arg)))

;; Line-based commands
(defun move-it-line-up (&optional arg)
  "Moves line at point |ARG| lines up (down if ARG is negative). Defaults to
1 line up."
  (interactive "p")
  (move-it--line-vertically (- arg)))

(defun move-it-line-down (&optional arg)
  "Moves line at point |ARG| lines down (up if ARG is negative). Defaults to
1 line down."
  (interactive "p")
  (move-it--line-vertically arg))

(defun move-it-line-left (&optional arg)
  "Moves line at point |ARG| characters left (right if ARG is negative).
Defaults to 1 character left."
  (interactive "p")
  (move-it--line-horizontally (- arg)))

(defun move-it-line-right (&optional arg)
  "Moves line at point |ARG| characters right (left if ARG is negative).
Defaults to 1 character right."
  (interactive "p")
  (move-it--line-horizontally arg))


;; Main commands (region + line combined)
(defun move-it-up (&optional arg)
  "If region is active, moves region or whole lines in region |ARG| lines up
(down if ARG is negative). If region is not active, moves line at point
|ARG| lines up (down if ARG is negative). Defaults to 1 line up."
  (interactive "p")
  (if (use-region-p)
      (move-it-region-up (region-beginning) (region-end) arg)
    (move-it-line-up arg)))

(defun move-it-down (&optional arg)
  "If region is active, moves region or whole lines in region |ARG| lines down
(up if ARG is negative). If region is not active, moves line at point |ARG|
lines down (up if ARG is negative). Defaults to 1 line down."
  (interactive "p")
  (if (use-region-p)
      (move-it-region-down (region-beginning) (region-end) arg)
    (move-it-line-down arg)))

(defun move-it-left (&optional arg)
  "If region is active, moves region or whole  lines in region |ARG| characters
left (right if ARG is negative). If region is not active, moves line
at point |ARG| characters left (right if ARG is negative).
Defaults to 1 character left."
  (interactive "p")
  (if (use-region-p)
      (move-it-region-left (region-beginning) (region-end) arg)
    (move-it-line-left arg)))

(defun move-it-right (&optional arg)
  "If region is active, moves region or whole lines in region |ARG| characters
right (left if ARG is negative). If region is not active, moves line
at point |ARG| characters right (left if ARG is negative).
Defaults to 1 character right."
  (interactive "p")
  (if (use-region-p)
      (move-it-region-right (region-beginning) (region-end) arg)
    (move-it-line-right arg)))


(provide 'move-it)

;;; move-it.el ends here
