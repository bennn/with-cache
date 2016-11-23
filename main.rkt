#lang racket/base

(require
  racket/contract
  with-cache/private/with-cache)

(provide
  (contract-out
    [with-cache-logger
     logger?]

    [*use-cache?*
     (parameter/c boolean?)]

    [*with-cache-fasl?*
     (parameter/c boolean?)]

    [*current-cache-directory*
     (parameter/c path-string?)]

    [*current-cache-keys*
     (parameter/c (listof (or/c parameter? (-> any/c))))]

    [cachefile
     (-> path-string? parent-directory-exists?)]

    [with-cache
     (->* [parent-directory-exists? (-> any)]
          [#:read (-> any/c any)
           #:write (-> any/c any)]
          any)]))
