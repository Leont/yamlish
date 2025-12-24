use Test;
use YAMLish;

my $str = "t/data/config.yml".IO.slurp;
my %conf = load-yaml $str;

plan 3;

is %conf<lang>, "en";
is %conf<lat>, 46.12345;
is %conf<lon>, -82.6231;


