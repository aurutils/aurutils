#!/usr/bin/env perl
use v5.40;
use File::Temp qw(tempdir);
# Test2::V0 is part of perl since 5.40. The srand plugin sets a fixed seed,
# which File::Temp would share between processes; the utf8 plugin changes
# the encoding of the source and of test output.
use Test2::V0 -no_srand => 1, -no_utf8 => 1;

use AUR::Vercmp qw(vercmp);

delete local $ENV{AUR_DEBUG};

# --- Helper: run vercmp() and count calls of vercmp(8) ---
# Returns the result and the number of calls.
sub vercmp_calls {
    my @args = @_;
    my $calls = 0;
    my $run = \&AUR::Vercmp::vercmp_run;

    no warnings 'redefine';
    local *AUR::Vercmp::vercmp_run = sub { $calls++; return $run->(@_) };
    my $ret = vercmp(@args);

    return ($ret, $calls);
}

subtest 'unversioned dependency is always true' => sub {
    local $ENV{PATH} = '/nonexistent';   # vercmp must not be called

    ok(vercmp('1.0', undef, '>='), 'undef version');
    ok(vercmp('1.0', '2.0', undef), 'undef operator');
    ok(vercmp('1.0', undef, undef), 'both undef');
    ok(vercmp(undef, undef, '<'),   'undef left version');
    ok(vercmp('1.0', undef, '=='),  'invalid operator not checked');
};

subtest 'provides without a version is always false' => sub {
    local $ENV{PATH} = '/nonexistent';   # vercmp must not be called

    ok(!vercmp(undef, '1.0', '>='), 'undef left version');
    ok(!vercmp(undef, '1.0', '='),  'undef left version, =');
};

subtest 'operator table' => sub {
    # Version pairs for each result of vercmp(8). pkgrel is only compared
    # if both versions have one, so 1.0 and 1.0-1 are equal.
    my %pairs = (-1 => ['1.0', '2.0'], 0 => ['1.0', '1.0-1'], 1 => ['2.0', '1.0']);
    my %expect = (
        '<'  => { -1 => 1, 0 => 0, 1 => 0 },
        '<=' => { -1 => 1, 0 => 1, 1 => 0 },
        '>'  => { -1 => 0, 0 => 0, 1 => 1 },
        '>=' => { -1 => 0, 0 => 1, 1 => 1 },
        '='  => { -1 => 0, 0 => 1, 1 => 0 },
    );
    for my $op (sort keys %expect) {
        for my $result (-1, 0, 1) {
            my ($ver1, $ver2) = @{$pairs{$result}};
            my ($ret, $calls) = vercmp_calls($ver1, $ver2, $op);

            is(!!$ret, !!$expect{$op}{$result}, "$ver1 $op $ver2");
            is($calls, 1, "vercmp called for $ver1 $op $ver2");
        }
    }
};

subtest '= with identical strings skips vercmp' => sub {
    my ($ret, $calls) = vercmp_calls('1.0-1', '1.0-1', '=');

    ok($ret, 'equal strings');
    is($calls, 0, 'vercmp not called');
};

subtest 'invalid operator croaks' => sub {
    for my $op ('==', '!=', '<>', '', 'eq') {
        eval { vercmp('1.0', '2.0', $op) };
        like($@, qr/^invalid vercmp operation at \Q${\__FILE__}\E/,
             "'$op' croaks at caller");
    }
};

subtest 'vercmp failure dies' => sub {
    # vercmp(8) does not fail with two arguments: replace it by false(1)
    my $bindir = tempdir(CLEANUP => 1);
    my ($false) = grep { -x } map { "$_/false" } '/usr/bin', '/bin';
    symlink($false, "$bindir/vercmp") or die "symlink: $!";

    local $ENV{PATH} = "$bindir:$ENV{PATH}";
    eval { vercmp('1.0', '2.0', '<') };
    like($@, qr/^AUR::Vercmp: vercmp failure/, 'non-zero exit status');
};

subtest 'vercmp not found dies' => sub {
    local $ENV{PATH} = tempdir(CLEANUP => 1);
    my $err;
    {
        local *STDERR;
        open STDERR, '>', \$err or die "redirect stderr: $!";
        eval { vercmp('1.0', '2.0', '<') };
    }
    ok($@, 'dies when exec fails');
};

subtest 'AUR_DEBUG prints call' => sub {
    local $ENV{AUR_DEBUG} = 1;
    my $err = '';
    {
        local *STDERR;
        open STDERR, '>', \$err or die "redirect stderr: $!";
        vercmp('1.0', '2.0', '<');
    }
    is($err, "AUR::Vercmp: vercmp 1.0 2.0\n", 'call on stderr');
};

subtest 'version ordering' => sub {
    ok(vercmp("1.0", "1.0", '='));
    ok(vercmp("1.0a", "1.0b", '<'));
    ok(vercmp("1", "1.0", '<='));
    ok(vercmp("1:1", "1", '>'));
    ok(vercmp("2.0", "1.0", '>='));
    ok(vercmp("abc", undef, '<'));

    # epoch takes precedence
    ok(vercmp("1:0.1", "9.9", '>'),  'epoch beats version');
    ok(vercmp("0:1.0", "1.0", '='),  'epoch 0 equals none');

    # alpha suffixes sort before release
    ok(vercmp("1.0alpha", "1.0", '<'), 'alpha before release');
    ok(vercmp("1.0rc1", "1.0", '<'),   'rc before release');

    # numeric, not lexical, comparison
    ok(vercmp("1.10", "1.9", '>'), '1.10 > 1.9');

    # pkgrel is only compared if both versions have one
    ok(vercmp("2.0-3", "2.0-3", '='));
    ok(vercmp("2.0-3", "2.0", '='));
    ok(!vercmp("2.0-3", "2.0-4", '='));
    ok(!vercmp("1:2.0-3", "2.0", '='));
    ok(!vercmp("2.0-3", "2.0-4", '>='));
    ok(vercmp("2.0-3", "2.0-4", '<'));
};

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
