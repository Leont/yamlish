use v6;

module YAMLish {
	grammar Grammar {
		method parse($, *%) {
			my $*yaml-indent = '';
			callsame;
		}
		method subparse($, *%) {
			my $*yaml-indent = '';
			callsame;
		}
		token version {
			'%YAML' ' '? <[\d.]>+ \n
		}
		token ws { <[\s] - [\n]> }
		token TOP {
			<version>?
			[ <header> <content> ]+
			<.footer>
		}
		token header { ^^ '---' }
		token footer { [ \n '...' ]? \n? $ }
		token content { \n <map> | \n <list> | ' '+ <inline> }
		token map {
			$*yaml-indent <map-entry>+ % [ \n $*yaml-indent ]
		}
		token inline-map {
			 <map-entry>+ % [ \n $*yaml-indent ]
		}
		token map-entry {
			<key> <.ws>? ':' <!alpha> <.ws>? <element>
		}
		token key { <bareword> | <string> }
		token bareword { <alpha> <[\w.-]>* }
		token string {
			<unquoted> | <quoted>
		}

		token unquoted {
			"'" $<value>=[ <-[\\']>+ ] "'"
		}
		token quoted {
			\" ~ \" [ <str=.quoted-bare> | \\ <str=.quoted-escape> ]*
		}
		token quoted-bare {
			<-["\\\n]>+
		}
		token quoted-escape {
			<["\\/abefnrvtz]> | x <xdigit>**2 | u <xdigit>**4 | U<xdigit>**8
		}

		token list {
			<list-entry>+ % \n
		}
		token list-entry {
			$*yaml-indent '-'
			[
				<.ws>* <element>
			|
				:my $sp;
				$<sp>=' '+ { $sp = $<sp> }
				:temp $*yaml-indent ~= ' ' ~ $sp;
				<element=inline-map>
			]
		}

		token yes {
			:i y | yes | true | on
		}
		token no {
			:i n | no | false | off
		}
		token boolean {
			<yes> | <no>
		}

		proto token inline { * }

		token inline:sym<number> {
			'-'?
			[ 0 | <[1..9]> <[0..9]>* ]
			[ \. <[0..9]>+ ]?
			[ <[eE]> [\+|\-]? <[0..9]>+ ]?
		}
		token inline:sym<yes> { <yes> }
		token inline:sym<no> { <no> }
		token inline:sym<null> { '~' }
		token inline:sym<bareword> { <bareword> <!before ':'> }
		token inline:sym<empty-map> { '{}' }
		token inline:sym<empty-list> { '[]' }
		token inline:sym<string> { <string> }
		token inline:sym<datetime> {
			$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
			[ ' ' | 'T' ]
			$<hour>=<[0..9]>**2 '-' $<minute>=<[0..9]>**2 '-' $<seconds>=<[0..9]>**2
			$<offset>=[ <[+-]> <[0..9]>**1..2]
		}

		token element { <inline> | <block> }

		token block {
			[ \n | <after \n> ]
			:my $sp;
			<before $*yaml-indent $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			[ <list> | <map> ]
		}
	}

	class Actions {
		method TOP($/) {
			make [ @<content>».ast ];
		}
		method document($/) {
			make $<header>.ast => $<content>.ast;
		}
		method header($/) {
			make $<title>.defined ?? ~$<title> !! Nil;
		}
		method content($/) {
			make $/.values.[0].ast;
		}
		method map($/) {
			make @<map-entry>».ast.hash.item;
		}
		method map-entry($/) {
			make $<key>.ast => $<element>.ast
		}
		method inline-map($/) {
			self.map($/);
		}
		method key($/) {
			make $/.values.[0].ast;
		}
		method list($/) {
			make [ @<list-entry>».ast ];
		}
		method list-entry($/) {
			make $<element>.ast;
		}
		method string($/) {
			make $/.values.[0].ast;
		}
		method unquoted($/) {
			make ~$<value>;
		}
		method quoted($/) {
			make @<str> == 1 ?? $<str>[0].ast !! @<str>».ast.join;
		}
		method bareword($/) {
			make ~$/;
		}
		method element($/) {
			make $/.values.[0].ast;
		}
		method inline:sym<yes>($/) { make True }
		method inline:sym<no>($/) { make False }
		method inline:sym<number>($/) { make +$/.Str }
		method inline:sym<string>($/) { make $<string>.ast }
		method inline:sym<null>($/) { make Any }
		method inline:sym<empty-map>($/) { make {} }
		method inline:sym<empty-list>($/) { make [] }
		method inline:sym<bareword>($/) { make $<bareword>.ast }
		method inline:sym<datetime>($/) { make DateTime.new(|$/.hash)}

		method block($/) { make $/.values.[0].ast }

		method quoted-bare ($/) { make ~$/ }

		my %h = '\\' => "\\",
				'/' => "/",
				'a' => "\a",
				'b' => "\b",
				'e' => "\e",
				'n' => "\n",
				't' => "\t",
				'f' => "\f",
				'r' => "\r",
				'v' => "\x0b",
				'z' => "\0",
				'"' => "\"";
		method quoted-escape($/) {
			if $<xdigit> {
				make chr(:16($<xdigit>.join));
			} else {
				make %h{~$/};
			}
		}
	}

	my $parser = Grammar.new;
	my $actions = Actions.new;

	our sub load-yaml(Str $input) is export {
		my $match = Grammar.parse($input, :$actions);
		return $match ?? $match.ast[0] !! Nil;
	}
	our sub load-yamls(Str $input) is export {
		my $match = Grammar.parse($input, :$actions);
		return $match ?? $match.ast !! Nil;
	}

	proto to-yaml($;$ = Str) {*}

	multi to-yaml(Real:D $d; $ = Str) { ~$d }
	multi to-yaml(Bool:D $d; $ = Str) { $d ?? 'true' !! 'false'; }
	multi to-yaml(Str:D  $d where /^ <!Grammar::boolean> <[\w.-]>+ $/; $ = Str) {
		return $d;
	}
	multi to-yaml(Str:D  $d; $) {
		'"'
		~ $d.trans(['"',  '\\',   "\b", "\f", "\n", "\r", "\t"]
				=> ['\"', '\\\\', '\b', '\f', '\n', '\r', '\t'])\
				.subst(/<-[\c9\xA\xD\x20..\x7E\xA0..\xD7FF\xE000..\xFFFD\x10000..\x10FFFF]>/, {
					given .ord { $_ > 0xFFFF ?? .fmt("\\U%08x") !! $_ > 0xFF ?? .fmt("\\u%04x") !! .fmt("\\x%02x") }
				}, :g)
		~ '"'
	}
	multi to-yaml(Positional:D $d, Str $indent) {
		return "\n" ~ $d.map({ "$indent\- " ~ to-yaml($_, $indent ~ '  ') }).join("\n");
	}
	multi to-yaml(Associative:D $d, Str $indent) {
		return "\n" ~ $d.map({ $indent ~ to-yaml(.key, $indent) ~ ': ' ~ to-yaml(.value, $indent ~ '  ') }).join("\n")
	}

	multi to-yaml(Mu:U $, $) { '~' }
	multi to-yaml(Mu:D $s, $) {
		die "Can't serialize an object of type " ~ $s.WHAT.perl
	}

	subset Collection where Positional|Associative;

	proto to-yaml-doc($) { * }
	multi to-yaml-doc(Collection $document) {
		return '---' ~ to-yaml($document, '') ~ "\n";
	}
	multi to-yaml-doc(Any $document) {
		return '--- ' ~ to-yaml($document, '') ~ "\n";
	}

	sub save-yaml($document --> Str) is export {
		to-yaml-doc($document) ~ "...";
	}
	sub save-yamls(*@documents --> Str) is export {
		@documents.map(&to-yaml-doc).join('') ~ "...";
	}
}
