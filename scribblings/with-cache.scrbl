#lang scribble/manual
@require[scribble/eval
         scriblib/footnote
         pict
         (only-in racket/math pi)
         with-cache
         (for-label
           racket/base racket/contract racket/fasl racket/path
           racket/file racket/serialize version/utils with-cache)]

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
@margin-note{By default, any cache built by an older version of @racketmodname[with-cache] is invalid. Set @racket[*current-cache-keys*] to override this default.}

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
                        ser-pict (arrows "add-keys" "keys-equal?")
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
    @racket[add-keys] is a hidden function that adds the value of @racket[*current-cache-keys*] to a cached value.
  }
  @item{
    @racket[keys-equal?] compares the keys in a cache file to the now-current value of @racket[*current-cache-keys*].
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
                     [#:keys keys (or/c #f (listof (or/c parameter? (-> any/c)))) (*current-cache-keys*)]
                     [#:keys-equal? keys-equal? equivalence/c (*keys-equal?*)])
                     any]{
  If @racket[cache-path] exists:
  @nested[#:style 'inset]{@itemlist[#:style 'ordered
    @item{
      reads the contents of @racket[cache-path] (using @racket[s-exp->fasl] if @racket[*with-cache-fasl?*] is @racket[#t] and @racket[read] otherwise);
    }
    @item{
      checks whether the result contains keys equal to @racket[*current-cache-keys*],
       where "equal" is determined by @racket[keys-equal?];
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

  Uses @racket[call-with-file-lock/timeout] to protect concurrent reads and writes to the same @racket[cache-path].
  If a thread fails to lock @racket[cache-path], @racket[with-cache] throws an exception (@racket[exn:fail:filesystem]) giving the location of the problematic lock file.
  All lock files are generated by @racket[make-lock-file-name] and stored in @racket[(find-system-path 'temp-dir)].

  Diagnostic information is logged under the @racket[with-cache] topic.
  To see logging information, use either:

  @nested[#:style 'inset @exec{racket -W with-cache <file.rkt>}]

  or, if you are not invoking @exec{racket} directly:

  @nested[#:style 'inset @exec|{PLTSTDERR="error info@with-cache" <CMD>}|]

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

@defparam[*current-cache-directory* cache-dir (and/c path-string? directory-exists?) #:value (build-path (current-directory) "compiled" "with-cache")]{
  The value of this parameter is the prefix of paths returned by @racket[cachefile].
  Another good default is @racket[(find-system-path 'temp-dir)].
}

@defparam[*current-cache-keys* params (or/c #f (listof (or/c parameter? (-> any/c)))) #:value (list get-with-cache-version)]{
  List of parameters (or thunks) used to check when a cache is invalid.

  Before writing a cache file, @racket[with-cache] gets the value of @racket[*current-cache-keys*]
   (by taking the value of the parameters and forcing the thunks)
   and writes the result to the file.
  When reading a cache file, @racket[with-cache] gets the current value of @racket[*current-cache-keys*]
   and compares this value to the value written in the cache file.
  If the current keys are NOT equal to the old keys (equal in the sense of @racket[*keys-equal?*]),
   then the cache is invalid.

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

  By default, the only key is a thunk that retrieves the installed version of
   the @racket[with-cache] package.

}

@defparam[*keys-equal?* =? equivalence/c #:value equal?]{
  Used to check whether a cache file is invalid.

  A cache is invalid if @racket[(=? _old-keys _current-keys)] returns @racket[#false],
   where @racket[_current-keys] is the current value of @racket[*current-cache-keys*].

  By convention, the function bound to @racket[=?] should be an equivalence,
   meaning it obeys the following 3 laws:
  @itemlist[
  @item{
    @racket[(=? _k _k)] returns a true value for all @racket[_k];
  }
  @item{
    @racket[(=? _k1 _k2)] returns the same value as @racket[(=? _k2 _k1)]; and
  }
  @item{
    @racket[(and (=? _k1 _k2) (=? _k2 _k3))] implies @racket[(=? _k1 _k3)] is true.
  }
  ]

  The contract @racket[equivalence/c] does not enforce these laws,
   but it might in the future.
}


@section{Utilities}

@defproc[(cachefile [filename path-string?]) parent-directory-exists?]{
  Prefix @racket[filename] with the value of @racket[*current-cache-directory*].
  By contract, this function returns only paths whose parent directory exists.
}

@defproc[(parent-directory-exists? [x any/c]) boolean?]{
  Flat contract that checks whether @racket[(path-only x)] exists.
}

@defproc[(equivalence/c [x any/c]) boolean?]{
  Flat contract for functions that implement equivalence relations.
}

@defproc[(get-with-cache-version) valid-version?]{
  Return the current version of @racket[with-cache].
}

@defthing[with-cache-logger logger?]{
  A @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{logger} that reports events from the @racket[with-cache] library.
  Logs @racket['info] events when reading or writing caches and @racket['error] events after detecting corrupted cache files.
}
