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
		token ws { <[\s] - [\n]> }
		token TOP { <multi-doc> | <single-doc> }
		token document {
			<header> <content>
		}
		token multi-doc {
			<document>+
			<.footer>
		}
		token single-doc {
			<.header> <content> <.footer>
			| <content> \n?
		}
		token header { ^^ '---' <ws>* [ $<title>=\N+ ]? \n }
		token footer { \n '...' [ \n | $ ] }
		token content { <map> | <list> }
		regex map {
			<map-element>+ % \n
		}
		token map-element {
			$*yaml-indent <key> <.ws>? ':' <!alpha> <.ws>? <element>
		}
		token key { <bareword> | <string> }
		token bareword { <[\w.-]> +}
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
			<-["\\\t\n]>+
		}
		token quoted-escape {
			<["\\/bfnrt]> | u <xdigit>**4 | U<xdigit>**8
		}

		regex list {
			[ $*yaml-indent '-' <.ws>* <element> ]+ % \n
		}

		proto token element { * };
		token element:sym<number> {
			'-'?
			[ 0 | <[1..9]> <[0..9]>* ]
			[ \. <[0..9]>+ ]?
			[ <[eE]> [\+|\-]? <[0..9]>+ ]?
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

		token element:sym<yes> { <yes> }
		token element:sym<no> { <no> }
		token element:sym<null> { '~' }
		token element:sym<bareword> { <bareword> }
		token element:sym<map> {
			[ \n | <after \n> ]
			:my $sp;
			<before $*yaml-indent $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			<map>
		}
		token element:sym<list> {
			[ \n | <after \n> ]
			:my $sp;
			<?before $*yaml-indent $<sp>=' '+ { $sp = $<sp> }>
			:temp $*yaml-indent ~= $sp;
			<list>
		}
		token element:sym<string> { <string> }
		token element:sym<datetime> {
			$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
			[ ' ' | 'T' ]
			$<hour>=<[0..9]>**2 '-' $<minute>=<[0..9]>**2 '-' $<seconds>=<[0..9]>**2
			$<offset>=[ <[+-]> <[0..9]>**1..2]
		}
	}

	class Actions {
		method single-doc($/) {
			make $<content>.ast;
		}
		method multi-doc($/) {
			make @<document>».ast.hash.item;
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
			make @<map-element>».ast.hash.item;
		}
		method map-element($/) {
			make $<key>.ast => $<element>.ast
		}
		method key($/) {
			make $/.values.[0].ast;
		}
		method list($/) {
			make [ @<element>».ast ]; 
		}
		method string($/) {
			make $/.values.[0].ast;
		}
		method unquoted($/) {
			make ~$<value>;
		}
		method quoted($/) {
			make +@$<str> == 1 ?? $<str>[0].ast !! $<str>».ast.join;
		}
		method bareword($/) {
			make ~$/;
		}
		method element:sym<yes>($/) { make True }
		method element:sym<no>($/) { make False }
		method element:sym<number>($/) { make +$/.Str }
		method element:sym<string>($/) { make $<string>.ast }
		method element:sym<null>($/) { make Any }
		method element:sym<map>($/) { make $<map>.ast }
		method element:sym<list>($/) { make $<list>.ast }
		method element:sym<bareword>($/) { make $<bareword>.ast }
		method element:sym<datetime>($/) {
			make DateTime.new(|$/.hash);
		}

		method quoted-bare ($/) { make ~$/ }

		my %h = '\\' => "\\",
				'/' => "/",
				'b' => "\b",
				'n' => "\n",
				't' => "\t",
				'f' => "\f",
				'r' => "\r",
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
		my $match = Grammar.parse($input, :$actions, :rule('single-doc'));
		return $match ?? $match.ast !! Nil;
	}
	our sub load-yamls(Str $input) is export {
		my $match = Grammar.parse($input, :$actions, :rule('multi-doc'));
		return $match ?? $match.ast !! Nil;
	}

	my $*yaml-indent = '';
	our proto to-yaml($;$ = Str) is export {*}

	multi to-yaml(Real:D $d; $ = Str) { ~$d }
	multi to-yaml(Bool:D $d; $ = Str) { $d ?? 'true' !! 'false'; }
	multi to-yaml(Str:D  $d where /^ <!Grammar::boolean> <[\w.-]>+ $/; $ = Str) {
		return $d;
	}
	multi to-yaml(Str:D  $d; $ = Str) {
		'"'
		~ $d.trans(['"',  '\\',   "\b", "\f", "\n", "\r", "\t"]
				=> ['\"', '\\\\', '\b', '\f', '\n', '\r', '\t'])\
				.subst(/<-[\c32..\c126]>/, {
					$_.Str.encode('utf-16').values».fmt('\u%04x').join
				}, :g)
		~ '"'
	}
	multi to-yaml(Positional:D $d, Str $indent = '') {
		return ($indent ?? "\n" !! '')
				~ $d.flatmap({ to-yaml($_, $indent)}).map("$indent\- " ~ *).join("\n");
	}
	multi to-yaml(Associative:D $d, Str $indent = '') {
		return ($indent ?? "\n" !! '')
				~ $d.flatmap({ $indent ~ to-yaml(.key, $indent) ~ ': ' ~ to-yaml(.value, $indent ~ '  ') }).join("\n")
	}

	multi to-yaml(Mu:U $, $ = Str) { '~' }
	multi to-yaml(Mu:D $s, $ = Str) {
		die "Can't serialize an object of type " ~ $s.WHAT.perl
	}

	proto to-yamls($) is export {*}
	multi to-yamls(Positional:D $documents) {
		$documents.map({ "---\n" ~ to-yaml($_) ~ "\n" }).join('') ~ "...";
	}
	multi to-yamls(Associative:D $documents) {
		$documents.pairs.map({ "--- {.key}\n" ~ to-yaml(.value) ~ "\n" }).join('') ~ "...";
	}
}
