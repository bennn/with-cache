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

  (test-case "with-cache:cwd"
    ;; TODO always prints to an error port, because list of *current-cache-keys*
    ;;  is changing for each invocation
    (reset-file! data1)

    (define num-calls (box 0))
    (define result '$$$)

    (define (f)
      (set-box! num-calls (+ (unbox num-calls) 1))
      result)

    (define v0 (with-cache data1 f))
    (check-equal? v0 (with-cache data1 f))
    (check-equal? v0 result)
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

  (test-case "with-cache:*use-cache?*=#f"
    (reset-file! data1)

    (define num-calls (box 0))
    (define result (gensym 'result))

    (define (f)
      (set-box! num-calls (+ (unbox num-calls) 1))
      result)

    (parameterize ([*use-cache?* #f])
      (check-equal? (with-cache data1 f) result)
      (check-false (file-exists? data1))
      (check-equal? (with-cache data1 f) result)
      (check-equal? (unbox num-calls) 2)))

  (test-case "with-cache:fasl=#t"
    (reset-file! data1)

    (check-false (file-exists? data1))
    (parameterize ([*with-cache-fasl?* #t])
      (with-cache data1 (λ () 4)))
    (check-true (file-exists? data1))

    (with-handlers ([exn:fail:read? void])
      (with-input-from-file data1 read)
      (raise-user-error 'with-cache:test "Error: `read` should have failed.")))

  (test-case "with-cache:fasl=#f"
    (reset-file! data1)

    (define n 48)

    (check-false (file-exists? data1))
    (parameterize ([*with-cache-fasl?* #f])
      (with-cache data1 (λ () n)))
    (check-true (file-exists? data1))

    (with-handlers ([exn:fail:read? (λ (exn) (raise-user-error 'with-cache:test "Error reading, got exception '~a'" (exn-message exn)))])
      (check-true (and (with-input-from-file data1 read) #t))))

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

    (define result 'hello-world)
    (define num-calls (box 0))

    (define (f)
      (set-box! num-calls (+ (unbox num-calls) 1))
      result)

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

)
