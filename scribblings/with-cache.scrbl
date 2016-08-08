#lang scribble/manual
@require[scribble/eval scriblib/footnote]

@title[#:tag "top"]{with-cache}
@author[@hyperlink["https://github.com/bennn"]{Ben Greenman}]

@defmodule[with-cache]

Simple, filesystem-based caching.
Wrap your large computations in a thunk and let @racket[with-cache] deal with
 saving and retrieving the result.

@defproc[(with-cache [cache-path path-string?]
                     [thunk (-> any)]
                     [#:read read-proc (or/c #f (-> any/c any)) #f]
                     [#:write write-proc (or/c #f (-> any/c any)) #f])
                     any]{
  If @racket[cache-path] exists, applies @racket[read-proc] to the result of
   @racket[(file->value cache-path)] and returns the result (if non-@racket[#f]).
  If @racket[cache-path] does not exist or @racket[read-proc] returns @racket[#f],
   executes @racket[thunk] and saves the result of @racket[(write-proc (thunk))]
   to @racket[cache-path] for future calls to retrieve.

  For any value @racket[x], calling @racket[(read-proc (write-proc x))] should
   return @racket[x].
  Both @racket[read-proc] and @racket[write-proc] default to identity functions.

}


@section{Parameters}

@defparam[*use-cache?* use-cache? boolean? #:value #t]{
  Parameter for disabling @racket[with-cache].
  When @racket[#f], @racket[with-cache] will not read or write any cachefiles.
}

@defparam[*with-cache-log?* log? boolean? #:value #t]{
  Parameter to disable @racket[with-cache] diagnostic messages.
  When @racket[#f], calls to @racket[with-cache] will not print information
   about files read or written to, or even about errors reading cachefiles.
  (Malformed cachefiles are the same as missing cachefiles.)
}

@defparam[*current-cache-directory* cache-dir boolean? #:value "./compiled"]{
  The value of this parameter is the prefix of paths returned by @racket[cachefile].
  Another good default is @racket[(find-system-path 'temp-dir)].
}

@defparam[*current-cache-keys* params (or/c #f (listof parameter?)) #:value #f]{
  List of parameters (or thunks) to validate cachefiles with.
  When non-@racket[#f], writes by @racket[with-cache] store the value of each
   parameter in the list along with the cached data.
  Reads by @racket[with-cache] assert that the current value of each parameter
   matches the values written to the cachefile.

  For example, @racket[(*current-cache-keys* (list current-seconds))] causes
   @racket[with-cache] to ignore cachefiles written more than 1 second ago.
}


@section{Utilities}

@defproc[(cachefile [filename path-string?]) path-string?]{
  Prefix @racket[filename] with the value of @racket[*current-cache-directory*].
  By contract, this function returns only paths whose parent directory exists.
}
