#lang racket/base

(require
  racket/contract
  with-cache/private/with-cache)

(provide
  *use-cache?*
  *with-cache-fasl?*
  *current-cache-directory*
  *current-cache-keys*

  (contract-out
    [cachefile
     (-> path-string? parent-directory-exists?)]

    [with-cache
     (->* [parent-directory-exists? (-> any)]
          [#:read (-> any/c any)
           #:write (-> any/c any)]
          any)]))
