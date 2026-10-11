use 5.040000;
use strict;
use warnings;

use App::Normalo;
use Test::More;

# The POD can't interpolate $VERSION, so check that its copy matches.
my $module = $INC{'App/Normalo.pm'};
open my $fh, '<', $module or die "Cannot open $module: $!";
my $source = do { local $/ = undef; <$fh> };
close $fh or die "Cannot close $module: $!";

my ($pod_version) = $source =~ m{ ^=head1\ VERSION\n\nVersion\ (\S+)$ }smx;
is($pod_version, $App::Normalo::VERSION, 'POD VERSION section matches $VERSION');

done_testing();
