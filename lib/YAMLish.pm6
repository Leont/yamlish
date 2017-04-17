use v6;

unit module YAMLish;

grammar Grammar {
	my $yaml-namespace = 'tag:yaml.org,2002:';
	token TOP {
		<.document-prefix>?
		[
		| <document=directive-document>
		| <document=explicit-document>
		| <document=simple-document>
		]
		[
		| <.document-suffix>+ <.document-prefix>* <document=any-document>?
		| <.document-prefix>* <document=explicit-document>
		]*
	}
	token document-prefix {
		<.bom>? <.comment-line>* <?{ $/.chars > 0 }>
	}
	token bom {
		"\x[FEFF]"
	}
	token comment-line {
		<.space>* <.comment> <.line-end>
	}
	token line-end {
		<line-break> | $
	}
	token document-suffix {
		<.document-end> <.comment>? <.line-end> <.comment-line>*
	}
	token any-document {
		| <directive-document>
		| <explicit-document>
		| <bare-document>
	}
	token directive-document {
		<directives>
		{  }
		:my %*yaml-prefix = %( $<directives>.ast<tags> );
		<explicit-document>
	}
	token directives {
		[ '%' [ <yaml-directive> | <tag-directive> ] <.space>* <.line-break> ]+
	}
	token yaml-directive {
		'YAML' <.space>+ $<version>=[ <[0..9]>+ \. <[0..9]>+ ]
	}
	token tag-directive {
		'TAG' <.space>+ <tag-handle> <.space>+ <tag-prefix>
	}
	token tag-prefix {
		| '!' <.uri-char>+
		| <.tag-char> <.uri-char>*
	}
	token explicit-document	{
		<.directives-end>
		[
		| <document=bare-document>
		| <document=empty-document>
		]
	}
	token empty-document {
		<.comment-line>* <?before <document-suffix> | <document-prefix> | $>
	}
	token directives-end {
		'---'
	}
	token document-end {
		'...'
	}
	token bare-document {
		[
		| <.newline> <!before '---' | '...'> <map('')>
		| <.newline> <yamllist('')>
		| <.begin-space> <inline>
		| <.begin-space> <block-string('')>
		| <.begin-space> <!before '---' | '...'> <plain>
		]
		<.line-end>
	}
	token simple-document {
		<!before '---' | '...'>
		[
		| <map('')>
		| <yamllist('')>
		| <inline>
		| <block-string('')>
		| <plain>
		]
		<.line-end>
	}
	token begin-space {
		<?before <break>> <.ws>
	}

	token ws {
		<.space>*
		[ [ <!after <.alnum>> <.comment> ]? <.line-break> <.space>* ]*
	}
	token block-ws(Str $indent) {
		<.space>*
		[ <!after <.alnum>> <.comment> <.line-break> $indent <.space>* ]*
	}
	token newline {
		[ <.space>* <.comment>? <.line-break> ]+
	}
	token space {
		<[\ \t]>
	}
	token comment {
		'#' <-line-break>*
	}
	token line-break {
		<[ \c[LF] \r \r\c[LF]] >
	}
	token break {
		<.line-break> | <.space>
	}

	token nb {
		<[\x09\x20..\x10FFFF]>
	}

	token block(Str $indent, Int $minimum-indent) {
		<properties>?
		<.newline>
		:my $new-indent;
		<?before $indent $<sp>=[' ' ** { $minimum-indent..* } ] { $new-indent = $indent ~ $<sp> }>
		$new-indent
		[ <value=yamllist($new-indent)> | <value=map($new-indent)> ]
	}

	token map(Str $indent) {
		<map-entry($indent)>+ % [ <.newline> $indent ]
	}
	token map-entry(Str $indent) {
		  <key> <.space>* ':' <?break> <.block-ws($indent)> <element($indent, 0)>
		| '?' <.block-ws($indent)> <key=.element($indent, 0)> <.newline> $indent
		  <.space>* ':' <.space>+ <element($indent, 0)>
	}

	token yamllist(Str $indent) {
		<list-entry($indent)>+ % [ <.newline> $indent ]
	}
	token list-entry(Str $indent) {
		'-' <?break>
		[
		  || <element=cuddly-list-entry($indent)>
		  || <.block-ws($indent)> <element($indent, 1)> <.comment>?
		]
	}
	token cuddly-list-entry(Str $indent) {
		:my $new-indent;
		$<sp>=' '+ { $new-indent = $indent ~ ' ' ~ $<sp> }
		[ <element=map($new-indent)> | <element=yamllist($new-indent)> ]
	}

	token key {
		| <inline-plain>
		| <single-key>
		| <double-key>
	}
	token plainfirst {
		<-[\-\?\:\,\[\]\{\}\#\&\*\!\|\>\'\"\%\@\`\ \t\x0a\x0d]>
		| <[\?\:\-]> <!before <.space> | <.line-break>>
	}
	token plain {
		<properties>?
		<.plainfirst> [ <-[\x0a\x0d\:]> | ':' <!break> ]*
	}
	regex inline-plain {
		$<value> = [
			<.plainfirst> :
			[ <-[\x0a\x0d\:\,\[\]\{\}]> | ':' <!break> ]*
			<!after <.space>> :
		]
		<.space>*
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
		<-space-[\"\\\n]>+
	}
	token quoted-escape {
		<["\\/abefnrvtzNLP_\ ]> | x <xdigit>**2 | u <xdigit>**4 | U<xdigit>**8
	}
	token foldable-whitespace {
		<.space>* <.line-break> <.space>*
	}
	token block-string(Str $indent) {
		<properties>?
		$<kind>=<[\|\>]> <.space>*
		<.comment>? <.line-break>
		:my $new-indent;
		<?before $indent $<sp>=' '+ { $new-indent = $indent ~ $<sp> }>
		[ $new-indent $<content>=[ \N* ] ]+ % <.line-break>
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
		<pair>* %% \,
	}
	rule pair {
		<key> ':' [ <inline> || <inline=inline-plain> ]
	}

	token inline-list {
		'[' <.ws> <inline-list-inside> <.ws> ']'
	}
	rule inline-list-inside {
		[ <inline> || <inline=inline-plain> ]* %% \,
	}

	token identifier-char {
		<[\x21..\x7E\x85\xA0..\xD7FF\xE000..\xFFFD\x10000..\x10FFFF]-[\,\[\]\{\}]>+
	}
	token identifier {
		<identifier-char>+ <!before <identifier-char> >
	}

	token inline-atom {
		[
		| <value=int>
		| <value=hex>
		| <value=oct>
		| <value=rat>
		| <value=float>
		| <value=inf>
		| <value=nan>
		| <value=yes>
		| <value=no>
		| <value=null>
		| <value=alias>
		| <value=datetime>
		| <value=date>
		]
	}

	token inline {
		<properties>?

		[
		| <value=inline-atom>
		| <value=inline-map>
		| <value=inline-list>
		| <value=single-quoted>
		| <value=double-quoted>
		]
	}

	token properties {
		| <anchor> <.space>+ [ <tag> <.space>+ ]?
		| <tag> <.space>+ [ <anchor> <.space>+ ]?
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
	token rat {
		'-'?
		[ 0 | <[1..9]> <[0..9]>* ]
		\. <[0..9]>+
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

	token element(Str $indent, Int $minimum-indent) {
		[  [ <value=block($indent, $minimum-indent)> | <value=block-string($indent)> ]
		|  <value=inline> <.comment>?
		|| <value=plain> <.comment>?
		]
	}
	token anchor {
		'&' <identifier>
	}

	token tag {
		| <value=verbatim-tag>
		| <value=shorthand-tag>
		| <value=non-specific-tag>
	}

	token verbatim-tag {
		'!<' <uri-char>+ '>'
	}
	token uri-char {
		<char=uri-escaped-char> | <char=uri-real-char>
	}
	token uri-escaped-char {
		:i '%' $<hex>=<[ 0..9 A..F ]>**2
	}
	token uri-real-char {
		<[ 0..9 A..Z a..z \-#;/?:@&=+$,_.!~*'()\[\] ]>
	}

	token shorthand-tag {
		<tag-handle> $<tag-name>=[ <tag-char>+ ]
	}
	token tag-handle {
		'!' [ <[ A..Z a..z 0..9 ]>* '!' ]?
	}
	token tag-real-char {
		<[ 0..9 A..Z a..z \-#;/?:@&=+$_.~*'() ]>
	}
	token tag-char {
		[ <char=uri-escaped-char> | <char=tag-real-char> ]
	}

	token non-specific-tag {
		'!'
	}

	class Actions {
		method TOP($/) {
			make ( @<document>».ast );
		}
		method !first($/) {
			make $/.values.[0].ast;
		}
		method any-document($/) {
			self!first($/);
		}
		method directive-document($/) {
			make $<explicit-document>.ast;
		}
		method directives($/) {
			my %tags = @<tag-directive>».ast;
			my $version = $<version-directive>.ast // 1.2;
			make { :%tags, :$version };
		}
		method tag-directive($/) {
			make ~$<tag-handle> => ~$<tag-prefix>
		}
		method explicit-document($/) {
			make $<document>.ast;
		}
		method bare-document($/) {
			self!first($/);
		}
		method simple-document($/) {
			self!first($/);
		}
		method empty-document($/) {
			make Any;
		}
		method map($/) {
			make @<map-entry>».ast.hash;
		}
		method map-entry($/) {
			make $<key>.ast => $<element>.ast
		}
		method key($/) {
			self!first($/);
		}
		method yamllist($/) {
			make @<list-entry>».ast.list;
		}
		method list-entry($/) {
			make $<element>.ast;
		}
		method cuddly-list-entry($/) {
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
			make self!handle_properties($<properties>, $/, ~$/);
		}
		method inline-plain($/) {
			make ~$<value>
		}
		method block-string($/) {
			my $ret = $<content>.map(* ~ "\n").join('');
			if $<kind> eq '>' {
				my $/;
				$ret.=subst(/ <[\x0a\x0d]> <!before ' ' | $> /, ' ', :g);
			}
			make self!handle_properties($<properties>, $/, $ret);
		}

		method !save($name, $value) {
			%*yaml-anchors{$name} = $value;
		}
		method element($/) {
			make $<value>.ast;
		}

		method inline-map($/) {
			make $<pairlist>.ast.hash;
		}
		method pairlist($/) {
			make @<pair>».ast.list;
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
			make @<inline>».ast.list;
		}
		method inline-atom($/) {
			make $<value>.ast;
		}
		method inline($/) {
			make self!handle_properties($<properties>, $<value>);
		}

		method !decode_value($properties, $ast, $value) {
			if $properties<tag> -> $tag {
				return $value if $tag.ast eq '!';
				my &resolve = %*yaml-tags{$tag.ast} // return die "Unknown tag { $tag.ast }";
				return resolve($ast, $value);
			}
			return $value;
		}
		method !handle_properties($properties, $ast, $original-value = $ast.ast) {
			return $original-value if not $properties;
			my $value = self!decode_value($properties, $ast, $original-value);
			self!save($properties<anchor>.ast, $value) if $properties<anchor>;
			return $value;
		}
		method tag($/) {
			make $<value>.ast;
		}
		method verbatim-tag($/) {
			make @<uri-char>».ast.join('');
		}
		method uri-char($/) {
			make $<char>;
		}
		method uri-real-char($/) {
			make ~$/;
		}
		method uri-escaped-char($/) {
			:16(~$<hex>);
		}
		method !lookup-namespace($name) {
			return %*yaml-prefix{$name} // do given $name {
				when '!' {
					'!';
				}
				when '!!' {
					$yaml-namespace;
				}
				default {
					die "No such prefix $name known: " ~ %*yaml-prefix.keys.join(", ");
				}
			}
		}
		method shorthand-tag($/) {
			make self!lookup-namespace($<tag-handle>.ast) ~ ~$<tag-name>;
		}
		method tag-handle($/) {
			make ~$/;
		}
		method non-specific-tag {
			make '!';
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
			make :16(~$<value>);
		}
		method oct($/) {
			make :8(~$<value>);
		}
		method rat($/) {
			make $/.Rat;
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

		method block($/) {
			make self!handle_properties($<properties>, $<value>);
		}

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

	my %yaml-tags = (
		$yaml-namespace => {
			str => sub ($ast, $value) {
				given $value {
					when Str {
						return $value;
					}
					when Bool|Numeric|Date|DateTime|*.defined.not {
						return ~$ast;
					}
					when Positional|Associative {
						die "Couldn't convert collection into string";
					}
					default {
						die "Couldn't resolve { $value.WHAT } to string";
					}
				}
			},
			int => sub ($, $value) {
				given $value {
					when Numeric|Str|Bool {
						return $value.Int;
					}
					default {
						die "Couldn't resolve a { $value.WHAT } to integer";
					}
				}
			},
			float => sub ($, $value) {
				given $value {
					when Rat|Num {
						return $value;
					}
					when Int|Str {
						return $value.Rat;
					}
					default {
						die "Couldn't resolve a { $value.WHAT } to float";
					}
				}
			},
			null => sub ($, $value) {
				return Any;
			},
			binary => sub ($, $value) {
				require MIME::Base64;
				return MIME::Base64.decode($value.subst(/<[\ \t\n]>/, '', :g)) if $value ~~ Str;
				die "Binary has to be a string";
			},
			seq => sub ($, $value) {
				return $value if $value ~~ Iterable;
				die "Could not convert { $value.WHAT } to a sequence";
			},
			map => sub ($, $value) {
				return $value if $value ~~ Associative;
				die "Could not convert { $value.WHAT } to am Associative";
			},
			set => sub ($ast, $value) {
				return $value.keys.set if $value ~~ Associative;
				die "Could not convert { $value.WHAT } to a set";
			},
			omap => sub ($ast, $value) {
				die "Ordered maps not implemented yet"
			},
		},
	);
	my sub flatten-tags(%tags) {
		return %tags.kv.map({ |$^value.kv.map($^namespace ~ * => *) } );
	}
	my %default-tags = flatten-tags(%yaml-tags);
	method parse($string, :%tags, *%args) {
		my %*yaml-anchors;
		my %*yaml-tags = |%default-tags, |flatten-tags(%tags);
		my $*yaml-version = 1.2;
		my %*yaml-prefix;
		nextwith($string, :actions(Actions), |%args);
	}
	method subparse($string, :%tags, *%args) {
		my %*yaml-anchors;
		my %*yaml-tags = |%default-tags, |flatten-tags(%tags);
		my $*yaml-version = 1.2;
		my %*yaml-prefix;
		nextwith($string, :actions(Actions), |%args);
	}
}

our sub load-yaml(Str $input) is export {
	my $match = Grammar.parse($input);
	return $match ?? $match.ast[0] !! fail "Couldn't parse YAML";
}
our sub load-yamls(Str $input) is export {
	my $match = Grammar.parse($input);
	return $match ?? $match.ast !! fail "Couldn't parse YAML";
}

proto to-yaml($;$ = Str) {*}

multi to-yaml(Real:D $d; $ = Str) { ~$d }
multi to-yaml(Bool:D $d; $ = Str) { $d ?? 'true' !! 'false'; }
multi to-yaml(Str:D  $d where /^ <!Grammar::inline-atom> <[\w.-]>+ $/; $ = Str) {
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
	return ' []' unless $d.elems;
	return "\n" ~ $d.map({ "$indent\- " ~ to-yaml($_, $indent ~ '  ') }).join("\n");
}
multi to-yaml(Associative:D $d, Str $indent) {
	return ' {}' unless $d.elems;
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
