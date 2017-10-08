#lang scribble/manual
@require[
  (for-syntax racket/base pkg/path)
  setup/collects
  setup/path-to-relative
  racket/path
  syntax/location]

@(define src (quote-source-file))

@(define-syntax (get-src stx)
   (define-values [pkg subpath] (path->pkg+subpath (syntax-source stx)))
   #`(list #,pkg #,(path->string subpath)))

@(define pkg+subpath (get-src))

@(define (edit-link online-prefix)
   (define pkg (car pkg+subpath))
   (define subpath (cadr pkg+subpath))
   (define gh-url (string-append online-prefix pkg "/" subpath))
   (url gh-url))

@title{Hello world}

@edit-link{https://github.com/bennn/with-cache/blob/master/}
