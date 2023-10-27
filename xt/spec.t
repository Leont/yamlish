#! raku

use Test;
use YAMLish;
use JSON::Tiny;

my @targets = @*ARGS || dir('test-suite/name');

if %*ENV<SPEC_TESTING> {
	for @targets -> $dirname {
		my $dir = $dirname.IO;
		my $description = $dir.add('===').slurp.chomp;

		my $yaml-text = $dir.add('in.yaml').slurp;
		my $yaml-content = load-yaml($yaml-text);

		subtest "$description ($dirname)", {
			my $error = $dir.add('error').e;

			is($yaml-content ~~ Failure, $error, "YAML content is {$error ?? 'not ' !! ''}defined");

			if !$error {
				my @expected-events = $dir.add('test.event').lines.map({ $_ eq '-DOC ...' ?? '-DOC' !! $_ } );
				my @observed-events = stream-yaml($yaml-text);
				is(@observed-events.join(' '), @expected-events.join(' '), "Events match $dirname");

				my $json-name = $dir.add('in.json');
				if $json-name.e {
					my $json-content = from-json($json-name.slurp);
					is-deeply($yaml-content, $json-content, "JSON matches");
				}
			}
		}
	}
}

done-testing;
