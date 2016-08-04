#lang racket/base
(require with-cache)
(*current-cache-directory* (find-system-path 'temp-dir))
(provide (all-from-out with-cache))
