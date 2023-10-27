#! raku

use YAMLish;
use JSON::Tiny;

my @targets = @*ARGS || dir('test-suite/name');

my $successes = 0;
my $total = 0;
for @targets -> $dirname {
	my $description = slurp($*SPEC.catfile($dirname, '===')).chomp;

	my $filename = $*SPEC.catfile($dirname, 'in.yaml');
	my $yaml-text = slurp($filename);

	if !$*SPEC.catfile($dirname, 'error').IO.e {
		my @expected-events = slurp($*SPEC.catfile($dirname, 'test.event')).lines.map({ $_ eq '-DOC ...' ?? '-DOC' !! $_ } );
		my @observed-events = try { stream-yaml($yaml-text) // Nil };
		my $success = @observed-events eqv @expected-events;
		if $success {
			my $match = YAMLish::Grammar.parse($yaml-text);
			say "Yay" if $match;
			$successes++;
		}
		$total++;

		say ~$dirname ~ '/in.yaml' unless $success;

		my $json-name = $*SPEC.catfile($dirname, 'in.json');
	}
}

say round(100 * $successes / $total, 0.01);
