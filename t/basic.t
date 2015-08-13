#! perl6

use v6;
use Test;
use YAMLish;

my $text1 = q:heredoc/END/;
---
- 1
-
  - 1
  - 2
-
  foo: bar
  baz: quz
...
END
my $match = load-yaml($text1);
is-deeply($match, [1, [1, 2], {:baz("quz"), :foo("bar")}], "First test matches");



my $text2 = q:heredoc/END/;
---
message: "Board layout"
severity: comment
dump: 
  - '      16G         05C        '
  - '      G N C       C C G      '
  - '        G           C  +     '
  - '10C   01G         03C        '
  - 'R N G G A G       C C C      '
  - '  R     G           C  +     '
  - '      01G   17C   00C        '
  - '      G A G G N R R N R      '
  - '        G     R     G        '
...
END
my $expected2 = {
	message => "Board layout",
	severity => "comment",
	dump => [
		"      16G         05C        ",
		"      G N C       C C G      ",
		"        G           C  +     ",
		"10C   01G         03C        ",
		"R N G G A G       C C C      ",
		"  R     G           C  +     ",
		"      01G   17C   00C        ",
		"      G A G G N R R N R      ",
		"        G     R     G        ",
	],
}
is-deeply(load-yaml($text2), $expected2, "Second test matches");


my $text3 = q:heredoc/END/;
---
User: ed
Fatal: "Unknown variable \"bar\""
Stack:
  - file: TopClass.pl
    line: 23
    code: "x = MoreObject(\"345\n\")"
  -
    file: MoreClass.pl
    line: 58
    code: "foo = bar"
...
END
my $expected3 = {
	Fatal => "Unknown variable \"bar\"",
	Stack => [ 
		{
			file => "TopClass.pl",
			line => 23,
			code => "x = MoreObject(\"345\n\")",
		},
		{
			file => "MoreClass.pl",
			line => 58,
			code => "foo = bar",
		},
	],
	User => "ed",
}
is-deeply(load-yaml($text3), $expected3, "Third test matches");
is-deeply(load-yamls($text3), [ $expected3 ], "Third test matches in multi-doc mode too");

done();
