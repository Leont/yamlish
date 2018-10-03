use v6;

unit module YAMLish;

my $yaml-namespace = 'tag:yaml.org,2002:';

class Namespace {
	has Str %.prefixes;
	method lookup(Str $name) {
		return %!prefixes{$name} // do given $name {
			when '!' {
				'!';
			}
			when '!!' {
				$yaml-namespace;
			}
			default {
				die "No such prefix $name known: " ~ %!prefixes.keys.join(", ");
			}
		}
	}
}

role Tag {
	method full-name(Namespace $namespace) { ... }
}

class ShortHandTag does Tag {
	has Str:D $.namespace is required;
	has Str:D $.local is required;
	method full-name(Namespace $namespace) {
		return $namespace.lookup($!namespace) ~ $!local;
	}
}

class VerbatimTag does Tag {
	has Str:D $.url is required;
	method full-name(Namespace $namespace) {
		return $!url;
	}
}

class NonSpecificTag does Tag {
	has Bool:D $.resolved is required;
	method concretize() {
	}
	method full-name(Namespace $) {
		return $!resolved ?? '!' !! '?';
	}
}

role Element {
	has Tag:D $.tag is required;
	method concretize($, $, %) { ... }
}

my $resolved = NonSpecificTag.new(:resolved);
my $unresolved = NonSpecificTag.new(:!resolved);

class Single does Element {
	has Str:D $.value is required;
	has Str:D $.type is required;
	method concretize($schema, $namespaces, %callbacks) {
		my $full-name = $!tag.full-name($namespaces);
		if $full-name eq '!' {
			return $!value;
		}
		elsif $full-name eq '?' {
			my $match = $schema.new.parse($!value);
			return $match ?? $match.ast !! die "Invalid value $!value";
		}
		else {
			return %callbacks{$full-name}($!value);
		}
	}
}

class Mapping does Element {
	has Pair @.elems;
	submethod BUILD(:@!elems, :$!tag = $unresolved) {}
	method concretize($schema, $namespaces, %callbacks) {
		my @pairs := @.elems.map({ .key.concretize($schema, $namespaces, %callbacks) => .value.concretize($schema, $namespaces, %callbacks)}).list;
		if $!tag ~~ NonSpecificTag {
			return @pairs.hash;
		}
		else {
			my $full-name = $!tag.full-name($namespaces);
			return %callbacks{$full-name}(@pairs);
		}
	}
}

class Sequence does Element {
	has Element @.elems;
	submethod BUILD(:@!elems, :$!tag = $unresolved) {}
	method concretize($schema, $namespaces, %callbacks) {
		my @pairs := @.elems.map(*.concretize($schema, $namespaces, %callbacks)).list;
		if $!tag ~~ NonSpecificTag {
			return @pairs;
		}
		else {
			my $full-name = $!tag.full-name($namespaces);
			return %callbacks{$full-name}(@pairs);
		}
	}
}

my $default-version = 1.2;
class Document {
	has Rat:D $.version = $default-version;
	has Element:D $.root is required;
	has Namespace:D $.namespace = Namespace.new;
	has Bool:D $.explicit is required;
	method concretize($schema, %callbacks) {
		return $!root.concretize($schema, $!namespace, %callbacks);
	}
}

grammar Grammar {
	method indent-panic($/, $indent, $what) {
		my ($line-num, $column) := self.line-column($/);
		die "Problem with indentatiton in $what at {$line-num}:{$column}."
	}

	method line-column($/) {
		my $c = $/;
		my @lines-so-far = $/.orig.substr(0, $c.from).lines;
		my $line-num = +@lines-so-far;
		my $column   = @lines-so-far.tail.chars;
		return ($line-num, $column);
	}

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
		<explicit-document>
	}
	token directives {
		[ '%' [ <version=yaml-directive> | <tags=tag-directive> ] <.space>* <.line-break> ]+
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
		[ <.newline> | <.space>* <.comment> ]
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
		[ <.newline> | <.space>* <.comment> ]?
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
		[ <.newline> $indent \s+ <wrongkey=key> <.space>* ':' {} <.indent-panic: $<wrongkey>, $indent, "map"> ]?
	}
	token map-entry(Str $indent) {
		  <key> <.space>* ':' <?break> <.block-ws($indent)> <element($indent, 0)>
		| '?' <.block-ws($indent)> <key=.element($indent, 0)> <.newline> $indent
		  <.space>* ':' <.space>+ <element($indent, 0)>
	}

	token yamllist(Str $indent) {
		<list-entry($indent)>+ % [ <.newline> $indent ]
		[ <.newline> $indent \s+ $<wrongdash>='-' <?break> {} <.indent-panic: $<wrongdash>, $indent, "list"> ]?
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
		$<value> = [ <.plainfirst> [ <-[\x0a\x0d\:]> | ':' <!break> ]* ]
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
		<properties>?
		"'" $<value>=[ [ <-[']> | "''" ]* ] "'"
	}
	token double-quoted {
		<properties>?
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
		[ $new-indent $<content>=[ \N* ] | $indent <.before <.line-break> > ]+ % <.line-break>
	}

	token inline-map {
		<properties>?
		'{' <.ws> <pairlist> <.ws> '}'
	}
	rule pairlist {
		<pair>* %% \,
	}
	rule pair {
		<key> ':' [ <inline> || <inline=inline-plain> ]
	}

	token inline-list {
		<properties>?
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

	token inline {
		<properties>?

		[
		| <value=alias>
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

	token alias {
		'*' <identifier>
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
			my $version = $<directives>.ast<version> // $default-version;
			my %prefixes = $<directives>.ast<tags>;
			my $namespace = Namespace.new(:%prefixes);
			my $root = $<explicit-document>.ast.root;
			make Document.new(:$root, :$namespace, :$version, :explicit);
		}
		method directives($/) {
			my %directives;
			%directives<tags> = @<tag-directive>».ast.list;
			%directives<version> = @<yaml-directive>[0].ast.Rat if @<yaml-directives> == 0;
			make %directives;
		}
		method tag-directive($/) {
			make ~$<tag-handle> => ~$<tag-prefix>
		}
		method explicit-document($/) {
			make Document.new(:root($<document>.ast.root), :explicit);
		}
		method bare-document($/) {
			my $root = $/.values.[0].ast;
			make Document.new(:$root, :!explicit);
		}
		method simple-document($/) {
			my $root = $/.values.[0].ast;
			make Document.new(:$root, :!explicit);
		}
		method empty-document($/) {
			make Nil;
		}
		method map($/) {
			make Mapping.new(:elems(@<map-entry>».ast));
		}
		method map-entry($/) {
			make $<key>.ast => $<element>.ast
		}
		method key($/) {
			self!first($/);
		}
		method yamllist($/) {
			make Sequence.new(:elems(@<list-entry>».ast));
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
			my $value = $<value>.Str.subst(/<Grammar::foldable-whitespace>/, ' ', :g).subst("''", "'", :g);
			my $tag = $<properties><tag>.ast // $resolved;
			make Single.new(:$value, :$tag, :type("'"));
		}
		method single-key($/) {
			my $value = $<value>.Str.subst("''", "'", :g);
			make Single.new(:$value, :tag($resolved), :type("'"));
		}
		method double-quoted($/) {
			my $value = @<str> == 1 ?? $<str>[0].ast !! @<str>».ast.join;
			my $tag = $<properties><tag>.ast // $resolved;
			make Single.new(:$value, :$tag, :type('"'));
		}
		method double-key($/) {
			self.double-quoted($/);
		}
		method foldable-whitespace($/) {
			make ' ';
		}
		method plain($/) {
			my $value = ~$<value>;
			my $tag = $<properties><tag>.ast // $unresolved;
			my $ast = Single.new(:$value, :$tag, :type(':'));
			make $ast;
			self!save($<properties><anchor>.ast, $ast) if $<properties><anchor>;
		}
		method inline-plain($/) {
			my $tag = $<properties><tag>.ast // $unresolved;
			make Single.new(value => ~$<value>, :$tag, :type(":"));
		}
		method block-string($/) {
			my $ret = $<content>.map(* ~ "\n").join('');
			if $<kind> eq '>' {
				my $/;
				$ret.=subst(/ <[\x0a\x0d]> <!before ' ' | $> /, ' ', :g);
			}
			my $value = self!handle_properties($<properties>, $/, $ret);
			my $tag = $<properties><tag>.ast // $unresolved;
			make Single.new(:$value, :$tag, :type('>'));
		}

		method !save($name, $value) {
			%*yaml-anchors{$name} = $value;
		}
		method element($/) {
			make $<value>.ast;
		}

		method inline-map($/) {
			make Mapping.new(:elems($<pairlist>.ast));
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
			make Sequence.new(:elems($<inline-list-inside>.ast));
		}
		method inline-list-inside($/) {
			make @<inline>».ast.list;
		}
		method inline-atom($/) {
			make $<value>.ast;
		}
		method inline($/) {
			# XXX
			make self!handle_properties($<properties>, $<value>);
		}

		method !handle_properties($properties, $match, $value = $match.ast) {
			return $value if not $properties;
			self!save($properties<anchor>.ast, $value) if $properties<anchor>;
			return $value;
		}
		method tag($/) {
			make $<value>.ast;
		}
		method verbatim-tag($/) {
			my $url = @<uri-char>».ast.join('');
			make VerbatimTag.new(:$url);
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
		method shorthand-tag($/) {
			make ShortHandTag.new(:namespace($<tag-handle>.ast), :local(~$<tag-name>));
		}
		method tag-handle($/) {
			make ~$/;
		}
		method non-specific-tag($/) {
			make NonSpecificTag.new(:resolved);
		}

		method alias($/) {
			make %*yaml-anchors{~$<identifier>.ast} // die "Unknown anchor " ~ $<identifier>.ast;
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

	method parse($string, :%tags, *%args) {
		my %*yaml-anchors;
		nextwith($string, :actions(Actions), |%args);
	}
	method subparse($string, :%tags, *%args) {
		my %*yaml-anchors;
		nextwith($string, :actions(Actions), |%args);
	}
}

grammar Schema::JSON {
	regex TOP {
		[ <element> <.ws> || <plain> ]
		{ make $/.values[0].ast; }
	}

	proto token element { * }
	token element:<null> {
		'null'
		{ make Nil }
	}
	token element:<int> {
		<[+-]>?
		[ 0 | <[1..9]> <[0..9]>* ]
		<|w>
		{ make $/.Str.Int }
	}
	token element:<rat> {
		<[+-]>?
		[ 0 | <[1..9]> <[0..9]>* ]
		\. <[0..9]>+
		<|w>
		{ make $/.Rat }
	}
	token element:<float> {
		<[+-]>?
		[ 0 | <[1..9]> <[0..9]>* ]
		[ \. <[0..9]>+ ]?
		[ <[eE]> [\+|\-]? <[0..9]>+ ]?
		<|w>
		{ make +$/.Str }
	}
	token element:<inf> {
		$<sign=[+-]>?
		'.inf'
		{ make $<sign> eq '-' ?? -Inf !! Inf }
	}
	token element:<nan> {
		'.nan'
		{ make NaN }
	}
	token element:<yes> {
		true <|w>
		{ make True }
	}
	token element:<no> {
		false <|w>
		{ make False }
	}

	token plain {
		<?{ False }>
	}
}

grammar Schema::Core is Schema::JSON {
	token element:<hex> {
		:i
		'-'?
		'0x'
		$<value>=[ <[0..9A..F]>+ ]
		<|w>
		{ make :16(~$<value>) }
	}
	token element:<oct> {
		:i
		'-'?
		'0o'
		$<value>=[ <[0..7]>+ ]
		<|w>
		{ make :8(~$<value>) }
	}
	token element:<inf> {
		:i
		$<sign>='-'?
		'.inf'
		{ make $<sign> ?? -Inf !! Inf }
	}
	token element:<nan> {
		:i '.nan'
		{ make NaN }
	}
	token element:<null> {
		[ :i 'null' | '~' ]
		{ make Nil }
	}
	token element:<yes> {
		[ :i y | yes | true | on ] <|w>
		{ make True }
	}
	token element:<no> {
		[ :i n | no | false | off ] <|w>
		{ make False }
	}

	token plain {
		^ $<value>=.* $
		{ make ~$<value> }
	}
}

grammar Schema::Extra is Schema::Core {
	token element:<datetime> {
		$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
		[ ' ' | 'T' ]
		$<hour>=<[0..9]>**2 '-' $<minute>=<[0..9]>**2 '-' $<seconds>=<[0..9]>**2
		$<offset>=[ <[+-]> <[0..9]>**1..2]
		{ make DateTime.new(|$/.hash».Int) }
	}
	token element:<date> {
		$<year>=<[0..9]>**4 '-' $<month>=<[0..9]>**2 '-' $<day>=<[0..9]>**2
		{ make Date.new(|$/.hash».Int) }
	}
}

my %yaml-tags = (
	$yaml-namespace => {
		str => sub ($value) {
			return $value if $value ~~ Str;
			die "Couldn't resolve { $value.WHAT } to string";
		},
		int => sub ($value) {
			return $value.Int if $value ~~ Str;
			die "Couldn't resolve a { $value.WHAT } to integer";
		},
		float => sub ($value) {
			return $value.Rat if $value ~~ Str;
			die "Couldn't resolve a { $value.WHAT } to float";
		},
		null => sub ($) {
			return Nil;
		},
		binary => sub ($, $value) {
			require MIME::Base64;
			return MIME::Base64.decode($value.subst(/<[\ \t\n]>/, '', :g)) if $value ~~ Str;
			die "Binary has to be a string";
		},
		seq => sub ($value) {
			return $value if $value ~~ Iterable;
			die "Could not convert { $value.WHAT } to a sequence";
		},
		map => sub ($value) {
			return $value if $value ~~ Associative;
			die "Could not convert { $value.WHAT } to am Associative";
		},
		set => sub ($value) {
			return $value.keys.set if $value ~~ Associative;
			die "Could not convert { $value.WHAT } to a set";
		},
		omap => sub ($value) {
			die "Ordered maps not implemented yet"
		},
	},
);
my sub flatten-tags(%tags) {
	return %tags.kv.map({ |$^value.kv.map($^namespace ~ * => *) } );
}
my %default-tags = flatten-tags(%yaml-tags);

our sub load-yaml(Str $input, ::Grammar:U :$schema = ::Schema::Core, :%tags) is export {
	my $match = Grammar.parse($input);
	CATCH {
		fail "Couldn't parse YAML: $_";
	}
	my Callable %callbacks = |%default-tags, |flatten-tags(%tags);
	return $match ?? $match.ast[0].concretize($schema, %callbacks) !! fail "Couldn't parse YAML";
}
our sub load-yamls(Str $input, ::Grammar:U :$schema = ::Schema::Core, :%tags) is export {
	my $match = Grammar.parse($input);
	CATCH {
		fail "Couldn't parse YAML: $_";
	}
	my Callable %callbacks = |%default-tags, |flatten-tags(%tags);
	return $match ?? $match.ast.map(*.concretize($schema, %callbacks)) !! fail "Couldn't parse YAML";
}

proto to-yaml($;$ = Str) {*}

multi to-yaml(Real:D $d; $ = Str) { ~$d }
multi to-yaml(Bool:D $d; $ = Str) { $d ?? 'true' !! 'false'; }
multi to-yaml(Str:D  $d where /^ <!Schema::Core::element> <[\w.-]>+ $/; $ = Str) {
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
