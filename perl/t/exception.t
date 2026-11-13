#!/usr/bin/env perl
use v5.40;
use Carp;
use Test::More;

# Check if module can be imported
require_ok "AUR::Exception";

subtest 'new: message and exit code' => sub {
    my $e = AUR::Exception->new("no packages found", 3);

    isa_ok($e, 'AUR::Exception');
    is($e->message,   'no packages found', 'message accessor');
    is($e->exit_code, 3,                   'exit_code accessor');
};

subtest 'new: exit code defaults to 1' => sub {
    is(AUR::Exception->new("msg")->exit_code,        1, 'omitted exit code');
    is(AUR::Exception->new("msg", undef)->exit_code, 1, 'undef exit code');
};

subtest 'new: exit code 0 is kept' => sub {
    # $exit_code //= 1, not ||=
    is(AUR::Exception->new("msg", 0)->exit_code, 0, 'exit code 0 not replaced');
};

subtest 'new: subclass' => sub {
    @My::Exception::ISA = ('AUR::Exception');
    my $e = My::Exception->new("sub", 5);

    isa_ok($e, 'My::Exception');
    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 5, 'inherited accessor');
};

subtest 'stringification: returns message' => sub {
    my $e = AUR::Exception->new("dependency cycle", 2);

    is("$e", 'dependency cycle', 'interpolation');
    is($e . '!', 'dependency cycle!', 'concatenation');
    is(sprintf('%s', $e), 'dependency cycle', 'sprintf %s');
};

subtest 'die: object is preserved in $@' => sub {
    eval { die AUR::Exception->new("died", 7) };

    ok(blessed($@), '$@ is blessed');
    isa_ok($@, 'AUR::Exception');
    is($@->exit_code, 7, 'exit code survives die');
    is("$@", 'died', 'no location appended to object');
};

subtest 'croak: object is preserved in $@' => sub {
    eval { croak AUR::Exception->new("croaked", 4) };

    isa_ok($@, 'AUR::Exception');
    is($@->message,   'croaked', 'message survives croak');
    is($@->exit_code, 4,         'exit code survives croak');
};

subtest 'catch pattern from POD' => sub {
    my ($message, $code);
    try {
        croak AUR::Exception->new("caught", 6);
    }
    catch ($error) {
        if ($error isa AUR::Exception) {
            ($message, $code) = ($error->message, $error->exit_code);
        }
    }
    is($message, 'caught', 'message from handler');
    is($code,    6,        'exit code from handler');
};

subtest 'catch pattern: plain die is not an exception object' => sub {
    eval { die "plain\n" };

    ok(!blessed($@), 'string error not blessed');
    is($@, "plain\n", 'string error unchanged');
};

subtest 'top-level exit code' => sub {
    # Child process mirrors the handler in aur-depends
    my $pid = fork // die "fork: $!";
    if ($pid == 0) {
        Test::More->builder->no_ending(1);
        open STDERR, '>', '/dev/null';
        try {
            croak AUR::Exception->new("child", 9);
        }
        catch ($error) {
            exit($error->exit_code) if $error isa AUR::Exception;
            exit(255);
        }
        exit(0);
    }
    waitpid($pid, 0);
    is($? >> 8, 9, 'process exits with exception exit code');
};

subtest 'overload: string comparison' => sub {
    my $e = AUR::Exception->new("msg");

    ok($e eq 'msg',   'eq compares the message');
    ok($e ne 'other', 'ne compares the message');
    is(length($e), 3, 'length of the message');
};

subtest 'overload: boolean context' => sub {
    # bool would otherwise be derived from "", making an empty message
    # false: handlers using `if ($@)` would miss the exception
    ok(AUR::Exception->new("msg"), 'non-empty message is true');
    ok(AUR::Exception->new(""),    'empty message is true');
    ok(AUR::Exception->new("0"),   'message "0" is true');

    eval { die AUR::Exception->new("") };
    ok($@, '$@ is true for an empty message');
};

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
