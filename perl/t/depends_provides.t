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
do $script;
BAIL_OUT("unable to compile $script: $@") if $@;
BAIL_OUT("$script loaded but solve() not defined") if not exists &solve;

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
    ok(defined $results->{bar}, 'bar remains in %results');

    # Full DAG shape in one is_deeply so autoviv side-effects
    # from chained \$dag->{X}{Y} probes cannot mask a missing
    # node.
    is_deeply(
        $dag,
        {
            foo  => { foo => 'Self' },
            libx => { foo => 'Depends' },
            bar  => { bar => 'Self' },
            liby => { bar => 'Depends' },
        },
        'DAG shape: foo + bar self-edges with their dependencies',
    );
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
    ok(defined $results->{bar}, 'bar also preserved');

    is_deeply(
        $dag,
        { foo => { foo => 'Self' }, bar => { bar => 'Self' } },
        'DAG shape: both targets anchored, no cross-edges',
    );
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

    # Assert the whole shape in a single is_deeply rather than a
    # sequence of \$dag->{X}{Y} probes. Individual probes would
    # autovivify \$dag->{X}={}, masking an empty-DAG regression
    # and making a later "scalar keys %{\$dag} == 2" check pass
    # by accident.
    is_deeply(
        $dag,
        { foo => { foo => 'Self' }, bar => { foo => 'Depends' } },
        'DAG shape: foo self-edge plus foo -> bar dependency',
    );
};

done_testing();
# vim: set et sw=4 sts=4 ft=perl:
