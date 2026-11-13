#!/usr/bin/env perl
use strict;
use warnings;
use v5.20;
use File::Temp qw(tempdir tempfile);
use Test::More;

# Check if module can be imported
require_ok "AUR::Vercmp";

use AUR::Vercmp qw(vercmp);

delete local $ENV{AUR_DEBUG};

# --- Fake vercmp ---
# Prints FAKE_VERCMP (default 0) and appends its arguments to FAKE_VERCMP_LOG.
# FAKE_VERCMP=fail exits non-zero.
my $bindir = tempdir(CLEANUP => 1);
{
    open my $fh, '>', "$bindir/vercmp" or die "$bindir/vercmp: $!";
    print $fh <<'EOF';
#!/bin/sh
[ -n "$FAKE_VERCMP_LOG" ] && echo "$*" >> "$FAKE_VERCMP_LOG"
[ "$FAKE_VERCMP" = fail ] && exit 1
echo "${FAKE_VERCMP:-0}"
EOF
    close $fh;
    chmod 0755, "$bindir/vercmp" or die "chmod: $!";
}

# --- Helper: run vercmp() against the fake binary ---
# Returns the result and the list of vercmp invocations.
sub fake_vercmp {
    my ($result, @args) = @_;
    my (undef, $log) = tempfile(UNLINK => 1);

    local $ENV{PATH} = "$bindir:$ENV{PATH}";
    local $ENV{FAKE_VERCMP} = $result;
    local $ENV{FAKE_VERCMP_LOG} = $log;
    my $ret = vercmp(@args);

    open my $in, '<', $log or die "$log: $!";
    chomp(my @calls = <$in>);
    return ($ret, @calls);
}

subtest 'unversioned dependency is always true' => sub {
    local $ENV{PATH} = '/nonexistent';   # vercmp must not be called

    ok(vercmp('1.0', undef, '>='), 'undef version');
    ok(vercmp('1.0', '2.0', undef), 'undef operator');
    ok(vercmp('1.0', undef, undef), 'both undef');
    ok(vercmp(undef, undef, '<'),   'undef left version');
    ok(vercmp('1.0', undef, '=='),  'invalid operator not checked');
};

subtest 'operator table' => sub {
    # vercmp result: -1 (ver1 < ver2), 0 (equal), 1 (ver1 > ver2)
    my %expect = (
        '<'  => { -1 => 1, 0 => 0, 1 => 0 },
        '<=' => { -1 => 1, 0 => 1, 1 => 0 },
        '>'  => { -1 => 0, 0 => 0, 1 => 1 },
        '>=' => { -1 => 0, 0 => 1, 1 => 1 },
        '='  => { -1 => 0, 0 => 1, 1 => 0 },
    );
    for my $op (sort keys %expect) {
        for my $result (-1, 0, 1) {
            my ($ret, @calls) = fake_vercmp($result, '1.0', '2.0', $op);
            is(!!$ret, !!$expect{$op}{$result}, "vercmp=$result, op $op");
            is_deeply(\@calls, ['1.0 2.0'], "vercmp called with versions ($op, $result)");
        }
    }
};

subtest '= with identical strings skips vercmp' => sub {
    my ($ret, @calls) = fake_vercmp(1, '1.0-1', '1.0-1', '=');

    ok($ret, 'equal strings');
    is(scalar @calls, 0, 'vercmp not called');
};

subtest 'other operators always call vercmp' => sub {
    for my $op ('<', '<=', '>', '>=') {
        my (undef, @calls) = fake_vercmp(0, '1.0', '1.0', $op);
        is(scalar @calls, 1, "vercmp called for $op");
    }
};

subtest 'invalid operator croaks' => sub {
    for my $op ('==', '!=', '<>', '', 'eq') {
        local $ENV{PATH} = '/nonexistent';
        eval { vercmp('1.0', '2.0', $op) };
        like($@, qr/^invalid vercmp operation at \Q${\__FILE__}\E/,
             "'$op' croaks at caller");
    }
};

subtest 'vercmp failure dies' => sub {
    eval { fake_vercmp('fail', '1.0', '2.0', '<') };
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
        fake_vercmp(0, '1.0', '2.0', '<');
    }
    is($err, "AUR::Vercmp: vercmp 1.0 2.0\n", 'call on stderr');
};

# Tests against vercmp(8) from pacman
SKIP: {
    my $found = grep { -x "$_/vercmp" } split /:/, $ENV{PATH};
    skip 'vercmp(8) not found', 1 if not $found;

    subtest 'vercmp(8): version ordering' => sub {
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
}

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
