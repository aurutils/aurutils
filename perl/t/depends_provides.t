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
my $rv = do $script;
if (not defined $rv) {
    # do() returns undef for both compile errors ($@ set) and
    # I/O failures ($! set). Keep them distinct so a misplaced
    # script doesn't masquerade as a syntax problem.
    BAIL_OUT("unable to compile $script: $@") if $@;
    BAIL_OUT("unable to read $script: $!")    if $!;
    BAIL_OUT("do $script returned undef (script ended in falsy value?)");
}
BAIL_OUT("$script loaded but solve() not defined") if not exists &solve;

sub solve_with_db {
    my ($targets, $types, $db, $opt_verify, $opt_provides) = @_;

    my $callback = sub {
        my ($deps) = @_;
        return map { $db->{$_} } grep { defined $db->{$_} } @{$deps};
    };

    return solve($targets, $types, $callback, $opt_verify, $opt_provides, []);
}

# Drive the full aur-depends pipeline past solve(): populate
# RequiredBy from $dag and run pairs() on $results, capturing
# stdout. Mirrors the `unless(caller)` main block in
# lib/aurweb/aur-depends so formatter regressions (RequiredBy
# population, pair emission, pkgbase dedup) surface here too.
sub pairs_output {
    my ($results, $dag, $key, $reverse) = @_;

    for my $name (keys %{$dag}) {
        $results->{$name}->{RequiredBy} = $dag->{$name};
    }

    my $buf = '';
    open(my $save, '>&', \*STDOUT) or die "dup stdout: $!";
    close STDOUT;
    open(STDOUT, '>', \$buf)       or die "redirect stdout: $!";
    pairs($results, $key, $reverse);
    close STDOUT;
    open(STDOUT, '>&', $save)      or die "restore stdout: $!";

    return [ sort split /\n/, $buf ];
}

subtest 'explicit target stays anchored when sibling target provides it' => sub {
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

    # These hold on current master and must keep holding — they
    # stay outside any TODO guard so a regression fails loudly.
    is_deeply($dag_foreign, {}, 'no foreign dependencies in repro');
    ok(defined $results->{foo}, 'foo remains in %results');
    ok(defined $results->{bar}, 'bar remains in %results');

    # Only the DAG-shape expectation is the aspirational bug
    # check. is_deeply against the full shape avoids autoviv
    # side effects.
    TODO: {
        local $TODO = 'issue #1255: explicit targets should survive provider pruning';
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
    }
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
    my %db = (
        foo => { Name => 'foo', Version => '1.0-1',
                 Depends => ['bar'] },
        bar => { Name => 'bar', Version => '2.0-1',
                 Provides => ['foo=1.0'] },
    );

    my ($results, $dag, $dag_foreign) = solve_with_db(
        ['foo'], ['Depends'], \%db, 0, 1);

    # Invariants that already hold — outside any TODO so a
    # regression here fails loudly.
    is_deeply($dag_foreign, {}, 'no foreign dependencies in repro');
    ok(defined $results->{foo}, 'foo stays in %results');

    TODO: {
        local $TODO = 'issue #1255: explicit targets should survive provider pruning';

        ok(defined $results->{bar}, 'bar stays in %results');

        # is_deeply against the full shape avoids the
        # autovivification mask that per-key \$dag->{X}{Y}
        # probes would otherwise create.
        is_deeply(
            $dag,
            { foo => { foo => 'Self' }, bar => { foo => 'Depends' } },
            'DAG shape: foo self-edge plus foo -> bar dependency',
        );

        # Formatter-layer coverage: with the DAG intact, pairs()
        # should emit one line per edge. Today it emits nothing
        # because the DAG is empty after prune().
        my $lines = pairs_output($results, $dag, 'Name', 0);
        is_deeply($lines,
            [ "bar\tfoo", "foo\tfoo" ],
            'pairs() emits self-edge and dependency line',
        );
    }
};

subtest 'formatter control: pairs() emits expected lines for non-buggy DAG' => sub {
    # Provides-disabled path produces a clean DAG. Verify the
    # pairs()/RequiredBy output layer under a known-good shape so
    # an output regression there fails outside any TODO guard.
    my %db = (
        foo => { Name => 'foo', Version => '1.0-1', PackageBase => 'foo' },
        bar => { Name => 'bar', Version => '2.0-1', PackageBase => 'bar',
                 Provides => ['foo=1.0'] },
    );

    my ($results, $dag) = solve_with_db(
        ['foo', 'bar'], ['Depends'], \%db, 0, 0);

    my $by_name = pairs_output($results, $dag, 'Name', 0);
    is_deeply($by_name,
        [ "bar\tbar", "foo\tfoo" ],
        'pairs() by Name: one self-edge per target',
    );

    my $by_base = pairs_output($results, $dag, 'PackageBase', 0);
    is_deeply($by_base,
        [ "bar\tbar", "foo\tfoo" ],
        'pairs() by PackageBase: one self-edge per target',
    );
};

done_testing();
# vim: set et sw=4 sts=4 ft=perl:
