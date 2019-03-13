#! perl6

use Test;
use YAMLish;
use JSON::Tiny;

my @targets = @*ARGS || dir('test-suite/name');

for @targets -> $dirname {
	my $description = slurp($*SPEC.catfile($dirname, '===')).chomp;

	my $filename = $*SPEC.catfile($dirname, 'in.yaml');
	my $yaml-text = slurp($filename);
	my $yaml-content = load-yaml($yaml-text);

	subtest "$description ($dirname)", {
		if $*SPEC.catfile($dirname, 'error').IO.e {
			ok($yaml-content ~~ Failure, "Fails to parse");
		}
		else {
			my @expected-events = slurp($*SPEC.catfile($dirname, 'test.event')).lines.map({ $_ eq '-DOC ...' ?? '-DOC' !! $_ } );
			my @observed-events = try { stream-yaml($yaml-text) // Nil };
			is(@observed-events.join(' '), @expected-events.join(' '), "Events match $dirname") if @observed-events || True;

			my $json-name = $*SPEC.catfile($dirname, 'in.json');
			if $json-name.IO.e {
				my $json-text = slurp($json-name);
				my $json-content = from-json($json-text);
				is-deeply($yaml-content, $json-content, "JSON matches");
			}
		}
	}
}

done-testing;
