#!/usr/bin/env perl
use strict;
use warnings;
use v5.20;
use Test::More;

# aur-format, with modules from this directory
my $script = '../lib/util/aur-format';
do $script or die $@ || $!;

my %pkg = (Name => 'foo', Version => '1.0-1', PackageBase => 'foobase');

# Expand a format string for %pkg
sub format_pkg {
    my ($format) = @_;
    my ($labels, $suffix) = tokenize($format);

    open(my $fh, '>', \my $out) or die $!;
    my $stdout = select($fh);
    info_format(\%pkg, $labels, $suffix, ' ', 0, '%F');
    select($stdout);
    close($fh);

    return $out;
}

is(format_pkg('%n\t%v\n'), "foo\t1.0-1\n", 'fields and escapes');
is(format_pkg('%n\\\\t'), 'foo\\\\t', 'escaped backslash');
is(format_pkg('text %n'), 'text foo', 'text before field');
is(format_pkg('\t%n\n'), "\tfoo\n", 'escapes before field');
is(format_pkg('100%%done'), '100%done', '%% before text');
is(format_pkg('%%b %b'), '%b foobase', '%% before format key');
is(format_pkg('%n%%'), 'foo%', '%% at end');
is(format_pkg('%n%'), 'foo%', 'trailing %');
is(format_pkg('%%z'), '%z', '%% before other character');

ok(!eval { tokenize('%z'); 1 }, 'invalid format key');
like($@, qr/invalid format key/, 'invalid format key: error');

done_testing();
