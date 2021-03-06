#lang info
(define collection "with-cache")
(define deps '("base" "typed-racket-lib"))
(define build-deps '("basedir" "scribble-lib" "racket-doc" "rackunit-lib" "pict-lib"))
(define pkg-desc "Simple, filesystem-based caching")
(define version "0.6")
(define pkg-authors '(ben))
(define scribblings '(("scribblings/with-cache.scrbl" () (tool-library))))
