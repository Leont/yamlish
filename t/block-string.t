#! perl6

use v6;
use Test;
use YAMLish;

is-deeply
	load-yaml(qq:to/END/),
		- foo: |
		    The following line has no spaces

		    And the following has two, not four
		\x20\x20
		    The following has six, so resulting text should have two left in it
		\x20\x20\x20\x20\x20\x20
		    And that's all, folks!
		\x20\x20

		- bar
		END
	[{foo => qq:to/END/}, 'bar'],
		The following line has no spaces

		And the following has two, not four

		The following has six, so resulting text should have two left in it
		\x20\x20
		And that's all, folks!
		END
	"Blank lines in block strings";

is-deeply
	load-yaml("x: |\n  a\n\n  b\n\n\n"),
	{ x => "a\n\nb\n" },
	"Clip trailing newlines";

is-deeply
	load-yaml("x: |+\n  a\n\n  b\n\n\n"),
	{ x => "a\n\nb\n\n\n" },
	"Keep trailing newlines";

is-deeply
	load-yaml("x: |-\n  a\n\n  b\n\n\n"),
	{ x => "a\n\nb" },
	"Strip trailing newlines";

is-deeply
	load-yaml("x: |\n  \n  \n  a\n\n  b\n"),
	{ x => "\n\na\n\nb\n" },
	"Leading blank lines with matching indent";

is-deeply
	load-yaml("x: |\n\n \n  a\n\n  b\n"),
	{ x => "\n\na\n\nb\n" },
	"Leading blank lines with lesser indent";

dies-ok
	{ load-yaml("x: |\n\n   \n  a\n\n  b\n") },
	"Leading blank lines with too much indent";

is-deeply
	load-yaml("x: |\n\n  \t\n  a\n\n  b\n"),
	{ x => "\n\t\na\n\nb\n" },
	"Leading blank lines with tab after indent";

is-deeply
	load-yaml("foo: a\nbar: |+\nbaz: c\n"),
	{ :foo<a>, :bar(''), :baz<c> },
	"Zero-line block-string";

is-deeply
	load-yaml("foo: a\nbar: |+\n"),
	{ :foo<a>, :bar('') },
	"Zero-line block-string at end of doc";

is-deeply
	load-yaml("foo: a\nbar: |+"),
	{ :foo<a>, :bar('') },
	"Zero-line block-string at end of doc (no newline)";

is-deeply
	load-yaml("foo: a\nbar: |\n\n \nbaz: c\n"),
	{ :foo<a>, :bar("\n"), :baz<c> },
	"Only-blank-lines block-string";

is-deeply
	load-yaml("foo: a\nbar: |+\n  \n \nbaz: c\n"),
	{ :foo<a>, :bar("\n\n"), :baz<c> },
	"Only-blank-lines block-string (keep)";

is-deeply
	load-yaml("foo: a\nbar: |+\n  \n "),
	{ :foo<a>, :bar("\n\n") },
	"Only-blank-lines at end of doc (keep)";

is-deeply
	load-yaml("foo: a\nbar: |+2\n  \n    \n   starting space\n    \n\nbaz: c\n"),
	{ :foo<a>, :bar("\n  \n starting space\n  \n\n"), :baz<c> },
	"Explicit indentation level";

is-deeply
	load-yaml("foo: a\nbar: |3\n  \n    \n   starting space\n    \n\nbaz: c\n"),
	{ :foo<a>, :bar("\n \nstarting space\n \n"), :baz<c> },
	"Explicit indentation level (chop)";

dies-ok
	{ load-yaml("foo: a\nbar: |0\nxyz\nbaz: c\n") },
	"Explicit indentation level can't be zero";

is-deeply
	load-yaml(qq:to/END/),
		top:
		  - foo:   a
		    bar:  |
		     z
		    baz:      c
		  - |

		   x
		END
	{ top => [
		{ :foo<a>, :bar("z\n"), :baz<c> },
		"\nx\n",
	], },
	"Nested inside a list";

is-deeply
	load-yaml(qq:to/END/),
		top:
		  - |1
		   x
		END
	{ top => [
		"x\n",
	], },
	"Nested with explicit indentation";

done-testing();
