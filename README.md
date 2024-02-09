[![Build Status](https://travis-ci.org/Leont/yamlish.svg?branch=master)](https://travis-ci.org/Leont/yamlish)

NAME
====

YAMLish - a YAML parser/emitter written in pure raku

DESCRIPTION
===========

This is a YAML parser written in pure-raku. It aims at being feature complete (though there still a few features left to implement). Patches are welcome.

INSTALLATION
============

```console
$ zef install YAMLish
```

EXPORTED SUBS
=============

  * `load-yaml(Str $input, ::Grammar:U :$schema = ::Schema::Core, :%tags)`

  * `load-yamls(Str $input, ::Grammar:U :$schema = ::Schema::Core, :%tags)`

  * `save-yaml($document, :$sorted = True)`

  * `save-yamls(**@documents, :$sorted = True)`
    
  * `debool(Str $input -> Str)`   #quote boolean values (y, Y, yes, Yes, YES and so on)

TODO
====

Please have a look at [TODO.md](TODO.md)

AUTHOR
======

Leon Timmermans

LICENSE
=======

Artistic License 2.0

