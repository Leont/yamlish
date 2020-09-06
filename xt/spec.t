#! perl6

use Test;
use YAMLish;
use JSON::Tiny;

my @targets = @*ARGS || dir('test-suite/name');

plan(+@targets);

for @targets -> $dirname {
	my $dir = $dirname.IO;
	my $description = $dir.add('===').slurp.chomp;

	my $yaml-text = $dir.add('in.yaml').slurp;
	my $yaml-content = load-yaml($yaml-text);

	subtest "$description ($dirname)", {
		if $dir.add('error').e {
			ok($yaml-content ~~ Failure, "Fails to parse");
		}
		else {
			my @expected-events = $dir.add('test.event').lines.map({ $_ eq '-DOC ...' ?? '-DOC' !! $_ } );
			my @observed-events = try { stream-yaml($yaml-text) // Nil };
			is(@observed-events.join(' '), @expected-events.join(' '), "Events match $dirname") if @observed-events || True;

			my $json-name = $dir.add('in.json');
			if $json-name.e {
				my $json-content = from-json($json-name.slurp);
				is-deeply($yaml-content, $json-content, "JSON matches");
			}
		}
	}
}
