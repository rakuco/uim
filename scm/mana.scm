;;; mana.scm: mana for uim.
;;; charset: EUC-JP
;;;
;;; Copyright (c) 2003-2006 uim Project http://uim.freedesktop.org/
;;;
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;; 1. Redistributions of source code must retain the above copyright
;;;    notice, this list of conditions and the following disclaimer.
;;; 2. Redistributions in binary form must reproduce the above copyright
;;;    notice, this list of conditions and the following disclaimer in the
;;;    documentation and/or other materials provided with the distribution.
;;; 3. Neither the name of authors nor the names of its contributors
;;;    may be used to endorse or promote products derived from this software
;;;    without specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' AND
;;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE
;;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
;;; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;;; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
;;; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.
;;;;

(require "util.scm")
(require "ustr.scm")
(require "japanese.scm")
(require "japanese-kana.scm")
(require "japanese-azik.scm")
(require-custom "generic-key-custom.scm")
(require-custom "mana-custom.scm")
(require-custom "mana-key-custom.scm")


;;; implementations

(define mana-segment-rec-spec
  (list
    (list 'first-candidate  #f)
    (list 'pos               0)
    (list 'len               0)
    (list 'state             0)
    (list 'candidate-list  '())
    (list 'candidate-pos     0)
    (list 'nr-candidates     0)))

(define-record 'mana-segment mana-segment-rec-spec)
(define mana-segment-new-internal mana-segment-new)

(define mana-segment-new
  (lambda (first-candidate pos len state cost)
    (mana-segment-new-internal first-candidate pos len state)))


(define mana-best-path
  (lambda (yomi state pos len)
    (mana-eval (list 'mana-best-path yomi state pos len))))

(define mana-list-candidates
  (lambda (yomi state pos mrph-len len)
    (mana-eval (list 'mana-list-candidates yomi state pos mrph-len len))))

(define mana-add-new-word
  (lambda (kaki yomi)
    (mana-eval (list 'mana-add-new-word kaki yomi))))

(define mana-eval
  (lambda (val)
    (mana-lib-eval (mana-list->string val))))

(define mana-list->string
  (lambda (lst)
    (let ((canonicalized (map (lambda (elem)
                                (cond
                                  ((symbol? elem)
                                   (symbol->string elem))
                                  ((string? elem)
                                   (string-escape elem))
                                  ((number? elem)
                                   (number->string elem))
                                  (else
                                    "")))
                              lst)))
      (string-append "(" (string-join " " canonicalized) ")\n"))))

(define mana-set-string!
  (lambda (mc yomi yomi-len)
    (let ((best-path (mana-best-path yomi 0 0 yomi-len)))
      (if (not best-path)
          #f
          (let ((nr-segments (length best-path))
                (segment-list (mana-make-segment-list best-path)))
            (mana-context-set-yomi! mc yomi)
            (mana-context-set-yomi-len! mc yomi-len)
            (mana-context-set-nr-segments! mc nr-segments)
            (mana-context-set-segment-list! mc segment-list)
            #t)))))

(define mana-make-segment-list
  (lambda (best-path)
    (map
      (lambda (segment)
        (apply mana-segment-new segment))
      best-path)))

(define mana-get-nth-candidate
  (lambda (mc seg-idx cand-idx)
    (let* ((segment-list (mana-context-segment-list mc))
           (segment (list-ref segment-list seg-idx)))
      (if (= cand-idx 0)
          (mana-segment-first-candidate segment)
          (begin
            (if (null? (mana-segment-candidate-list segment))
                (mana-set-candidate-list! mc seg-idx))
            (list-ref (mana-segment-candidate-list segment)
                      cand-idx))))))

(define mana-get-nr-candidates
  (lambda (mc seg-idx)
    (let* ((segment-list (mana-context-segment-list mc))
           (segment (list-ref segment-list seg-idx)))
      (if (not (mana-segment-candidate-list segment))
          (mana-set-candidate-list! mc seg-idx))
      (mana-segment-nr-candidates segment))))

(define mana-uniq
  (lambda (lst)
    (reverse (fold
               (lambda (x xs)
                 (if (member x xs)
                     xs
                     (cons x xs)))
               '() lst))))

(define mana-set-candidate-list!
  (lambda (mc seg-idx)
    (let* ((segment-list (mana-context-segment-list mc))
           (segment (list-ref segment-list seg-idx))
           (yomi (mana-context-yomi mc))
           (state
             (if (= seg-idx 0)
                 0
                 (mana-segment-state
                   (list-ref segment-list (- seg-idx 1)))))
           (pos  (mana-segment-pos segment))
           (len  (mana-segment-len segment))
           (first-candidate (mana-segment-first-candidate segment))
           (uniq-candidate-list
             (mana-uniq
               (cons
                 first-candidate
                 (map car (mana-list-candidates yomi state pos len len))))))
      (mana-segment-set-candidate-list!
        segment uniq-candidate-list)
      (mana-segment-set-nr-candidates!
        segment (length uniq-candidate-list)))))

(define mana-resize-specified-segment
  (lambda (mc seg-idx cnt)
    (let* ((yomi (mana-context-yomi mc))
           (segment-list (mana-context-segment-list mc))
           (segment (list-ref segment-list seg-idx))
           (state (mana-segment-state segment))
           (len (mana-segment-len segment))
           (new-len (+ len cnt))
           (pos (mana-segment-pos segment))
           (next-segment-pos (+ pos new-len))
           (end-of-yomi (- (mana-context-yomi-len mc) next-segment-pos)))
      (if (and (> new-len 0)
               (>= end-of-yomi 0))
          (let* ((cand-state-list (mana-list-candidates yomi state pos new-len new-len))
                 (first-candidate (caar cand-state-list))
                 (next-state (car (cdar cand-state-list)))
                 (best-path (mana-best-path yomi next-state next-segment-pos end-of-yomi))
                 (uniq-candidate-list (mana-uniq (map car cand-state-list))))
            (mana-segment-set-len! segment new-len)
            (mana-segment-set-first-candidate! segment first-candidate)
            (mana-segment-set-candidate-list! segment uniq-candidate-list)
            (mana-segment-set-nr-candidates! segment (length uniq-candidate-list))
            (mana-context-set-nr-segments! mc (+ seg-idx 1 (length best-path)))
            (set-cdr! (list-tail segment-list seg-idx)
                      (mana-make-segment-list best-path)))))))



(define mana-lib-initialized? #f)

(define mana-type-hiragana   0)
(define mana-type-katakana   1)
(define mana-type-hankana    2)
(define mana-type-latin      3)
(define mana-type-wide-latin 4)

(define mana-input-rule-roma 0)
(define mana-input-rule-kana 1)
(define mana-input-rule-azik 2)

(define mana-prepare-activation
  (lambda (mc)
    (mana-flush mc)
    (mana-update-preedit mc)))

(register-action 'action_mana_hiragana
                 ;;              (indication-alist-indicator 'action_mana_hiragana
                 ;;                                          mana-input-mode-indication-alist)
                 (lambda (mc) ;; indication handler
                   '(figure_ja_hiragana
                      "あ"
                      "ひらがな"
                      "ひらがな入力モード"))

                 (lambda (mc) ;; activity predicate
                   (and (mana-context-on mc)
                        (= (mana-context-kana-mode mc)
                           mana-type-hiragana)))

                 (lambda (mc) ;; action handler
                   (mana-prepare-activation mc)
                   (mana-context-set-on! mc #t)
                   (mana-context-change-kana-mode! mc mana-type-hiragana)))

(register-action 'action_mana_katakana
                 ;;              (indication-alist-indicator 'action_mana_katakana
                 ;;                                          mana-input-mode-indication-alist)
                 (lambda (mc)
                   '(figure_ja_katakana
                      "ア"
                      "カタカナ"
                      "カタカナ入力モード"))
                 (lambda (mc)
                   (and (mana-context-on mc)
                        (= (mana-context-kana-mode mc)
                           mana-type-katakana)))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (mana-context-set-on! mc #t)
                   (mana-context-change-kana-mode! mc mana-type-katakana)))

(register-action 'action_mana_hankana
                 ;;              (indication-alist-indicator 'action_mana_hankana
                 ;;                                          mana-input-mode-indication-alist)
                 (lambda (mc)
                   '(figure_ja_hankana
                      "ｱ"
                      "半角カタカナ"
                      "半角カタカナ入力モード"))
                 (lambda (mc)
                   (and (mana-context-on mc)
                        (= (mana-context-kana-mode mc)
                           mana-type-hankana)))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (mana-context-set-on! mc #t)
                   (mana-context-change-kana-mode! mc mana-type-hankana)))

(register-action 'action_mana_direct
                 ;;              (indication-alist-indicator 'action_mana_direct
                 ;;                                          mana-input-mode-indication-alist)
                 (lambda (mc)
                   '(figure_ja_direct
                      "a"
                      "直接入力"
                      "直接(無変換)入力モード"))
                 (lambda (mc)
                   (and (not (mana-context-on mc))
                        (not (mana-context-wide-latin mc))))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (mana-context-set-on! mc #f)
                   (mana-context-set-wide-latin! mc #f)))

(register-action 'action_mana_zenkaku
                 ;;              (indication-alist-indicator 'action_mana_zenkaku
                 ;;                                          mana-input-mode-indication-alist)
                 (lambda (mc)
                   '(figure_ja_zenkaku
                      "Ａ"
                      "全角英数"
                      "全角英数入力モード"))
                 (lambda (mc)
                   (and (not (mana-context-on mc))
                        (mana-context-wide-latin mc)))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (mana-context-set-on! mc #f)
                   (mana-context-set-wide-latin! mc #t)))

(register-action 'action_mana_roma
                 ;;              (indication-alist-indicator 'action_mana_roma
                 ;;                                          mana-kana-input-method-indication-alist)
                 (lambda (mc)
                   '(figure_ja_roma
                      "Ｒ"
                      "ローマ字"
                      "ローマ字入力モード"))
                 (lambda (mc)
                   (= (mana-context-input-rule mc)
                      mana-input-rule-roma))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (rk-context-set-rule! (mana-context-rkc mc)
                                         ja-rk-rule)
                   (mana-context-set-input-rule! mc mana-input-rule-roma)))

(register-action 'action_mana_kana
                 ;;              (indication-alist-indicator 'action_mana_kana
                 ;;                                          mana-kana-input-method-indication-alist)
                 (lambda (mc)
                   '(figure_ja_kana
                      "か"
                      "かな"
                      "かな入力モード"))
                 (lambda (mc)
                   (= (mana-context-input-rule mc)
                      mana-input-rule-kana))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (mana-context-set-input-rule! mc mana-input-rule-kana)
                   (mana-context-change-kana-mode! mc (mana-context-kana-mode mc))
                   ;;(define-key mana-kana-toggle-key? "")
                   ;;(define-key mana-latin-key? generic-on-key?)
                   ;;(define-key mana-wide-latin-key? "")
                   ))

(register-action 'action_mana_azik
                 ;;              (indication-alist-indicator 'action_mana_azik
                 ;;                                          mana-kana-input-method-indication-alist)
                 (lambda (mc)
                   '(figure_ja_azik
                      "Ａ"
                      "AZIK"
                      "AZIK拡張ローマ字入力モード"))
                 (lambda (mc)
                   (= (mana-context-input-rule mc)
                      mana-input-rule-azik))
                 (lambda (mc)
                   (mana-prepare-activation mc)
                   (rk-context-set-rule! (mana-context-rkc mc)
                                         ja-azik-rule)
                   (mana-context-set-input-rule! mc mana-input-rule-azik)))

;; Update widget definitions based on action configurations. The
;; procedure is needed for on-the-fly reconfiguration involving the
;; custom API
(define mana-configure-widgets
  (lambda ()
    (register-widget 'widget_mana_input_mode
                     (activity-indicator-new mana-input-mode-actions)
                     (actions-new mana-input-mode-actions))

    (register-widget 'widget_mana_kana_input_method
                     (activity-indicator-new mana-kana-input-method-actions)
                     (actions-new mana-kana-input-method-actions))
    (context-list-replace-widgets! 'mana mana-widgets)))

(define mana-context-rec-spec
  (append
    context-rec-spec
    (list
      (list 'on                 #f)
      (list 'converting         #f)
      (list 'transposing        #f)
      (list 'transposing-type    0)
      (list 'nr-segments         0)
      (list 'segment-list      '())
      (list 'yomi               #f)
      (list 'yomi-len            0)
      (list 'preconv-ustr       #f) ;; preedit strings
      (list 'rkc                #f)
      (list 'segments           #f) ;; ustr of candidate indices
      (list 'candidate-window   #f)
      (list 'candidate-op-count 0)
      (list 'wide-latin         #f)
      (list 'kana-mode          mana-type-hiragana)
      (list 'commit-raw         #t)
      (list 'input-rule         mana-input-rule-roma)
      (list 'raw-ustr           #f))))
(define-record 'mana-context mana-context-rec-spec)
(define mana-context-new-internal mana-context-new)

(define mana-context-new
  (lambda (id im)
    (let ((mc (mana-context-new-internal id im))
          (rkc (rk-context-new ja-rk-rule #t #f)))
      (if (not mana-lib-initialized?)
          (set! mana-lib-initialized? (mana-lib-init)))
      (mana-context-set-widgets! mc mana-widgets)
      (mana-context-set-rkc! mc rkc)
      (mana-context-set-preconv-ustr! mc (ustr-new))
      (mana-context-set-raw-ustr! mc (ustr-new))
      (mana-context-set-segments! mc (ustr-new))

      ;; 2004-08-26 Takuro Ashie <ashie@homa.ne.jp>
      ;;   * I think load-kana-table should be marked as depracated.
      ;;     Because it is a little violent (it overwrites ja-rk-rule table).
      ;;     We should prepare a custom entry like "uim-default-input-rule"
      ;;     instead of using-kana-table.
      (if using-kana-table?
          (mana-context-set-input-rule! mc mana-input-rule-kana)
          (mana-context-set-input-rule! mc mana-input-rule-roma))
      mc)))

(define mana-commit-raw
  (lambda (mc)
    (im-commit-raw mc)
    (mana-context-set-commit-raw! mc #t)))

(define mana-context-kana-toggle
  (lambda (mc)
    (let* ((kana (mana-context-kana-mode mc))
           (opposite-kana (multi-segment-opposite-kana kana)))
      (mana-context-change-kana-mode! mc opposite-kana))))

(define mana-context-change-kana-mode!
  (lambda (mc kana-mode)
    (if (= (mana-context-input-rule mc)
           mana-input-rule-kana)
        (rk-context-set-rule!
          (mana-context-rkc mc)
          (cond
            ((= kana-mode mana-type-hiragana) ja-kana-hiragana-rule)
            ((= kana-mode mana-type-katakana) ja-kana-katakana-rule)
            ((= kana-mode mana-type-hankana)  ja-kana-hankana-rule))))
    (mana-context-set-kana-mode! mc kana-mode)))

;; TODO: generarize as multi-segment procedure
;; side effect: none. rkc will not be altered
(define mana-make-whole-string
  (lambda (mc convert-pending-into-kana? kana)
    (let* ((rkc (mana-context-rkc mc))
           (pending (rk-pending rkc))
           (residual-kana (rk-peek-terminal-match rkc))
           (rule (mana-context-input-rule mc))
           (preconv-str (mana-context-preconv-ustr mc))
           (extract-kana
             (if (= rule mana-input-rule-kana)
                 (lambda (entry) (car entry))
                 (lambda (entry) (list-ref entry kana)))))

      (string-append
        (string-append-map-ustr-former extract-kana preconv-str)
        (if convert-pending-into-kana?
            (if residual-kana
                (extract-kana residual-kana)
                (if (= rule mana-input-rule-kana)
                    pending
                    ""))
            pending)
        (string-append-map-ustr-latter extract-kana preconv-str)))))

(define mana-make-raw-string
  (lambda (raw-str-list wide?)
    (if (not (null? raw-str-list))
        (if wide?
            (string-append
              (ja-string-list-to-wide-alphabet (string-to-list (car raw-str-list)))
              (mana-make-raw-string (cdr raw-str-list) wide?))
            (string-append
              (car raw-str-list)
              (mana-make-raw-string (cdr raw-str-list) wide?)))
        "")))

(define mana-make-whole-raw-string
  (lambda (mc wide?)
    (let* ((rkc (mana-context-rkc mc))
           (pending (rk-pending rkc))
           (residual-kana (rk-push-key-last! rkc))
           (raw-str (mana-context-raw-ustr mc))
           (right-str (ustr-latter-seq raw-str))
           (left-str (ustr-former-seq raw-str)))
      (mana-make-raw-string
        (ja-raw-string-list-to-valid-roma
          (append left-str
                  (if (null? residual-kana)
                      (begin
                        (if (null? right-str)
                            (list pending)
                            (append right-str (list pending))))
                      (begin
                        (rk-flush rkc)
                        (if (null? right-str)
                            (list pending)
                            (append right-str (list pending)))))))
        wide?))))

(define mana-init-handler
  (lambda (id im arg)
    (mana-context-new id im)))

(define mana-release-handler
  (lambda (mc)
    '()))

(define mana-flush
  (lambda (mc)
    (rk-flush (mana-context-rkc mc))
    (ustr-clear! (mana-context-preconv-ustr mc))
    (ustr-clear! (mana-context-raw-ustr mc))
    (ustr-clear! (mana-context-segments mc))
    (mana-context-set-transposing! mc #f)
    (mana-context-set-converting! mc #f)
    (mana-context-set-nr-segments! mc 0)
    (mana-context-set-segment-list! mc '())
    (mana-context-set-yomi! mc #f)
    (mana-context-set-yomi-len! mc 0)
    (if (mana-context-candidate-window mc)
        (im-deactivate-candidate-selector mc))
    (mana-context-set-candidate-window! mc #f)
    (mana-context-set-candidate-op-count! mc 0)))

(define mana-begin-input
  (lambda (mc)
    (mana-context-set-on! mc #t)
    (rk-flush (mana-context-rkc mc))
    (mana-context-set-converting! mc #f)))

(define mana-update-preedit
  (lambda (mc)
    (if (not (mana-context-commit-raw mc))
        (let ((segments (if (mana-context-on mc)
                            (if (mana-context-transposing mc)
                                (mana-context-transposing-state-preedit mc)
                                (if (mana-context-converting mc)
                                    (mana-converting-state-preedit mc)
                                    (mana-input-state-preedit mc)))
                            ())))
          (context-update-preedit mc segments))
        (mana-context-set-commit-raw! mc #f))))

(define mana-proc-raw-state
  (lambda (mc key key-state)
    (if (mana-on-key? key key-state)
        (mana-begin-input mc)
        (mana-commit-raw mc))))

(define mana-begin-conv
  (lambda (mc)
    (let* (
           (kana (mana-context-kana-mode mc))
           (preconv-str (mana-make-whole-string mc #t mana-type-hiragana))
           (yomi-len (mana-lib-eucjp-string-length preconv-str)))
      (if (and mana-lib-initialized?
               (> (string-length preconv-str)
                  0))
          (if (mana-set-string! mc preconv-str yomi-len)
              (let ((nr-segments (mana-context-nr-segments mc)))
                (ustr-set-latter-seq! (mana-context-segments mc)
                                      (make-list nr-segments 0))
                (mana-context-set-converting! mc #t)
                ;; Don't perform rk-flush here. The rkc must be restored when
                ;; mana-cancel-conv invoked -- YamaKen 2004-10-25
                ))))))

(define mana-cancel-conv
  (lambda (mc)
    (mana-reset-candidate-window mc)
    (mana-context-set-converting! mc #f)
    (mana-context-set-nr-segments! mc 0)
    (mana-context-set-segment-list! mc '())
    (mana-context-set-yomi! mc #f)
    (mana-context-set-yomi-len! mc 0)
    (ustr-clear! (mana-context-segments mc))))

(define mana-proc-input-state-no-preedit
  (lambda (mc key key-state)
    (let ((rkc (mana-context-rkc mc))
          (direct (ja-direct (charcode->string key)))
          (rule (mana-context-input-rule mc)))
      (cond
        ((and mana-use-with-vi?
              (mana-vi-escape-key? key key-state))
         (begin
           (mana-flush mc)
           (mana-context-set-on! mc #f)
           (mana-context-set-wide-latin! mc #f)
           (mana-commit-raw mc)))

        ((mana-wide-latin-key? key key-state)
         (begin
           (mana-flush mc)
           (mana-context-set-on! mc #f)
           (mana-context-set-wide-latin! mc #t)))

        ((mana-latin-key? key key-state)
         (begin
           (mana-flush mc)
           (mana-context-set-on! mc #f)
           (mana-context-set-wide-latin! mc #f)))

        ((mana-backspace-key? key key-state)
         (mana-commit-raw mc))

        ((mana-delete-key? key key-state)
         (mana-commit-raw mc))

        ((mana-hankaku-kana-key? key key-state)
         (mana-context-change-kana-mode! mc mana-type-hankana))

        ((mana-kana-toggle-key? key key-state)
         (mana-context-kana-toggle mc))

        ;; modifiers (except shift) => ignore
        ((and (modifier-key-mask key-state)
              (not (shift-key-mask key-state)))
         (mana-commit-raw mc))

        ;; direct key => commit
        (direct
          (im-commit mc direct))

        ((symbol? key)
         (mana-commit-raw mc))

        (else
          (let* ((key-str (charcode->string
                            (if (= rule mana-input-rule-kana)
                                key
                                (to-lower-char key))))
                 (res (rk-push-key! rkc key-str)))
            (if res
                (begin
                  (ustr-insert-elem! (mana-context-preconv-ustr mc)
                                     res)
                  (ustr-insert-elem! (mana-context-raw-ustr mc)
                                     key-str))
                (if (not (rk-pending rkc))
                    (mana-commit-raw mc)))))))))

(define mana-has-preedit?
  (lambda (mc)
    (or (not (ustr-empty? (mana-context-preconv-ustr mc)))
        (> (string-length (rk-pending (mana-context-rkc mc))) 0))))

(define mana-proc-transposing-state
  (lambda (mc key key-state)
    (cond
      ((mana-transpose-as-hiragana-key? key key-state)
       (mana-context-set-transposing-type! mc mana-type-hiragana))

      ((mana-transpose-as-katakana-key? key key-state)
       (mana-context-set-transposing-type! mc mana-type-katakana))

      ((mana-transpose-as-hankana-key? key key-state)
       (mana-context-set-transposing-type! mc mana-type-hankana))

      ((mana-transpose-as-latin-key? key key-state)
       (if (not (= (mana-context-input-rule mc)
                   mana-input-rule-kana))
           (mana-context-set-transposing-type! mc mana-type-latin)))

      ((mana-transpose-as-wide-latin-key? key key-state)
       (if (not (= (mana-context-input-rule mc)
                   mana-input-rule-kana))
           (mana-context-set-transposing-type! mc mana-type-wide-latin)))

      (else
        (begin
          ; commit
          (im-commit mc (mana-transposing-text mc))
          (mana-flush mc)
          (if (not (mana-commit-key? key key-state))
              (begin 
                (mana-context-set-transposing! mc #f)
                (mana-proc-input-state mc key key-state)
                (mana-context-set-commit-raw! mc #f))))))))

(define mana-proc-input-state-with-preedit
  (lambda (mc key key-state)
    (let ((preconv-str (mana-context-preconv-ustr mc))
          (raw-str (mana-context-raw-ustr mc))
          (rkc (mana-context-rkc mc))
          (kana (mana-context-kana-mode mc))
          (rule (mana-context-input-rule mc)))
      (cond

        ;; begin conversion
        ((mana-begin-conv-key? key key-state)
         (mana-begin-conv mc))

        ;; backspace
        ((mana-backspace-key? key key-state)
         (if (not (rk-backspace rkc))
             (begin
               (ustr-cursor-delete-backside! preconv-str)
               (ustr-cursor-delete-backside! raw-str))))

        ;; delete
        ((mana-delete-key? key key-state)
         (if (not (rk-delete rkc))
             (begin
               (ustr-cursor-delete-frontside! preconv-str)
               (ustr-cursor-delete-frontside! raw-str))))

        ;; kill
        ((mana-kill-key? key key-state)
         (ustr-clear-latter! preconv-str))

        ;; kill-backward
        ((mana-kill-backward-key? key key-state)
         (begin
           (rk-flush rkc)
           (ustr-clear-former! preconv-str)))

        ;; 現在とは逆のかなモードでかなを確定する
        ((mana-commit-as-opposite-kana-key? key key-state)
         (begin
           (im-commit
             mc
             (mana-make-whole-string mc #t (multi-segment-opposite-kana kana)))
           (mana-flush mc)))

        ;; Transposing状態へ移行
        ((or (mana-transpose-as-hiragana-key?   key key-state)
             (mana-transpose-as-katakana-key?   key key-state)
             (mana-transpose-as-hankana-key?    key key-state)
             (mana-transpose-as-latin-key?      key key-state)
             (mana-transpose-as-wide-latin-key? key key-state))
         (begin
           (mana-context-set-transposing! mc #t)
           (mana-proc-transposing-state mc key key-state)))

        ;; Commit current preedit string, then toggle hiragana/katakana mode.
        ((mana-kana-toggle-key? key key-state)
         (begin
           (im-commit
             mc
             (mana-make-whole-string mc #t kana))
           (mana-flush mc)
           (mana-context-kana-toggle mc)))

        ;; cancel
        ((mana-cancel-key? key key-state)
         (mana-flush mc))

        ;; commit
        ((mana-commit-key? key key-state)
         (begin
           (im-commit
             mc
             (mana-make-whole-string mc #t kana))
           (mana-flush mc)))

        ;; left
        ;; 2004-08-27 Takuro Ashie <ashie@homa.ne.jp>
        ;;   * We should restore pending state of rk-context when the input-rule
        ;;     is kana mode.
        ((mana-go-left-key? key key-state)
         (mana-context-confirm-kana! mc)
         (ustr-cursor-move-backward! preconv-str)
         (ustr-cursor-move-backward! raw-str))

        ;; right
        ;; 2004-08-27 Takuro Ashie <ashie@homa.ne.jp>
        ;;   * We should restore pending state of rk-context when the input-rule
        ;;     is kana mode.
        ((mana-go-right-key? key key-state)
         (mana-context-confirm-kana! mc)
         (ustr-cursor-move-forward! preconv-str)
         (ustr-cursor-move-forward! raw-str))

        ;; beginning-of-preedit
        ;; 2004-08-27 Takuro Ashie <ashie@homa.ne.jp>
        ;;   * We should restore pending state of rk-context when the input-rule
        ;;     is kana mode.
        ((mana-beginning-of-preedit-key? key key-state)
         (mana-context-confirm-kana! mc)
         (ustr-cursor-move-beginning! preconv-str))

        ;; end-of-preedit
        ;; 2004-08-27 Takuro Ashie <ashie@homa.ne.jp>
        ;;   * We should restore pending state of rk-context when the input-rule
        ;;     is kana mode.
        ((mana-end-of-preedit-key? key key-state)
         (mana-context-confirm-kana! mc)
         (ustr-cursor-move-end! preconv-str))

        ;; modifiers (except shift) => ignore
        ((and (modifier-key-mask key-state)
              (not (shift-key-mask key-state)))
         #f)

        (else
          (let* ((key-str (charcode->string 
                            (if (= rule mana-input-rule-kana)
                                key
                                (to-lower-char key))))
                 (pend (rk-pending rkc))
                 (res (rk-push-key! rkc key-str)))

            (if (and res
                     (or (list? (car res))
                         (not (string=? (car res) ""))))
                (let ((next-pend (rk-pending rkc)))
                  (if (list? (car res))
                      (ustr-insert-seq!  preconv-str res)
                      (ustr-insert-elem! preconv-str res))
                  (if (and next-pend
                           (not (string=? next-pend "")))
                      (ustr-insert-elem! raw-str pend)
                      (ustr-insert-elem! raw-str (string-append pend key-str))))
                )))))))

(define mana-context-confirm-kana!
  (lambda (mc)
    (if (= (mana-context-input-rule mc)
           mana-input-rule-kana)
        (let* ((preconv-str (mana-context-preconv-ustr mc))
               (rkc (mana-context-rkc mc))
               (residual-kana (rk-peek-terminal-match rkc)))
          (if residual-kana
              (begin
                (ustr-insert-elem! preconv-str residual-kana)
                (rk-flush rkc)))))))

(define mana-proc-input-state
  (lambda (mc key key-state)
    (if (mana-has-preedit? mc)
        (mana-proc-input-state-with-preedit mc key key-state)
        (mana-proc-input-state-no-preedit mc key key-state))))

(define mana-separator
  (lambda (mc)
    (let ((attr (bit-or preedit-separator
                        preedit-underline)))
      (if mana-show-segment-separator?
          (cons attr mana-segment-separator)
          #f))))

(define mana-context-transposing-state-preedit
  (lambda (mc)
    (let* ((transposing-text (mana-transposing-text mc)))
      (list (cons preedit-underline transposing-text)
            (cons preedit-cursor "")))))

(define mana-transposing-text
  (lambda (mc)
    (let* ((transposing-type (mana-context-transposing-type mc)))
      (cond
        ((= transposing-type mana-type-hiragana)
         (mana-make-whole-string mc #t multi-segment-type-hiragana))

        ((= transposing-type mana-type-katakana)
         (mana-make-whole-string mc #t multi-segment-type-katakana))

        ((= transposing-type mana-type-hankana)
         (mana-make-whole-string mc #t multi-segment-type-hankana))

        ((= transposing-type mana-type-latin)
         (mana-make-whole-raw-string mc #f))

        ((= transposing-type mana-type-wide-latin)
         (mana-make-whole-raw-string mc #t))
        ))))

(define mana-converting-state-preedit
  (lambda (mc)
    (let* (
           (segments (mana-context-segments mc))
           (cur-seg (ustr-cursor-pos segments))
           (separator (mana-separator mc)))
      (append-map
        (lambda (seg-idx cand-idx)
          (let* ((attr (if (= seg-idx cur-seg)
                           (bit-or preedit-reverse
                                   preedit-cursor)
                           preedit-underline))
                 (cand (mana-get-nth-candidate mc seg-idx cand-idx))
                 (seg (list (cons attr cand))))
            (if (and separator
                     (< 0 seg-idx))
                (cons separator seg)
                seg)))
        (iota (ustr-length segments))
        (ustr-whole-seq segments)))))

(define mana-input-state-preedit
  (lambda (mc)
    (let* ((preconv-str (mana-context-preconv-ustr mc))
           (rkc (mana-context-rkc mc))
           (pending (rk-pending rkc))
           (kana (mana-context-kana-mode mc))
           (rule (mana-context-input-rule mc))
           (extract-kana
             (if (= rule mana-input-rule-kana)
                 (lambda (entry) (car entry))
                 (lambda (entry) (list-ref entry kana)))))

      (list
        (and (not (ustr-cursor-at-beginning? preconv-str))
             (cons preedit-underline
                   (string-append-map-ustr-former extract-kana preconv-str)))
        (and (> (string-length pending) 0)
             (cons preedit-underline pending))
        (and (mana-has-preedit? mc)
             (cons preedit-cursor ""))
        (and (not (ustr-cursor-at-end? preconv-str))
             (cons preedit-underline
                   (string-append-map-ustr-latter extract-kana preconv-str)))))))

(define mana-get-commit-string
  (lambda (mc)
    (let (
          (segments (mana-context-segments mc)))
      (string-append-map (lambda (seg-idx cand-idx)
                           (mana-get-nth-candidate mc seg-idx cand-idx))
                         (iota (ustr-length segments))
                         (ustr-whole-seq segments)))))

(define mana-commit-string
  (lambda (mc)
    '()))

(define mana-do-commit
  (lambda (mc)
    (im-commit mc (mana-get-commit-string mc))
    (mana-commit-string mc)
    (mana-reset-candidate-window mc)
    (mana-flush mc)))

(define mana-correct-segment-cursor
  (lambda (segments)
    (if (ustr-cursor-at-end? segments)
        (ustr-cursor-move-backward! segments))))

(define mana-move-segment
  (lambda (mc offset)
    (mana-reset-candidate-window mc)
    (let ((segments (mana-context-segments mc)))
      (ustr-cursor-move! segments offset)
      (mana-correct-segment-cursor segments))))

(define mana-resize-segment
  (lambda (mc cnt)
    (let* (
           (segments (mana-context-segments mc))
           (cur-seg (ustr-cursor-pos segments)))
      (mana-reset-candidate-window mc)
      (mana-resize-specified-segment mc cur-seg cnt)
      (let* ((resized-nseg (mana-context-nr-segments mc))
             (latter-nseg (- resized-nseg cur-seg)))
        (ustr-set-latter-seq! segments (make-list latter-nseg 0))))))

(define mana-move-candidate
  (lambda (mc offset)
    (let* (
           (segments (mana-context-segments mc))
           (cur-seg (ustr-cursor-pos segments))
           (max (mana-get-nr-candidates mc cur-seg))
           (n (+ (ustr-cursor-frontside segments)
                 offset))
           (compensated-n (cond
                            ((>= n max)
                             0)
                            ((< n 0)
                             (- max 1))
                            (else
                              n)))
           (new-op-count (+ 1 (mana-context-candidate-op-count mc))))
      (ustr-cursor-set-frontside! segments compensated-n)
      (mana-context-set-candidate-op-count! mc new-op-count)
      (if (and mana-use-candidate-window?
               (= (mana-context-candidate-op-count mc)
                  mana-candidate-op-count))
          (begin
            (mana-context-set-candidate-window! mc #t)
            (im-activate-candidate-selector mc max mana-nr-candidate-max)))
      (if (mana-context-candidate-window mc)
          (im-select-candidate mc compensated-n)))))

(define mana-move-candidate-in-page
  (lambda (mc numeralc)
    (let* (
           (segments (mana-context-segments mc))
           (cur-seg (ustr-cursor-pos segments))
           (max (mana-get-nr-candidates mc cur-seg))
           (n (ustr-cursor-frontside segments))
           (cur-page (if (= mana-nr-candidate-max 0)
                         0
                         (quotient n mana-nr-candidate-max)))
           (pageidx (- (numeral-char->number numeralc) 1))
           (compensated-pageidx (cond
                                  ((< pageidx 0) ; pressing key_0
                                   (+ pageidx 10))
                                  (else
                                    pageidx)))
           (idx (+ (* cur-page mana-nr-candidate-max) compensated-pageidx))
           (compensated-idx (cond
                              ((>= idx max)
                               (- max 1))
                              (else
                                idx)))
           (new-op-count (+ 1 (mana-context-candidate-op-count mc))))
      (ustr-cursor-set-frontside! segments compensated-idx)
      (mana-context-set-candidate-op-count! mc new-op-count)
      (im-select-candidate mc compensated-idx))))

(define mana-reset-candidate-window
  (lambda (mc)
    (if (mana-context-candidate-window mc)
        (begin
          (im-deactivate-candidate-selector mc)
          (mana-context-set-candidate-window! mc #f)))
    (mana-context-set-candidate-op-count! mc 0)))

(define mana-proc-converting-state
  (lambda (mc key key-state)
    (cond
      ((mana-prev-page-key? key key-state)
       (if (mana-context-candidate-window mc)
           (im-shift-page-candidate mc #f)))

      ((mana-next-page-key? key key-state)
       (if (mana-context-candidate-window mc)
           (im-shift-page-candidate mc #t)))

      ((mana-commit-key? key key-state)
       (mana-do-commit mc))

      ((mana-extend-segment-key? key key-state)
       (mana-resize-segment mc 1))

      ((mana-shrink-segment-key? key key-state)
       (mana-resize-segment mc -1))

      ((mana-next-segment-key? key key-state)
       (mana-move-segment mc 1))

      ((mana-prev-segment-key? key key-state)
       (mana-move-segment mc -1))

      ((mana-beginning-of-preedit-key? key key-state)
       (begin
         (ustr-cursor-move-beginning! (mana-context-segments mc))
         (mana-reset-candidate-window mc)))

      ((mana-end-of-preedit-key? key key-state)
       (begin
         (ustr-cursor-move-end! (mana-context-segments mc))
         (mana-correct-segment-cursor (mana-context-segments mc))
         (mana-reset-candidate-window mc)))

      ((mana-backspace-key? key key-state)
       (mana-cancel-conv mc))

      ((mana-next-candidate-key? key key-state)
       (mana-move-candidate mc 1))

      ((mana-prev-candidate-key? key key-state)
       (mana-move-candidate mc -1))

      ((mana-cancel-key? key key-state)
       (mana-cancel-conv mc))

      ((and mana-select-candidate-by-numeral-key?
            (numeral-char? key)
            (mana-context-candidate-window mc))
       (mana-move-candidate-in-page mc key))

      ;; don't discard shift-modified keys. Some of them ("?", "~",
      ;; etc) are used to implicit commit. Reported by [mana-dev 745]
      ;; -- YamaKen 2004-04-08
      ((and (modifier-key-mask key-state)
            (not (shift-key-mask key-state)))
       #f)  ;; use #f rather than () to conform to R5RS

      ((symbol? key)
       #f)

      (else
        (begin
          (mana-do-commit mc)
          (mana-proc-input-state mc key key-state))))))

(define mana-proc-wide-latin
  (lambda (mc key key-state)
    (let* ((char (charcode->string key))
           (w (or (ja-direct char)
                  (ja-wide char))))
      (cond
        ((and mana-use-with-vi?
              (mana-vi-escape-key? key key-state))
         (begin
           (mana-flush mc)
           (mana-context-set-wide-latin! mc #f)
           (mana-commit-raw mc)))

        ((mana-on-key? key key-state)
         (mana-flush mc)
         (mana-context-set-on! mc #t))
        ((and (modifier-key-mask key-state)
              (not (shift-key-mask key-state)))
         (mana-commit-raw mc))
        (w
          (im-commit mc w))
        (else
          (mana-commit-raw mc)))
      ())))

(define mana-press-key-handler
  (lambda (mc key key-state)
    (if (control-char? key)
        (im-commit-raw mc)
        (if (mana-context-on mc)
            (if (mana-context-transposing mc)
                (mana-proc-transposing-state mc key key-state)
                (if (mana-context-converting mc)
                    (mana-proc-converting-state mc key key-state)
                    (mana-proc-input-state mc key key-state)))
            (if (mana-context-wide-latin mc)
                (mana-proc-wide-latin mc key key-state)
                (mana-proc-raw-state mc key key-state))))
    ;; preedit
    (mana-update-preedit mc)))


(define mana-release-key-handler
  (lambda (mc key key-state)
    (if (or (control-char? key)
            (and (not (mana-context-on mc))
                 (not (mana-context-wide-latin mc))))
        ;; don't discard key release event for apps
        (mana-commit-raw mc))))

(define mana-reset-handler
  (lambda (mc)
    (if (mana-context-on mc)
        (mana-flush mc))
    ;; code to commit pending string must not be added to here.
    ;; -- YamaKen 2004-10-21
    ))

(define mana-get-candidate-handler
  (lambda (mc idx accel-enum-hint)
    (let* (
           (cur-seg (ustr-cursor-pos (mana-context-segments mc)))
           (cand (mana-get-nth-candidate mc cur-seg idx)))
      (list cand (digit->string (+ idx 1)) ""))))

(define mana-set-candidate-index-handler
  (lambda (mc idx)
    (ustr-cursor-set-frontside! (mana-context-segments mc) idx)
    ;    (mana-move-segment mc 1)
    (mana-update-preedit mc)))

(mana-configure-widgets)

(register-im
  'mana
  "ja"
  "EUC-JP"
  mana-im-name-label
  mana-im-short-desc
  #f
  mana-init-handler
  mana-release-handler
  context-mode-handler
  mana-press-key-handler
  mana-release-key-handler
  mana-reset-handler
  mana-get-candidate-handler
  mana-set-candidate-index-handler
  context-prop-activate-handler
  )
