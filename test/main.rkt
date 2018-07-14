#lang racket/base
(module+ test
  (require
    rackunit
    racket/file
    racket/runtime-path
    with-cache
    (for-syntax racket/base))

  (define-runtime-path data1 "./data1.rktd")
  (define-runtime-path with-cache-subdir "./subdir")
  (define-runtime-path data2 "./subdir/data2.rktd")
  (define-runtime-path compiled "./compiled")

  (unless (directory-exists? with-cache-subdir) (error 'with-cache "missing data directory ~a" with-cache-subdir))
  (unless (directory-exists? compiled) (make-directory compiled))

  (define (reset-file! f)
    (when (file-exists? f)
      (delete-file f)))

  ;; Return 3 values:
  ;; - (Boxof Natural), counts the number of calls to the 2nd return value
  ;; - (-> Symbol), a thunk that simulates writing to a cache
  ;; - Symbol, the return value of the thunk
  (define (make-counter)
    (define num-calls (box 0))
    (define result (gensym '$$$))
    (define (f)
      (set-box! num-calls (+ (unbox num-calls) 1))
      result)
    (values num-calls f result))

  ;; ---------------------------------------------------------------------------

  (test-case "with-cache:cwd"
    ;; TODO always prints to an error port, because list of *current-cache-keys*
    ;;  is changing for each invocation
    (reset-file! data1)

    (define-values (num-calls f result) (make-counter))

    (define v0 (with-cache data1 f))
    (check-equal? (symbol->string v0) (symbol->string (with-cache data1 f)))
    (check-equal? (symbol->string v0) (symbol->string result))
    (check-equal? (unbox num-calls) 1)

    (define v1
      (parameterize ([*current-cache-keys* '()])
        (with-cache data1 f)))
    (check-equal? v0 v1)
    (check-equal? (unbox num-calls) 2)

    (define v2
      (parameterize ([*use-cache?* #f])
        (with-cache data1 f)))
    (check-equal? v0 v2)
    (check-equal? (unbox num-calls) 3)
  )

  (test-case "with-cache:*use-cache?*=#f/parameter"
    (reset-file! data1)

    (define-values (num-calls f result) (make-counter))

    (parameterize ([*use-cache?* #f])
      (check-equal? (with-cache data1 f) result)
      (check-false (file-exists? data1))
      (check-equal? (with-cache data1 f) result)
      (check-equal? (unbox num-calls) 2)))

  (test-case "with-cache:*use-cache?*=#f/keyword"
    (reset-file! data1)

    (define-values (num-calls f result) (make-counter))

    (check-equal? (with-cache data1 f #:use-cache? #f) result)
    (check-false (file-exists? data1))
    (check-equal? (with-cache data1 f #:use-cache? #f) result)
    (check-equal? (unbox num-calls) 2))

  (test-case "with-cache:fasl=#t/parameter"
    (reset-file! data1)

    (define the-value 4)

    (check-false (file-exists? data1))
    (parameterize ([*with-cache-fasl?* #t])
      (with-cache data1 (λ () the-value)))
    (check-true (file-exists? data1))

    (define new-value
      (parameterize ([read-accept-compiled #true])
        (with-input-from-file data1 read)))
    (check-false (equal? new-value the-value)))

  (test-case "with-cache:fasl=#t/keyword"
    (reset-file! data1)
    (define the-value 4)

    (check-false (file-exists? data1))
    (with-cache data1 (λ () the-value) #:fasl? #t)
    (check-true (file-exists? data1))

    (define new-value
      (parameterize ([read-accept-compiled #true])
        (with-input-from-file data1 read)))
    (check-false (equal? new-value the-value)))

  (test-case "with-cache:fasl=#f"
    (reset-file! data1)

    (define n 48)

    (check-false (file-exists? data1))
    (parameterize ([*with-cache-fasl?* #f])
      (with-cache data1 (λ () n)))
    (check-true (file-exists? data1))

    (with-handlers ([exn:fail:read? (λ (exn) (raise-user-error 'with-cache:test "Error reading, got exception '~a'" (exn-message exn)))])
      (check-true (and
                    (parameterize ([read-accept-compiled #true])
                      (with-input-from-file data1 read))
                    #t))))

  (test-case "with-cache:read/write"
    (reset-file! data1)

    (define read-result 'read-result)
    (define write-result 'write-result)
    (define thunk-result 'thunk-result)

    (define v0
      (with-cache data1
        (λ () thunk-result)
        #:read (λ (v) (if (eq? v write-result) read-result #f))
        #:write (λ (v) (if (eq? v thunk-result) write-result #f))))

    (define v1
      (with-cache data1
        (λ () thunk-result)
        #:read (λ (v) (if (eq? v write-result) read-result #f))
        #:write (λ (v) (if (eq? v thunk-result) write-result #f))))

    (check-equal? v0 thunk-result)
    (check-equal? v1 read-result))

  (test-case "with-cache:subdir"
    (reset-file! data2)

    (define-values (num-calls f result) (make-counter))

    (define v0
      (parameterize ([*current-cache-directory* with-cache-subdir])
        (with-cache (cachefile "data2.rktd") f)))

    (define v1
      (let ([cf (cachefile "data2.rktd")])
        (reset-file! cf)
        (with-cache cf f)))

    (check-equal? v0 result)
    (check-equal? v0 v1)

    (check-equal? (unbox num-calls) 2)
  )

  (test-case "with-cache:truncate-long-values"
    (struct non-serializable-structure-with-long-name ())

    (define exn-msg
      (parameterize ([error-print-width 10])
        (with-handlers ([exn:fail:user? (λ (exn) (exn-message exn))])
          (with-cache "test.rktd"
            (λ () (non-serializable-structure-with-long-name))))))

    (check-regexp-match #rx"'#<non-s\\.\\.\\.'$" exn-msg))

  (test-case "current-cache-keys/parameter"
    (reset-file! data1)

    (define-values (count count++ secret-key) (make-counter))

    (define k1 (list (lambda () 1)))
    (define k2 (list (lambda () 2)))

    (define v0
      (parameterize ([*current-cache-keys* k1])
        (with-cache data1 count++)))

    (define v1
      (parameterize ([*current-cache-keys* k1])
        (with-cache data1 count++)))

    (check-equal? (unbox count) 1)
    (check-equal? (symbol->string v0) (symbol->string v1))

    (define v1/no-key
      (with-cache data1 count++))

    (check-equal? (unbox count) 2)

    (define v2
      (parameterize ([*current-cache-keys* k2])
        (with-cache data1 count++)))

    (define v3
      (parameterize ([*current-cache-keys* k1])
        (with-cache data1 count++)))

    (check-equal? (unbox count) 4)
    (check-equal? (symbol->string v2) (symbol->string v3))
  )

  (test-case "current-cache-keys/keyword"
    (reset-file! data1)

    (define-values (count count++ secret-key) (make-counter))

    (define k1 (list (lambda () 1)))
    (define k2 (list (lambda () 2)))

    (define v0
      (with-cache data1 count++ #:keys k1))

    (define v1
      (with-cache data1 count++ #:keys k1))

    (check-equal? (unbox count) 1)
    (check-equal? (symbol->string v0) (symbol->string v1))

    (define v1/no-key
      (with-cache data1 count++ #:read (lambda (x) x) #:keys '()))

    (check-equal? (unbox count) 2)

    (define v2
      (with-cache data1 count++ #:keys k2))

    (define v3
      (with-cache data1 count++ #:keys k1))

    (check-equal? (unbox count) 4)
    (check-equal? (symbol->string v2) (symbol->string v3))
  )

  (test-case "current-cache-keys/custom-eq"
    (reset-file! data1)

    (define-values (count count++ secret-key) (make-counter))

    (define k1 (list (lambda () 1)))
    (define k2 (list (lambda () 2)))

    (define v0
      (with-cache data1 count++ #:keys k1))

    (define v1
      (with-cache data1 count++ #:keys k1 #:keys-equal? (λ (x y) #f)))

    (check-equal? (unbox count) 2)
    (check-equal? (symbol->string v0) (symbol->string v1))

    (define v1+
      (with-cache data1 count++ #:keys k1 #:keys-equal? (λ (x y) (andmap = x y))))

    (check-equal? (unbox count) 2)
    (check-equal? (symbol->string v1) (symbol->string v1+))
  )

)
