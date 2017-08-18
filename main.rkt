#lang racket/base

(require
  racket/contract
  with-cache/private/with-cache)

(define keys/c
  (or/c #f (listof (or/c parameter? (-> any/c)))))

(define with-cache/c
  (->* [parent-directory-exists? (-> any)]
       [#:use-cache? boolean?
        #:fasl? boolean?
        #:keys keys/c
        #:read (-> any/c any)
        #:write (-> any/c any)]
       any))

(provide
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

    [cachefile
     (-> path-string? parent-directory-exists?)]

    [with-cache
     with-cache/c]
    [rename with-cache cache-ref
     with-cache/c]))
