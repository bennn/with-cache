#lang racket/base

(require
  racket/contract
  with-cache/private/with-cache)

(define keys/c
  (or/c #f (listof (or/c parameter? (-> any/c)))))

(define equivalence/c
  (flat-named-contract "equivalence/c"
    (and/c procedure? (procedure-arity-includes/c 2))))

(provide
  equivalence/c

  get-with-cache-version

  parent-directory-exists?

  (contract-out
    [with-cache-logger
     logger?]

    [*use-cache?*
     (parameter/c boolean?)]

    [*with-cache-fasl?*
     (parameter/c boolean?)]

    [*current-cache-directory*
     (parameter/c (and/c path-string? directory-exists?))]

    [*current-cache-keys*
     (parameter/c keys/c)]

    [*keys-equal?*
     (parameter/c equivalence/c)]

    [cachefile
     (-> path-string? parent-directory-exists?)]

    [with-cache
     (->* [parent-directory-exists? (-> any)]
          [#:use-cache? boolean?
           #:fasl? boolean?
           #:keys keys/c
           #:keys-equal? equivalence/c
           #:read (-> any/c any)
           #:write (-> any/c any)]
          any)]))
