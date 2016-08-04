#lang racket/base
(require with-cache)
(*current-cache-directory* "./compiled")
(provide (all-from-out with-cache))
