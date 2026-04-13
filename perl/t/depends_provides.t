#!/usr/bin/env perl
#
# Regression coverage for issue #1255 against the real aur-depends
# solve() path. The TODO subtests document the intended graph shape
# once explicit targets stop being pruned when another resolved
# package provides them.
#
# Authors: Avinash H. Duduskar <https://github.com/Strykar>
#
use strict;
use warnings;
use v5.20;
use Test::More;
use FindBin qw($Bin);
use File::Spec;

my $script = File::Spec->catfile($Bin, '..', '..', 'lib', 'aurweb', 'aur-depends');
do $script or BAIL_OUT("unable to load $script: " . ($@ || $!));

sub solve_with_db {
    my ($targets, $types, $db, $opt_verify, $opt_provides) = @_;

    my $callback = sub {
        my ($deps) = @_;
        return map { $db->{$_} } grep { defined $db->{$_} } @{$deps};
    };

    return solve($targets, $types, $callback, $opt_verify, $opt_provides, []);
}

subtest 'explicit target stays anchored when sibling target provides it' => sub {
    local $TODO = 'issue #1255: explicit targets should survive provider pruning';

    my %db = (
        foo  => { Name => 'foo',  Version => '1.0-1',
                  Depends => ['libx'] },
        bar  => { Name => 'bar',  Version => '2.0-1',
                  Provides => ['foo=1.0'],
                  Depends => ['liby'] },
        libx => { Name => 'libx', Version => '1.0-1' },
        liby => { Name => 'liby', Version => '1.0-1' },
    );

    my ($results, $dag, $dag_foreign) = solve_with_db(
        ['foo', 'bar'], ['Depends'], \%db, 0, 1);

    is_deeply($dag_foreign, {}, 'no foreign dependencies in repro');
    ok(defined $results->{foo}, 'foo remains in %results');
    ok(defined $dag->{foo}, 'foo keeps a DAG node');
    is($dag->{foo}{foo}, 'Self', 'foo keeps its self-edge');
    ok(defined $dag->{libx}, 'foo dependency stays in DAG');
    is($dag->{libx}{foo}, 'Depends', 'libx remains required by foo');

    ok(defined $results->{bar}, 'bar remains in %results');
    ok(defined $dag->{bar}, 'bar keeps a DAG node');
    is($dag->{bar}{bar}, 'Self', 'bar keeps its self-edge');
    is($dag->{liby}{bar}, 'Depends', 'liby remains required by bar');
};

subtest 'explicit targets remain intact when provides are disabled' => sub {
    my %db = (
        foo => { Name => 'foo', Version => '1.0-1' },
        bar => { Name => 'bar', Version => '2.0-1',
                 Provides => ['foo=1.0'] },
    );

    my ($results, $dag, $dag_foreign) = solve_with_db(
        ['foo', 'bar'], ['Depends'], \%db, 0, 0);

    is_deeply($dag_foreign, {}, 'no foreign dependencies');
    ok(defined $results->{foo}, 'foo preserved when provides are disabled');
    is($dag->{foo}{foo}, 'Self', 'foo self-edge intact');
    ok(defined $results->{bar}, 'bar also preserved');
    is($dag->{bar}{bar}, 'Self', 'bar self-edge intact');
};

subtest 'explicit target survives when a dependency also provides it' => sub {
    local $TODO = 'issue #1255: explicit targets should survive provider pruning';

    my %db = (
        foo => { Name => 'foo', Version => '1.0-1',
                 Depends => ['bar'] },
        bar => { Name => 'bar', Version => '2.0-1',
                 Provides => ['foo=1.0'] },
    );

    my ($results, $dag, $dag_foreign) = solve_with_db(
        ['foo'], ['Depends'], \%db, 0, 1);

    is_deeply($dag_foreign, {}, 'no foreign dependencies in repro');
    ok(defined $results->{foo}, 'foo stays in %results');
    ok(defined $results->{bar}, 'bar stays in %results');
    ok(defined $dag->{foo}, 'foo keeps a DAG node');
    is($dag->{foo}{foo}, 'Self', 'foo keeps its self-edge');
    ok(defined $dag->{bar}, 'bar remains buildable');
    is($dag->{bar}{foo}, 'Depends', 'bar remains required by foo');
    is(scalar keys %{$dag}, 2, 'build order remains available');
};

done_testing();
# vim: set et sw=4 sts=4 ft=perl:
