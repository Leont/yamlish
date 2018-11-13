#! perl6

use v6;
use Test;
use YAMLish;

my $text1 = 'openapi: 3.0.1';

my $match = load-yaml($text1);
my %expected = (openapi => '3.0.1');
is-deeply($match, %expected); 

done-testing();
