#lang info
(define collection "with-cache")
(define deps '("base" "typed-racket-lib"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib" "rackunit-abbrevs"))
(define pkg-desc "Simple, filesystem-based caching")
(define version "0.1")
(define pkg-authors '(ben))
(define scribblings '(("scribblings/with-cache.scrbl" () (tool-library))))
