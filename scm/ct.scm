;;;
;;; Copyright (c) 2010 uim Project http://code.google.com/p/uim/
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

;; ct.scm: provides rk-lib equivalent functions using composing table
;;
;; following functions are used by rk.scm if table is used as a rule
;;   ct-lib-expect-seq
;;   ct-lib-expect-key-for-seq?
;;   ct-lib-find-seq
;;   ct-lib-find-partial-seq
;;
;; NB: composing table needs to be sorted

(require-dynlib "look")

(define ct-lib-find-seq
  (lambda (seq table)
    (let ((looked (look-lib-look
                    #f
                    #f
                    1
                    (string-append (sys-pkgdatadir) "/tables/" table)
                    (apply string-append seq))))
      (if (and
            (not (null? looked))
            (= (string-contains (car looked) " " 0) 0))
        (list (list seq) (read-from-string (car looked)))
        #f))))

;; return a rule of partial match 
(define ct-lib-find-partial-seq
  (lambda (seq table)
    ;; search 2 entries matching (including partial match) with look
    (let ((looked (look-lib-look
                    #f
                    #f
                    2
                    (string-append (sys-pkgdatadir) "/tables/" table)
                    (apply string-append seq))))
      (if (not (null? looked))
        (let ((first (car looked))
              (second (if (null? (cdr looked))
                        '()
                        (car (cdr looked)))))
          (cond
            ;; second one is partial
            ((and
                (not (null? second))
                (string=? (substring first 0 1) " "))
             (let ((partial
                     (reverse
                       (string-to-list (car (string-split second " ")))))
                   (cands
                     (apply string-append (cdr (string-split second " ")))))
               (list (list (append seq partial)) (read-from-string cands))))
            ;; first one is partial
            ((not (string=? (substring first 0 1) " "))
             (let ((partial
                     (reverse
                       (string-to-list (car (string-split first " ")))))
                   (cands
                     (apply string-append (cdr (string-split first " ")))))
               (list (list (append seq partial)) (read-from-string cands))))
            (else
              #f)))
        #f))))