#lang scribble/manual
@require[scribble/eval
         scriblib/footnote
         pict
         (only-in racket/math pi)
         with-cache
         (for-label with-cache racket/base racket/contract racket/fasl racket/serialize)]

@title[#:tag "top"]{with-cache}
@author[@hyperlink["https://github.com/bennn"]{Ben Greenman}]

@defmodule[with-cache]

Simple, filesystem-based caching.
Wrap your large computations in a thunk and let @racket[with-cache] deal with
 saving and retrieving the result.

@racketblock[
  (define fish
    (with-cache (cachefile "stdfish.rktd")
      (λ () (standard-fish 100 50))))
]

Here's a diagram of what's happening in @racket[with-cache]:

@(let* ([val-pict (colorize (text "$" (list 'bold) 50) "ForestGreen")]
        [ser-pict (cc-superimpose (rectangle 50 50 #:border-color "black" #:border-width 1)
                                  (text "1101" "Courier" 20))]
        [lock (filled-rectangle 50 30 #:color "gold" #:border-color "chocolate" #:border-width 2)]
        [key-pict (cc-superimpose lock ser-pict)]
        [fil-pict (file-icon 40 50 "bisque")]
        [arrow-line (hline 130 4)]
        [head-size 24]
        [arrows (λ (top bot) (vc-append 44 (vc-append (text top '() 14)
                                                      (hc-append arrow-line (arrowhead head-size 0)))
                                           (vc-append (hc-append (arrowhead head-size pi) arrow-line)
                                                      (text bot '() 15))))]
        [all (hc-append val-pict (arrows "#:write" "#:read")
                        ser-pict (arrows "add-keys" "check-keys")
                        key-pict (arrows "write-data" "read-data")
                        fil-pict)]
        )
  @centered[all])

@itemlist[
  @item{
    The @emph{dollar sign} on the left represents a value that is expensive to compute.
  }
  @item{
    The @emph{box} in the left-middle is a serialized version of the expensive value.
  }
  @item{
    The @emph{yellow box} in the right-middle is the serialized data paired with a (yellow) label.
  }
  @item{
    The @emph{file symbol} on the right represents a location on the filesystem.
  }
]

The @racket[with-cache] function implements this pipeline and provides hooks for controlling the interesting parts.
@itemlist[
  @item{
    @racket[#:write] and @racket[#:read] are optional arguments to @racket[with-cache].
    They default to @racket[serialize] and @racket[deserialize].
  }
  @item{
    @racket[add-keys] and @racket[check-keys] are hidden functions.
    The parameter @racket[*current-cache-keys*] declares the keys.
  }
  @item{
    @racket[write-data] and @racket[read-data] are @racket[s-exp->fasl] and @racket[fasl->s-exp] when the parameter @racket[*with-cache-fasl?*] is @racket[#t].
    Otherwise, these functions are @racket[write] and @racket[read].
  }
]


@defproc[(with-cache [cache-path path-string?]
                     [thunk (-> any)]
                     [#:read read-proc (-> any/c any) deserialize]
                     [#:write write-proc (-> any/c any) serialize]
                     [#:use-cache? use-cache? boolean? (*use-cache?*)]
                     [#:fasl? fasl? boolean? (*with-cache-fasl?*)]
                     [#:keys keys (or/c #f (listof (or/c parameter? (-> any/c)))) (*current-cache-keys*)])
                     any]{
  If @racket[cache-path] exists:
  @nested[#:style 'inset]{@itemlist[#:style 'ordered
    @item{
      reads the contents of @racket[cache-path] (using @racket[s-exp->fasl] if @racket[*with-cache-fasl?*] is @racket[#t] and @racket[read] otherwise);
    }
    @item{
      checks whether the result contains keys matching @racket[*current-cache-keys*];
    }
    @item{
      if so, removes the keys and deserializes a value.
    }
  ]}
  If @racket[cache-path] does not exist or contains invalid data:
  @nested[#:style 'inset]{@itemlist[#:style 'ordered
    @item{
      executes @racket[thunk], obtains result @racket[r];
    }
    @item{
      retrieves the values of @racket[*current-cache-keys*];
    }
    @item{
      saves the keys and @racket[r] to @racket[cache-path];
    }
    @item{
      returns @racket[r]
    }
  ]}

  Diagnostic information is logged under the @racket[with-cache] topic.
  To see logging information, use @tt{racket -W with-cache <file.rkt>}.
}


@section{Parameters}

@defparam[*use-cache?* use-cache? boolean? #:value #t]{
  Parameter for disabling @racket[with-cache].
  When @racket[#f], @racket[with-cache] will not read or write any cachefiles.
}

@defparam[*with-cache-fasl?* fasl? boolean? #:value #t]{
  When @racket[#t], write files in @tt{fasl} format.
  Otherwise, write files with @racket[write].

  Note that byte strings written using @racket[s-exp->fasl] cannot be read by code running a different version of Racket.
}

@defparam[*current-cache-directory* cache-dir boolean? #:value "./compiled/with-cache"]{
  The value of this parameter is the prefix of paths returned by @racket[cachefile].
  Another good default is @racket[(find-system-path 'temp-dir)].
}

@defparam[*current-cache-keys* params (or/c #f (listof (or/c parameter? (-> any/c)))) #:value #f]{
  List of parameters or thunks to validate cachefiles with.
  The values in @racket[*current-cache-keys*] are @emph{computations}.
  We run these computations once before writing a cache file and save the result.
  We run these computations again when reading the cache file; if the new results match the saved results, the cache file is valid.
  Otherwise, the cache file is outdated and @racket[with-cache] will discard it.

  For example, @racket[(*current-cache-keys* (list current-seconds))] causes
   @racket[with-cache] to ignore cachefiles written more than 1 second ago.

  @(begin #reader scribble/comment-reader
  (racketblock
    (define (fresh-fish)
      (parameterize ([*current-cache-keys* (list current-seconds)])
        (with-cache (cachefile "stdfish.rktd")
          (λ () (standard-fish 100 50)))))

    (fresh-fish) ;; Writes to "compiled/with-cache/stdfish.rktd"
    (fresh-fish) ;; Reads from "compiled/with-cache/stdfish.rktd"
    (sleep 1)
    (fresh-fish) ;; Writes to "compiled/with-cache/stdfish.rktd"
  ))

  By default, the only key is a thunk that retrieves the installed version of the @racket[with-cache] package.

}


@section{Utilities}

@defproc[(cachefile [filename path-string?]) path-string?]{
  Prefix @racket[filename] with the value of @racket[*current-cache-directory*].
  By contract, this function returns only paths whose parent directory exists.
}

@defthing[with-cache-logger logger?]{
  A @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{logger} that reports events from the @racket[with-cache] library.
  Logs @racket['info] events when reading or writing caches and @racket['error] events after detecting corrupted cache files.
}
