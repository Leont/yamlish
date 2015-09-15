use v6;

module YAMLish {
	grammar Grammar {
		method parse($, *%) {
			my $*yaml-indent = '';
			my %*yaml-anchors;
			callsame;
		}
		method subparse($, *%) {
			my $*yaml-indent = '';
			my %*yaml-anchors;
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
		token content { <.newline> <map> | <.newline> <list> | <.space>+ <inline> | <.space>+ <block-string> | <.space>+ <plain> }

		token ws {
			<.space>*
			[ [ <!after <.alnum>> <.comment> ]? <.newline> <empty-line> ]*
		}
		token block-ws {
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
			'#' <-[\x0a\x0d]>*
		}
		token line-break {
			<[\x0A\x0D]> | "\x0D\x0A"
		}
		token break {
			<.line-break> | <.space>
		}
		token empty-line {
			<.indent> <.space>*
		}
		token indent {
			$*yaml-indent
		}

		token nb {
			<[\x09\x20..\x10FFFF]>
		}

		token block {
			[ <.newline> | <?after <.newline>> ]
			:my $sp;
			<?before <.indent> $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			<.indent>
			[ <list> | <map> ]
		}

		token map {
			<map-entry>+ % [ <.newline> <.indent> ]
		}
		token map-entry {
			  <key> <.space>* ':' <?break> <.block-ws> <element>
			| '?' <.block-ws> <key=.element> <.newline> <.indent>
			  <.space>* ':' <.space>+ <element>
		}

		token list {
			<list-entry>+ % [ <.newline> <.indent> ]
		}
		token list-entry {
			'-' <?break>
			[
				:my $sp;
				$<sp>=' '+ { $sp = $<sp> }
				:temp $*yaml-indent ~= ' ' ~ $sp;
				[ <element=map> | <element=list> ]
			  ||
				<.block-ws> <element> <.comment>?
			]
		}

		token key {
			| <inline-plain>
			| <single-key>
			| <double-key>
		}
		token plainfirst {
			<-[\-\?\:\,\[\]\{\}\#\&\*\!\|\>\'\"\%\@\`\ \t]>
			| <[\?\:\-]> <!before <.space> | <.line-break>>
		}
		token plain {
			<.plainfirst> [ <-[\x0a\x0d\:]> | ':' <!break> ]*
		}
		regex inline-plain {
			<.plainfirst> : [ <-[\x0a\x0d\:\,\[\]\{\}]> | ':' <!break> ]* <!after <.space>> : <.space>*
		}
		token single-key {
			"'" $<value>=[ [ <-['\x0a]> | "''" ]* ] "'"
		}
		token double-key {
			\" ~ \" [ <str=.quoted-bare> | \\ <str=.quoted-escape> | <str=.space> ]*
		}

		token single-quoted {
			"'" $<value>=[ [ <-[']> | "''" ]* ] "'"
		}
		token double-quoted {
			\" ~ \" [ <str=.quoted-bare> | \\ <str=.quoted-escape> | <str=foldable-whitespace> | <str=space> ]*
		}
		token quoted-bare {
			<-space-["\\\n]>+
		}
		token quoted-escape {
			<["\\/abefnrvtzNLP_\ ]> | x <xdigit>**2 | u <xdigit>**4 | U<xdigit>**8
		}
		token foldable-whitespace {
			<.space>* <.line-break> <.space>*
		}
		token block-string {
			$<kind>=<[|\>]> <.space>* <.comment>? <.line-break>
			:my $sp;
			<?before <.indent> $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			[ <.indent> $<content>=[ \N* ] ]+ % <.line-break>
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
		token inline-map {
			'{' <.ws> <pairlist> <.ws> '}'
		}
		rule pairlist {
			<pair>* % \,
		}
		rule pair {
			<key> ':' [ <inline> || <inline=inline-plain> ]
		}

		token inline-list {
			'[' <.ws> <inline-list-inside> <.ws> ']'
		}
		rule inline-list-inside {
			[ <inline> || <inline=inline-plain> ]* % \,
		}

		token identifier-char {
			<[\x21..\x7E\x85\xA0..\xD7FF\xE000..\xFFFD\x10000..\x10FFFF]-[\,\[\]\{\}]>+
		}
		token identifier {
			<identifier-char>+ <!before <identifier-char> >
		}

		token inline {
			| <int>
			| <hex>
			| <oct>
			| <float>
			| <inf>
			| <nan>
			| <yes>
			| <no>
			| <null>
			| <inline-map>
			| <inline-list>
			| <single-quoted>
			| <double-quoted>
			| <alias>
			| <datetime>
			| <date>
		}

		token int {
			'-'?
			[ 0 | <[1..9]> <[0..9]>* ]
			<|w>
		}
		token hex {
			:i
			'-'?
			'0x'
			$<value>=[ <[0..9A..F]>+ ]
			<|w>
		}
		token oct {
			:i
			'-'?
			'0o'
			$<value>=[ <[0..7]>+ ]
			<|w>
		}
		token float {
			'-'?
			[ 0 | <[1..9]> <[0..9]>* ]
			[ \. <[0..9]>+ ]?
			[ <[eE]> [\+|\-]? <[0..9]>+ ]?
			<|w>
		}
		token inf {
			:i
			$<sign>='-'?
			'.inf'
		}
		token nan {
			:i '.nan'
		}
		token null {
			'~'
		}
		token alias {
			'*' <identifier>
		}
		token datetime {
			$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
			[ ' ' | 'T' ]
			$<hour>=<[0..9]>**2 '-' $<minute>=<[0..9]>**2 '-' $<seconds>=<[0..9]>**2
			$<offset>=[ <[+-]> <[0..9]>**1..2]
		}
		token date {
			$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
		}

		token element {
			   <anchor>? <.block-ws> [ <value=block> | <value=block-string> ]
			|| [ <anchor> <.space>+ ]? <value=inline> <.comment>?
			|| [ <anchor> <.space>+ ]? <value=plain> <.comment>?
		}
		token anchor {
			'&' <identifier>
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
		method space($/) {
			make ~$/;
		}
		method single-quoted($/) {
			make $<value>.Str.subst(/<Grammar::foldable-whitespace>/, ' ', :g).subst("''", "'", :g);
		}
		method single-key($/) {
			make $<value>.Str.subst("''", "'", :g);
		}
		method double-quoted($/) {
			make @<str> == 1 ?? $<str>[0].ast !! @<str>».ast.join;
		}
		method double-key($/) {
			self.double-quoted($/);
		}
		method foldable-whitespace($/) {
			make ' ';
		}
		method plain($/) {
			make ~$/;
		}
		method inline-plain($/) {
			make $/.Str.subst(/ <[\ \t]>+ $/, '');
		}
		method block-string($/) {
			 my $ret = @<content>.map(* ~ "\n").join('');
			 $ret.=subst(/ <[\x0a\x0d]> <!before ' ' | $> /, ' ', :g) if $<kind> eq '>';
			 make $ret;
		}

		method !save($name, $node) {
			%*yaml-anchors{$name} = $node.ast;
		}
		method element($/) {
			make $<value>.ast;
			self!save($<anchor>.ast, $/) if $<anchor>;
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
		method identifier($/) {
			make ~$/;
		}
		method inline-list($/) {
			make $<inline-list-inside>.ast
		}
		method inline-list-inside($/) {
			make [ @<inline>».ast ];
		}

		method inline($/) {
			self!first($/);
		}

		method inf($/) {
			make $<sign> ?? -Inf !! Inf;
		}
		method nan($/) {
			make NaN;
		}
		method yes($/) {
			make True;
		}
		method no($/) {
			make False;
		}
		method int($/) {
			make $/.Str.Int;
		}
		method hex($/) {
			make :16($<value>.Str);
		}
		method oct($/) {
			make :8($<value>.Str);
		}
		method float($/) {
			make +$/.Str;
		}
		method null($/) {
			make Any;
		}
		method alias($/) {
			make %*yaml-anchors{~$<identifier>.ast} // die "Unknown anchor " ~ $<identifier>.ast;
		}
		method datetime($/) {
			make DateTime.new(|$/.hash».Int);
		}
		method date($/) {
			make Date.new(|$/.hash».Int);
		}

		method block($/) { make $/.values.[0].ast }

		method anchor($/) {
			make $<identifier>.ast;
		}

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
				"\n"=> "\n",
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
