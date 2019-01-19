[![Build Status](https://travis-ci.org/Leont/yamlish.svg?branch=master)](https://travis-ci.org/Leont/yamlish)

NAME
====

YAMLish - a YAML parser/emitter written in pure perl6

DESCRIPTION
===========

This is a YAML parser written in pure-perl6. It aims at being feature complete (though there still a few features left to implement). Patches are welcome.

INSTALLATION
============

```console
$ zef install YAMLish
```

EXPORTED SUBS
=============

  * `load-yaml(Str $input, ::Grammar:U :$schema = ::Schema::Core, :%tags)`

  * `load-yamls(Str $input, ::Grammar:U :$schema = ::Schema::Core, :%tags)`

  * `save-yaml($document)`

  * `save-yamls(**@documents)`

TODO
====

Please have a look at [TODO.md](TODO.md)

AUTHOR
======

Leon Timmermans

LICENSE
=======

Artistic License 2.0

