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
			'%YAML' ' '? <[\d.]>+ <.line-break>
		}
		token TOP {
			<version>?
			[ <header> <content> ]+
			<.footer>
		}
		token header { ^^ '---' }
		token footer { [ <.newline> '...' ]? <.newline>?? $ }
		token content { <.newline> <map> | <.newline> <list> | <.space>+ <inline> | <.space>+ <block-string> }
		token map {
			$*yaml-indent <map-entry>+ % [ <.newline> $*yaml-indent ]
		}
		token cuddly-map {
			 <map-entry>+ % [ <.newline> $*yaml-indent ]
		}

		token ws {
			<.space>*
			[ <!after <.alnum>> <.comment> <.newline> $*yaml-indent <.space>* ]*
		}
		token newline {
			<.space>* <.comment>? <.line-break> [ [ <.space>* <.comment> | <empty-line> ] <.line-break> ]*
		}
		token space {
			<[\ \t]>
		}
		token comment {
			'#' <.non-break>
		}
		token line-break {
			<[\x0A\x0D]> | "\x0D\x0A"
		}
		token empty-line {
			$*yaml-indent <.space>*
		}
		token non-break {
			<-[\x0a\x0d]>*
		}
		}
		token map-entry {
			<key> <.space>* ':' <!alpha> <.ws> <element>
		}
		token key { <bareword> | <string> }
		token bareword { <alpha> <[\w.-]>* }
		token plainfirst {
			<-[-?:,\[\]\{\}\#\&\*\!\|\>\'\"\%\@`\ \t]>
			| <[?:-]> <!before <space>>
		}
		token plain {
			<!before <key> <.space>* ':'> <.plainfirst> <.non-break>
		}
		token string {
			<single-quoted> | <double-quoted>
		}
		token single-quoted {
			"'" $<value>=[ [ <-[']> | "''" ]* ] "'"
		}
		token double-quoted {
			\" ~ \" [ <str=.quoted-bare> | \\ <str=.quoted-escape> ]*
		}
		token quoted-bare {
			<-["\\\n]>+
		}
		token quoted-escape {
			<["\\/abefnrvtzNLP_\ ]> | x <xdigit>**2 | u <xdigit>**4 | U<xdigit>**8
		}

		token list {
			<list-entry>+ % <.newline>
		}
		token list-entry {
			$*yaml-indent '-' <?before <space> | <.line-break>>
			[
				<.ws> <element> <.comment>?
			|
				:my $sp;
				$<sp>=' '+ { $sp = $<sp> }
				:temp $*yaml-indent ~= ' ' ~ $sp;
				<element=cuddly-map>
			]
		}

		token yes {
			[ :i y | yes | true | on ] <|w>
		}
		token no {
			[ :i n | no | false | off ] <|w>
		}
		token boolean {
			<yes> | <no>
		}
		rule inline-map {
			'{' <pairlist> '}'
		}
		rule pairlist {
			<pair>* % \,
		}
		rule pair {
			<key> ':' <inline>
		}

		rule inline-list {
			'[' ~ ']' <inline-list-inside>
		}
		rule inline-list-inside {
			<inline>* % \,
		}

		proto token inline { * }

		token inline:sym<number> {
			'-'?
			[ 0 | <[1..9]> <[0..9]>* ]
			[ \. <[0..9]>+ ]?
			[ <[eE]> [\+|\-]? <[0..9]>+ ]?
			<|w>
		}
		token inline:sym<yes> { <yes> }
		token inline:sym<no> { <no> }
		token inline:sym<null> { '~' }
		token inline:sym<plain> { <plain> }
		token inline:sym<inline-map> { <inline-map> }
		token inline:sym<inline-list> { <inline-list> }
		token inline:sym<string> { <string> }
		token inline:sym<datetime> {
			$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
			[ ' ' | 'T' ]
			$<hour>=<[0..9]>**2 '-' $<minute>=<[0..9]>**2 '-' $<seconds>=<[0..9]>**2
			$<offset>=[ <[+-]> <[0..9]>**1..2]
		}
		token inline:sym<date> {
			$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
		}

		token element { <inline> <comment>? | <block> | <block-string> }

		token block {
			[ <.newline> | <?after <.newline>> ]
			:my $sp;
			<?before $*yaml-indent $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			[ <list> | <map> ]
		}
		token block-string {
			$<kind>=<[|\>]> <.space>* <.comment>? <.line-break>
			:my $sp;
			<?before $*yaml-indent $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			[ $*yaml-indent $<content>=[ \N* ] ]+ % <.line-break>
		}
	}

	class Actions {
		method TOP($/) {
			make [ @<content>».ast ];
		}
		method !first($/) {
			make $/.values.[0].ast;
		}
		method document($/) {
			make $<header>.ast => $<content>.ast;
		}
		method content($/) {
			self!first($/);
		}
		method map($/) {
			make @<map-entry>».ast.hash.item;
		}
		method map-entry($/) {
			make $<key>.ast => $<element>.ast
		}
		method cuddly-map($/) {
			self.map($/);
		}
		method key($/) {
			self!first($/);
		}
		method list($/) {
			make [ @<list-entry>».ast ];
		}
		method list-entry($/) {
			make $<element>.ast;
		}
		method string($/) {
			self!first($/);
		}
		method single-quoted($/) {
			make $<value>.Str.subst("''", "'", :g);
		}
		method double-quoted($/) {
			make @<str> == 1 ?? $<str>[0].ast !! @<str>».ast.join;
		}
		method bareword($/) {
			make ~$/;
		}
		method plain($/) {
			make ~$/;
		}
		method block-string($/) {
			 my $ret = @<content>.map(* ~ "\n").join('');
			 $ret.=subst(/ <[\x0a\x0d]> <!before ' ' | $> /, ' ', :g) if $<kind> eq '>';
			 make $ret;
		}
		method element($/) {
			self!first($/);
		}

		method inline-map($/) {
			make $<pairlist>.ast;
		}
		method pairlist($/) {
			make $<pair>».ast.hash.item;
		}
		method pair($/) {
			make $<key>.ast => $<inline>.ast;
		}

		method inline-list($/) {
			make $<inline-list-inside>.ast
		}
		method inline-list-inside($/) {
			make [ @<inline>».ast ];
		}

		method inline:sym<yes>($/) { make True }
		method inline:sym<no>($/) { make False }
		method inline:sym<number>($/) { make +$/.Str }
		method inline:sym<string>($/) { make $<string>.ast }
		method inline:sym<null>($/) { make Any }
		method inline:sym<inline-map>($/) { make $<inline-map>.ast }
		method inline:sym<inline-list>($/) { make $<inline-list>.ast }
		method inline:sym<plain>($/) { make $<plain>.ast }
		method inline:sym<bareword>($/) { make $<bareword>.ast }
		method inline:sym<datetime>($/) { make DateTime.new(|$/.hash».Int)}
		method inline:sym<date>($/) { make Date.new(|$/.hash».Int)}

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
				'"' => "\"",
				' ' => ' ',
				'N' => "\x85",
				'_' => "\xA0",
				'L' => "\x2028",
				'P' => "\x2029";
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
		return $match ?? $match.ast[0] !! fail "Couldn't parse YAML";
	}
	our sub load-yamls(Str $input) is export {
		my $match = Grammar.parse($input, :$actions);
		return $match ?? $match.ast !! fail "Couldn't parse YAML";
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
	sub save-yamls(**@documents --> Str) is export {
		@documents.map(&to-yaml-doc).join('') ~ "...";
	}
}
