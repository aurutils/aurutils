#!/usr/bin/env perl
use strict;
use warnings;
use v5.20;
use Carp;
use File::Basename qw(dirname);
use File::Temp qw(tempfile);
use Test::More;
use AUR::Json qw(parse_json);

# Check if module can be imported
require_ok "AUR::Depends";

AUR::Depends->import(qw(recurse graph prune tsort));

# --- Helper: build $results hash from a list of packages ---
# Each entry: { Name => ..., Version => ..., Provides => [...] }
sub make_results {
    my @packages = @_;
    my %results;
    for my $pkg (@packages) {
        $results{$pkg->{Name}} = $pkg;
    }
    return %results;
}

# --- Helper: build $pkgdeps like recurse() does ---
# Seeds Self edges for targets, then adds explicit deps.
# $targets: arrayref of target names
# $deps:    hashref  { pkgname => [[$spec, $type], ...] }
sub make_pkgdeps {
    my ($targets, $deps) = @_;
    my %pkgdeps;

    # Seed Self edges the same way recurse() does (line 69-71)
    for my $t (@{$targets}) {
        push @{$pkgdeps{$t}}, [$t, 'Self'];
    }

    # Add explicit dependencies
    for my $name (keys %{$deps}) {
        for my $pair (@{$deps->{$name}}) {
            push @{$pkgdeps{$name}}, $pair;
        }
    }
    return %pkgdeps;
}

subtest 'graph: single target, no deps' => sub {
    my %results = make_results(
        { Name => 'foo', Version => '1.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['foo'], {});
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    # Self edge should exist
    is($dag->{foo}{foo}, 'Self', 'self edge for target foo');
    is(scalar keys %{$dag_foreign}, 0, 'no foreign deps');
};

subtest 'graph: linear chain A -> B -> C' => sub {
    my %results = make_results(
        { Name => 'A', Version => '1.0-1' },
        { Name => 'B', Version => '2.0-1' },
        { Name => 'C', Version => '3.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['A'], {
        'A' => [['B', 'Depends']],
        'B' => [['C', 'Depends']],
    });
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is($dag->{A}{A}, 'Self',    'A self edge');
    is($dag->{B}{A}, 'Depends', 'B required by A');
    is($dag->{C}{B}, 'Depends', 'C required by B');
};

subtest 'graph: target with empty depends' => sub {
    my %results = make_results(
        { Name => 'leaf', Version => '0.1-1' },
    );
    my %pkgdeps = make_pkgdeps(['leaf'], {});
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is(scalar keys %{$dag}, 1, 'only one node in DAG');
    ok(exists $dag->{leaf}, 'leaf exists as a DAG key');
    is($dag->{leaf}{leaf}, 'Self', 'self edge exists');
};

subtest 'graph: foreign dependency' => sub {
    my %results = make_results(
        { Name => 'mypkg', Version => '1.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['mypkg'], {
        'mypkg' => [['glibc', 'Depends']],
    });
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is($dag->{mypkg}{mypkg}, 'Self', 'self edge');
    is($dag_foreign->{glibc}{mypkg}, 'Depends', 'glibc in foreign DAG');
    ok(not(defined $dag->{glibc}), 'glibc not in main DAG');
};

subtest 'graph: provider ($provides=1)' => sub {
    my %results = make_results(
        { Name => 'mypkg',    Version => '1.0-1' },
        { Name => 'libfoo',   Version => '2.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['mypkg'], {
        'mypkg' => [['libfoo', 'Depends']],
    });
    # provider-pkg provides libfoo
    my %pkgmap = ( 'libfoo' => ['provider-pkg', '2.0'] );

    # $provides=1: provider takes precedence
    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 1);

    is($dag->{'provider-pkg'}{mypkg}, 'Depends',
        'edge goes through provider-pkg when $provides=1');
    ok(not(defined $dag->{'libfoo'}),
        'libfoo not in DAG (replaced by provider-pkg)');
};

subtest 'graph: provider disabled ($provides=0)' => sub {
    my %results = make_results(
        { Name => 'mypkg',  Version => '1.0-1' },
        { Name => 'libfoo', Version => '2.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['mypkg'], {
        'mypkg' => [['libfoo', 'Depends']],
    });
    my %pkgmap = ( 'libfoo' => ['provider-pkg', '2.0'] );

    # $provides=0: use the package itself
    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is($dag->{libfoo}{mypkg}, 'Depends',
        'edge goes to libfoo directly when $provides=0');
    ok(not(defined $dag->{'provider-pkg'}),
        'provider-pkg not in DAG when $provides=0');
};

subtest 'graph: multiple dep types' => sub {
    my %results = make_results(
        { Name => 'pkg',      Version => '1.0-1' },
        { Name => 'libdep',   Version => '1.0-1' },
        { Name => 'buildtool', Version => '2.0-1' },
        { Name => 'checker',  Version => '0.5-1' },
    );
    my %pkgdeps = make_pkgdeps(['pkg'], {
        'pkg' => [
            ['libdep',    'Depends'],
            ['buildtool', 'MakeDepends'],
            ['checker',   'CheckDepends'],
        ],
    });
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is($dag->{libdep}{pkg},    'Depends',      'Depends edge');
    is($dag->{buildtool}{pkg}, 'MakeDepends',  'MakeDepends edge');
    is($dag->{checker}{pkg},   'CheckDepends', 'CheckDepends edge');
};

subtest 'graph: multiple targets each get self edges' => sub {
    my %results = make_results(
        { Name => 'X', Version => '1.0-1' },
        { Name => 'Y', Version => '1.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['X', 'Y'], {});
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is($dag->{X}{X}, 'Self', 'X self edge');
    is($dag->{Y}{Y}, 'Self', 'Y self edge');
};

subtest 'graph: pkgdeps values are always arrayrefs (dead code proof)' => sub {
    my %results = make_results(
        { Name => 'test', Version => '1.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['test'], {});

    # Verify the data structure: pkgdeps{test} is an arrayref
    is(ref($pkgdeps{test}), 'ARRAY',
        'pkgdeps entry is ARRAY ref, not a scalar (confirms #1252)');

    # The dead code does: $pkgdeps->{$name} eq $name
    # This can never be true for an arrayref
    ok($pkgdeps{test} ne 'test',
        'arrayref ne string is always true');
};

subtest 'prune: removes installed packages' => sub {
    # Build a DAG: C <- B <- A (Self)
    my %dag = (
        'A' => { 'A' => 'Self' },
        'B' => { 'A' => 'Depends' },
        'C' => { 'B' => 'Depends' },
    );

    my @removed = prune(\%dag, ['C']);

    ok((grep { $_ eq 'C' } @removed), 'C was pruned');
    ok(not(defined $dag{C}), 'C removed from DAG');
    ok(defined $dag{A}, 'A remains in DAG');
    ok(defined $dag{B}, 'B remains in DAG');
};

subtest 'prune: cascading removal of orphaned deps' => sub {
    my %dag = (
        'A' => { 'A' => 'Self' },
        'B' => { 'A' => 'Depends' },
        'C' => { 'B' => 'Depends' },
    );

    my @removed = prune(\%dag, ['A']);

    ok((grep { $_ eq 'A' } @removed), 'A was pruned');
    ok((grep { $_ eq 'B' } @removed), 'B was pruned (cascading)');
    ok((grep { $_ eq 'C' } @removed), 'C was pruned (cascading)');
    is(scalar keys %dag, 0, 'DAG is empty after cascading prune');
};

subtest 'prune: empty installed list' => sub {
    my %dag = (
        'A' => { 'A' => 'Self' },
        'B' => { 'A' => 'Depends' },
    );

    my @removed = prune(\%dag, []);

    is(scalar @removed, 0, 'nothing pruned');
    is(scalar keys %dag, 2, 'DAG unchanged');
};

subtest 'prune: removes target with multiple dependents' => sub {
    my %dag = (
        'base'  => { 'base' => 'Self' },
        'dep-a' => { 'base' => 'Depends' },
        'dep-b' => { 'base' => 'Depends' },
        'dep-c' => { 'base' => 'Depends' },
    );

    my @removed = prune(\%dag, ['base']);

    ok((grep { $_ eq 'base' } @removed), 'base was pruned');
    ok((grep { $_ eq 'dep-a' } @removed), 'dep-a cascaded');
    ok((grep { $_ eq 'dep-b' } @removed), 'dep-b cascaded');
    ok((grep { $_ eq 'dep-c' } @removed), 'dep-c cascaded');
    is(scalar keys %dag, 0, 'DAG fully emptied');
};

subtest 'prune: leaf removal does not cascade upward' => sub {
    # A depends on both B and C
    my %dag = (
        'A' => { 'A' => 'Self' },
        'B' => { 'A' => 'Depends' },
        'C' => { 'A' => 'Depends' },
    );

    my @removed = prune(\%dag, ['B']);

    ok((grep { $_ eq 'B' } @removed), 'B was pruned');
    ok(defined $dag{A}, 'A remains');
    ok(defined $dag{C}, 'C remains');
};

subtest 'tsort: linear chain' => sub {
    # Pairs: A->A (self), B->A, C->B
    my @input = ('A', 'A', 'B', 'A', 'C', 'B');
    my @sorted = tsort(0, \@input);

    # C depends on B depends on A, so DFS order is C, B, A
    is($sorted[0], 'C', 'C first (deepest)');
    is($sorted[-1], 'A', 'A last (root)');
};

subtest 'tsort: self loop only' => sub {
    my @input = ('X', 'X');
    my @sorted = tsort(0, \@input);

    is(scalar @sorted, 1, 'one element');
    is($sorted[0], 'X', 'element is X');
};

subtest 'tsort: BFS mode' => sub {
    # Diamond: D depends on B and C, both depend on A
    my @input = ('A', 'A', 'B', 'A', 'C', 'A', 'D', 'B', 'D', 'C');
    my @sorted = tsort(1, \@input);

    is($sorted[0], 'D', 'D first in BFS (only node with no predecessors)');
    is($sorted[-1], 'A', 'A last in BFS (leaf)');
};

subtest 'recurse: single target, no deps' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'pkg-a' => {
                Name    => 'pkg-a',
                Version => '1.0-1',
            },
        );
        return map { $db{$_} } @{$deps};
    };

    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['pkg-a'], ['Depends'], $callback
    );

    ok(defined $results->{'pkg-a'}, 'pkg-a in results');
    is($results->{'pkg-a'}{'Version'}, '1.0-1', 'correct version');

    # Self edge seeded
    is($pkgdeps->{'pkg-a'}[0][0], 'pkg-a', 'self dep spec');
    is($pkgdeps->{'pkg-a'}[0][1], 'Self',  'self dep type');

    is(scalar keys %{$pkgmap}, 0, 'no providers');
};

subtest 'recurse: multi-level A -> B -> C' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'A' => {
                Name     => 'A',
                Version  => '1.0-1',
                Depends  => ['B'],
            },
            'B' => {
                Name     => 'B',
                Version  => '2.0-1',
                Depends  => ['C'],
            },
            'C' => {
                Name     => 'C',
                Version  => '3.0-1',
            },
        );
        return map { $db{$_} } @{$deps};
    };

    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['A'], ['Depends'], $callback
    );

    # All three packages resolved
    ok(defined $results->{'A'}, 'A in results');
    ok(defined $results->{'B'}, 'B in results');
    ok(defined $results->{'C'}, 'C in results');

    # A has Self + B dep
    is(scalar @{$pkgdeps->{'A'}}, 2, 'A has 2 pkgdeps entries');
    is($pkgdeps->{'A'}[1][0], 'B',       'A depends on B');
    is($pkgdeps->{'A'}[1][1], 'Depends', 'dep type is Depends');

    # B has B dep (from callback) + C dep
    is($pkgdeps->{'B'}[0][0], 'C',       'B depends on C');
    is($pkgdeps->{'B'}[0][1], 'Depends', 'dep type is Depends');
};

subtest 'recurse: dedup - shared dep queried once' => sub {
    my $call_count = 0;
    my $callback = sub {
        my ($deps) = @_;
        $call_count++;
        my %db = (
            'X' => {
                Name    => 'X',
                Version => '1.0-1',
                Depends => ['shared'],
            },
            'Y' => {
                Name    => 'Y',
                Version => '1.0-1',
                Depends => ['shared'],
            },
            'shared' => {
                Name    => 'shared',
                Version => '1.0-1',
            },
        );
        return map { $db{$_} } @{$deps};
    };

    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['X', 'Y'], ['Depends'], $callback
    );

    ok(defined $results->{'shared'}, 'shared in results');
    # callback called twice: once for [X,Y], once for [shared]
    is($call_count, 2, 'callback called exactly twice (no dup queries)');
};

subtest 'recurse: provides populate pkgmap' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'real-pkg' => {
                Name     => 'real-pkg',
                Version  => '2.0-1',
                Provides => ['virtual-pkg=2.0'],
            },
        );
        return map { $db{$_} } @{$deps};
    };

    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['real-pkg'], ['Depends'], $callback
    );

    ok(defined $pkgmap->{'virtual-pkg'}, 'virtual-pkg in pkgmap');
    is($pkgmap->{'virtual-pkg'}[0], 'real-pkg', 'provider is real-pkg');
    is($pkgmap->{'virtual-pkg'}[1], '2.0',      'provider version is 2.0');
};

subtest 'recurse: self-provide excluded from pkgmap' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'foo' => {
                Name     => 'foo',
                Version  => '1.0-1',
                Provides => ['foo=1.0'],
            },
        );
        return map { $db{$_} } @{$deps};
    };

    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['foo'], ['Depends'], $callback
    );

    ok(not(defined $pkgmap->{'foo'}),
        'self-provide not added to pkgmap (line 102: $prov ne $name)');
};

subtest 'recurse: first provider takes precedence' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'first' => {
                Name     => 'first',
                Version  => '1.0-1',
                Provides => ['virt=1.0'],
            },
            'second' => {
                Name     => 'second',
                Version  => '2.0-1',
                Provides => ['virt=2.0'],
            },
        );
        # Return in deterministic order: first before second
        my @out;
        for my $d (@{$deps}) {
            push @out, $db{$d} if defined $db{$d};
        }
        return @out;
    };

    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['first', 'second'], ['Depends'], $callback
    );

    is($pkgmap->{'virt'}[0], 'first', 'first provider wins');
};

subtest 'recurse: dep type filtering' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'app' => {
                Name          => 'app',
                Version       => '1.0-1',
                Depends       => ['libx'],
                MakeDepends   => ['build-tool'],
                CheckDepends  => ['test-fw'],
            },
            'libx'       => { Name => 'libx',       Version => '1.0-1' },
            'build-tool' => { Name => 'build-tool',  Version => '1.0-1' },
            'test-fw'    => { Name => 'test-fw',     Version => '1.0-1' },
        );
        return map { $db{$_} } @{$deps};
    };

    # Only request Depends - MakeDepends and CheckDepends should be ignored
    my ($results, $pkgdeps, $pkgmap) = recurse(
        ['app'], ['Depends'], $callback
    );

    ok(defined $results->{'libx'}, 'libx resolved (Depends)');
    ok(not(defined $results->{'build-tool'}),
        'build-tool not resolved (MakeDepends filtered out)');
    ok(not(defined $results->{'test-fw'}),
        'test-fw not resolved (CheckDepends filtered out)');
};

subtest 'recurse: OptDepends resolves when requested' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'app' => {
                Name        => 'app',
                Version     => '1.0-1',
                Depends     => ['libx'],
                OptDepends  => ['plugin'],
            },
            'libx'   => { Name => 'libx',   Version => '1.0-1' },
            'plugin' => { Name => 'plugin', Version => '1.0-1' },
        );
        return map { $db{$_} } @{$deps};
    };

    # Default trio ignores OptDepends
    my ($r1) = recurse(['app'], ['Depends', 'MakeDepends', 'CheckDepends'],
                      $callback);
    ok(not(defined $r1->{'plugin'}),
        'plugin not resolved under default dep_types');

    # OptDepends in $dep_types pulls it in
    my ($r2) = recurse(['app'], ['Depends', 'OptDepends'], $callback);
    ok(defined $r2->{'plugin'},
        'plugin resolved when OptDepends requested');
    ok(defined $r2->{'libx'},
        'libx still resolved alongside OptDepends');
};

subtest 'recurse: Conflicts and Replaces pass through to results' => sub {
    my $callback = sub {
        my ($deps) = @_;
        my %db = (
            'new-app' => {
                Name      => 'new-app',
                Version   => '2.0-1',
                Depends   => [],
                Conflicts => ['old-app', 'rival'],
                Replaces  => ['old-app'],
            },
        );
        return map { $db{$_} } @{$deps};
    };

    my ($results) = recurse(
        ['new-app'], ['Depends', 'MakeDepends', 'CheckDepends'], $callback
    );

    is_deeply($results->{'new-app'}{'Conflicts'}, ['old-app', 'rival'],
        'Conflicts preserved verbatim in results');
    is_deeply($results->{'new-app'}{'Replaces'}, ['old-app'],
        'Replaces preserved verbatim in results');
};

subtest 'graph: versioned dep fails vercmp' => sub {
    my %results = make_results(
        { Name => 'app',    Version => '1.0-1' },
        { Name => 'libold', Version => '1.0-1' },
    );
    my %pkgdeps = make_pkgdeps(['app'], {
        'app' => [['libold>=5.0', 'Depends']],
    });
    my %pkgmap;

    eval { graph(\%results, \%pkgdeps, \%pkgmap, 1, 0) };
    like($@, qr/invalid node: libold=1\.0/,
        'graph croaks on version mismatch');
};

subtest 'tsort: cycle detection' => sub {
    # A -> B -> A (cycle), plus self-loops
    eval { tsort(0, ['A', 'A', 'A', 'B', 'B', 'B', 'B', 'A']) };
    like($@, qr/cycle detected/, 'tsort croaks on cycle');
};

subtest 'tsort: partial cycle with sortable nodes' => sub {
    # C -> A -> B -> A (A-B cycle), C has no predecessors
    eval { tsort(0, ['C', 'C', 'C', 'A', 'A', 'B', 'B', 'A']) };
    like($@, qr/cycle detected/, 'tsort croaks even when some nodes sortable');
};

subtest 'graph: empty pkgdeps' => sub {
    my %results;
    my %pkgdeps;
    my %pkgmap;

    my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, \%pkgmap, 0, 0);

    is(scalar keys %{$dag}, 0, 'empty DAG');
    is(scalar keys %{$dag_foreign}, 0, 'empty foreign DAG');
};

subtest 'recurse: no results croaks' => sub {
    my $callback = sub { return (); };

    # Silence the "target not found" pre-check warning on STDERR.
    my $err;
    do {
        local *STDERR;
        open STDERR, '>', \$err or die "redirect stderr: $!";
        eval { recurse(['nonexistent'], ['Depends'], $callback) };
    };
    like($@, qr/no packages found/, 'recurse croaks when nothing resolves');
};

# Versioned dep operators - boundary tests for all five operators
subtest 'graph: versioned dep operators' => sub {
    my @cases = (
        ['=',  '2.0-1', 'lib=2.0',  'lib=2.0 satisfied by 2.0'],
        ['<',  '1.5-1', 'lib<2.0',  'lib<2.0 satisfied by 1.5'],
        ['<=', '2.0-1', 'lib<=2.0', 'lib<=2.0 satisfied by 2.0 (boundary)'],
        ['>',  '3.0-1', 'lib>2.0',  'lib>2.0 satisfied by 3.0'],
        ['>=', '2.0-1', 'lib>=2.0', 'lib>=2.0 satisfied by 2.0 (boundary)'],
    );
    for my $case (@cases) {
        my ($op, $ver, $spec, $desc) = @{$case};
        my %results = make_results(
            { Name => 'app', Version => '1.0-1' },
            { Name => 'lib', Version => $ver },
        );
        my %pkgdeps = make_pkgdeps(['app'], {
            'app' => [[$spec, 'Depends']],
        });
        my ($dag, $dag_foreign) = graph(\%results, \%pkgdeps, {}, 1, 0);
        is($dag->{lib}{app}, 'Depends', $desc);
    }
};

subtest 'tsort: single non-self pair' => sub {
    my @input = ('A', 'B');
    my @sorted = tsort(0, \@input);

    is(scalar @sorted, 2, 'two elements');
    is($sorted[0], 'A', 'A first (no predecessors)');
    is($sorted[1], 'B', 'B second (successor of A)');
};

# =========================================================
# Fixture-based invariant tests
#
# Auto-discovers fixtures in t/fixtures/<pkg>/*.json: each
# subdirectory is one fixture whose name is the primary
# target, and all JSON files inside (array of AUR API result
# objects) are merged into the mock package database. This
# mirrors how aur-depends issues multiple RPC rounds.
#
# Invariants checked:
#   1. Target has a self-edge in the DAG (pre-prune)
#   2. Every main DAG node is in results (no dangling refs)
#   3. No foreign dep appears in the main DAG
#   4. tsort output has no duplicates
#   5. tsort output covers every DAG node in the no-cycle case
#
# The prune step mirrors current upstream solve() (aur-depends):
# every key of $pkgmap is pruned. No claims are made about
# targets surviving that prune — the harness only asserts
# invariants that hold for the pipeline as it is today.
# =========================================================

my $fixture_dir = dirname(__FILE__) . '/fixtures';

# --- Helper: load all JSON files in a fixture dir into one DB ---
sub fixture_callback {
    my ($dir) = @_;

    opendir(my $dh, $dir) or croak "Cannot open $dir: $!";
    my @files = sort grep { /[.]json\z/x } readdir($dh);
    closedir($dh);

    my %db;
    for my $file (@files) {
        open(my $fh, '<', "$dir/$file") or croak "Cannot open $dir/$file: $!";
        my $json_str = do { local $/ = undef; <$fh> };
        close($fh);
        my $packages = parse_json($json_str);
        for my $pkg (@{$packages}) {
            $db{$pkg->{'Name'}} = $pkg;
        }
    }

    return sub {
        my ($deps) = @_;
        return map { $db{$_} } @{$deps};
    }, \%db;
}

# --- Auto-discover and test each fixture ---
if (-d $fixture_dir) {
    opendir(my $dh, $fixture_dir) or croak "Cannot open $fixture_dir: $!";
    my @fixtures = sort grep {
        !/^[.]/x && -d "$fixture_dir/$_"
    } readdir($dh);
    closedir($dh);

    for my $fixture_name (@fixtures) {
        my $fixture_path = "$fixture_dir/$fixture_name";

        subtest "fixture: $fixture_name" => sub {
            my ($callback, $db) = fixture_callback($fixture_path);
            my @targets = sort keys %{$db};

            my @primary = grep { $_ eq $fixture_name } @targets;
            if (not @primary) {
                die "fixture $fixture_name: no matching package in DB";
            }

            my @dep_types = ('Depends', 'MakeDepends', 'CheckDepends');

            # --- Run pipeline ---
            # Silence the "target not found" pre-check stderr.
            my ($results, $pkgdeps, $pkgmap);
            my ($dag, $dag_foreign);
            {
                my $silenced;
                local *STDERR;
                open STDERR, '>', \$silenced or croak "redirect stderr: $!";

                ($results, $pkgdeps, $pkgmap) = recurse(
                    \@primary, \@dep_types, $callback
                );
                ($dag, $dag_foreign) = graph(
                    $results, $pkgdeps, $pkgmap, 0, 1
                );
            }

            # --- Invariant 1: target has self-edge (pre-prune) ---
            for my $target (@primary) {
                if (exists $dag->{$target}) {
                    is($dag->{$target}{$target}, 'Self',
                        "target $target has self-edge");
                }
                else {
                    fail("target $target has self-edge (no DAG node)");
                }
            }

            # prune every $pkgmap key ($provides=1)
            my @to_prune = keys %{$pkgmap};
            if (@to_prune) {
                my @removed = prune($dag, \@to_prune);
                delete @{$results}{@removed};
            }

            # --- Invariant 2: every DAG node is in results ---
            my $dangling = 0;
            for my $dep (keys %{$dag}) {
                if (not defined $results->{$dep}) {
                    $dangling++;
                    diag("dangling DAG node: $dep");
                }
            }
            is($dangling, 0, 'no dangling DAG nodes (all in results)');

            # --- Invariant 3: no foreign dep in main DAG ---
            my $foreign_in_dag = 0;
            for my $dep (keys %{$dag_foreign}) {
                if (defined $dag->{$dep}) {
                    $foreign_in_dag++;
                    diag("foreign dep in main DAG: $dep");
                }
            }
            is($foreign_in_dag, 0, 'no foreign deps in main DAG');

            # --- Invariants 4 & 5: tsort properties ---
            my @pairs;
            for my $dep (keys %{$dag}) {
                for my $name (keys %{$dag->{$dep}}) {
                    push @pairs, $dep, $name;
                }
            }

            my @sorted = eval { tsort(0, \@pairs) };
            my $cycle  = $@;

            if ($cycle) {
                like($cycle, qr/cycle detected/,
                    "cycle path: tsort croaks on cyclic dependencies");
            }
            else {
                my %seen;
                my @dupes = grep { $seen{$_}++ } @sorted;
                is(scalar @dupes, 0, 'tsort output has no duplicates');

                my $dag_nodes    = scalar keys %{$dag};
                my $sorted_nodes = scalar @sorted;
                is($sorted_nodes, $dag_nodes,
                    "no-cycle path: tsort emits every DAG node ($sorted_nodes == $dag_nodes)");
            }
        };
    }
}

done_testing();
# vim: set et sw=4 sts=4 ft=perl:
