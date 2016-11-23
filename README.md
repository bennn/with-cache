with-cache
===
[![Build Status](https://travis-ci.org/bennn/with-cache.svg)](https://travis-ci.org/bennn/with-cache)
[![Coverage Status](https://coveralls.io/repos/bennn/with-cache/badge.svg?branch=master&service=github)](https://coveralls.io/github/bennn/with-cache?branch=master)
[![Scribble](https://img.shields.io/badge/Docs-Scribble-blue.svg)](http://docs.racket-lang.org/with-cache/index.html)

Simple, filesystem-based caching.

0. Pick a directory to store caches in.
   By default, it's the `./compiled/with-cache` directory.
1. Wrap "expensive" computations in a thunk, call the thunk via `with-cache`.
2. Results of the expensive computation are automatically stored and retrieved.

Example:
```
(with-cache "fact42.rktd"
  (λ () (factorial 42)))
(with-cache "pict.rktd"
  (λ () (standard-fish 100 50))
  #:read deserialize
  #:write serialize)
```


Install
---

From the Racket [package server](pkgs.racket-lang.org):

```
$ raco pkg install with-cache
```

From Github:

```
$ git clone https://github.com/bennn/with-cache
$ raco pkg install ./with-cache
```

Don't forget the `./`!


More
---

The real documentation is here:
http://docs.racket-lang.org/with-cache/index.html

and has instructions for:
- invalidating cachefiles
- changing the default cache directory
- cachefile naming conventions

