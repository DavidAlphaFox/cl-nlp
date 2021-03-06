;;; (c) 2013-2017 Vsevolod Dyomkin

(in-package #:nlp-user)
(named-readtables:in-readtable rutilsx-readtable)


;;; end-user utilies

(defun grep (word string &key (width 25) pass-newlines limit)
  "Print all (or LIMIT) WORD occurances in STRING with the surrounding
   context up to WIDTH chars. If PASS-NEWLINES isn't set, the context
   will be shown up to the closest newline."
  (declare (type (integer 0) width))
  (let* ((regex (re:create-scanner (fmt "\\b~A\\b" word)
                                   :case-insensitive-mode t))
         (matches (re:all-matches regex string))
         (len (/ (length matches) 2)))
    (format t "Displaying ~A of ~A matches~%" (if limit (min limit len) len) len)
    (loop :for (s e) :on matches :by #'cddr :do
       (let ((s- (- s width))
             (e+ (+ e width)))
         (if pass-newlines
             (format t "~A~%" (substitute-if #\Space 'white-char-p
                                             (subseq string s- e+)))
             (let ((l-pos (max s- (1+ (position #\Newline string
                                                :end s :from-end t))))
                   (r-pos (min e+ (1- (position #\Newline string :start e)))))
               (format t "~@[~A~]~A~@[~A~]~%"
                       (unless (= s- l-pos) (filler (- l-pos s-)))
                       (subseq string l-pos r-pos)
                       (unless (= e+ r-pos) (filler (- e+ r-pos))))))))))

(defun tabulate (table &key (stream *standard-output*)
                       keys cols cumulative (order-by (constantly nil)))
  "Print TABLE to STREAM in nice readable column format.
   If KEYS are given, only they are taken into account.
   If COLS list is supplied print only columns matching them.
   (If ORDER-BY predicate is supplied they are sorted accordingly).
   If CUMULATIVE is T accumulate counts over each column."
  (flet ((strlen (obj)
           (length (princ-to-string obj))))
    (with ((samples (sort (or cols
                              (uniq (flatten (mapcar 'keys (vals table)))))
                          order-by))
           (table (if cumulative
                      (let ((cv (copy-hash-table table)))
                        (dotable (_ v cv)
                          (let ((total 0))
                            (dolist (s samples)
                              (:+ total (or (? v s) 0))
                              (set# s v total))))
                        cv)
                      table))
           (val-width #h())
           (conds (or keys (keys table)))
           (key-width (reduce 'max (mapcar #'strlen conds))))
      (dolist (s samples)
        (set# s val-width
              (max (strlen s)
                   (strlen (reduce 'max
                                   (mapcar ^(or (? % s) 0)
                                           (vals table)))))))
      ;; print header
      (format stream " ~V:@A" key-width "")
      (dolist (s samples)
        (format stream "  ~V:@A" (? val-width s) s))
      (terpri stream)
      ;; print rows
      (dotable (k v table)
        (when (member k conds)
          (format stream "  ~V:@A" key-width k)
          (dolist (s samples)
            (format stream "  ~V:@A" (? val-width s) (or (? v s) 0)))
          (terpri stream))))))

#+nil
(defun plot-table (table &rest args
                         &key keys cols cumulative (order-by (constantly nil)))
  "Plot all or selected KEYS and COLS from a TABLE.
   CUMULATIVE counts may be used, as well as custom ordering with ORDER-BY."
  (mv-bind (file cols-count keys-count)
      (apply #'write-tsv table args)
    (let ((row-format (fmt "\"~A\" using ~~A:xtic(2) with lines ~
                            title columnheader(~~:*~~A)"
                           file)))
      (cgn:with-gnuplot (t)
        (cgn:format-gnuplot "set grid")
        (cgn:format-gnuplot "set xtics rotate 90 1")
        (cgn:format-gnuplot "set ylabel \"~@[Cumulative ~]Counts\"" cumulative)
        (cgn:format-gnuplot "plot [0:~A] ~A"
                            cols-count
                            (strjoin "," (mapcar #`(fmt row-format (+ 3 %))
                                                 (range 0 keys-count))))))
    (delete-file file)))


;;;

(defun get-toks (text &key (kind :words))
  (let ((parags (tokenize *full-text-tokenizer* text)))
    (ecase kind
      (:parags (mapcar ^(mapcar 'tok-word %)
                       (mapcar ^(flat-map 'sent-toks %) parags)))
      (:sents (mapcar ^(mapcar 'tok-word (sent-toks %))
                      (flatten parags)))
      (:words (mapcar 'tok-word (flat-map 'sent-toks (flatten parags)))))))

(defun lemma-wikt (word)
  (nlp:lemmatize nlp:<wikt-dict> word))
