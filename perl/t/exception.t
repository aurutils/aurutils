#!/usr/bin/env perl
use v5.40;
use Carp;
use File::Temp qw(tempfile);
use Test::More;

# Check if module can be imported
require_ok "AUR::Exception";

AUR::Exception->import(qw(run_main));

# --- Helper: run code in a child process ---
# Returns the exit status, standard output and standard error of the child.
sub run_child {
    my ($code) = @_;
    my ($out_fh, $out_file) = tempfile(UNLINK => 1);
    my ($err_fh, $err_file) = tempfile(UNLINK => 1);

    my $pid = fork // die "fork: $!";
    if ($pid == 0) {
        Test::More->builder->no_ending(1);
        open STDOUT, '>&', $out_fh or die "redirect stdout: $!";
        open STDERR, '>&', $err_fh or die "redirect stderr: $!";
        $code->();
        exit(0);
    }
    waitpid($pid, 0);
    my $status = $? >> 8;

    my @output = map {
        open my $in, '<', $_ or die "$_: $!";
        local $/; scalar <$in>;
    } ($out_file, $err_file);
    return ($status, @output);
}

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

subtest 'new: exit code must be from 1 to 255' => sub {
    is(AUR::Exception->new("msg", 255)->exit_code, 255, '255 accepted');

    for my $code (0, 256, -1, 1.5, '4x', ' 4', "4\n", '') {
        eval { AUR::Exception->new("msg", $code) };
        like($@, qr/^AUR::Exception: exit code must be an integer from 1 to 255 at \Q${\__FILE__}\E/,
             "'$code' croaks at caller");
    }
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
    eval { croak(AUR::Exception->new("croaked", 4)) };

    isa_ok($@, 'AUR::Exception');
    is($@->message,   'croaked', 'message survives croak');
    is($@->exit_code, 4,         'exit code survives croak');
};

subtest 'plain die is not an exception object' => sub {
    eval { die "plain\n" };

    ok(!blessed($@), 'string error not blessed');
    is($@, "plain\n", 'string error unchanged');
};

subtest 'run_main: returns if main returns' => sub {
    my $called = 0;
    my $ret = run_main(sub { $called++; return 'ignored' });

    is($called, 1, 'main called once');
    ok(!defined $ret, 'returns nothing');
};

subtest 'run_main: main is called without arguments' => sub {
    my @args;
    run_main(sub { @args = @_ });
    is(scalar @args, 0, '@_ empty');
};

subtest 'run_main: exception exits with its exit code' => sub {
    my ($status, $out, $err) = run_child(sub {
        run_main(sub { croak(AUR::Exception->new("AUR::Test: failed", 4)) });
    });
    is($status, 4, 'exit status 4');
    is($err, "AUR::Test: failed\n", 'message on stderr, no location');
    is($out, '', 'nothing on stdout');
};

subtest 'run_main: multi-line message is printed as is' => sub {
    my ($status, $out, $err) = run_child(sub {
        run_main(sub { die AUR::Exception->new("line 1\nline 2", 2) });
    });
    is($status, 2, 'exit status 2');
    is($err, "line 1\nline 2\n", 'both lines');
};

subtest 'run_main: empty message' => sub {
    my ($status, $out, $err) = run_child(sub {
        run_main(sub { die AUR::Exception->new("", 3) });
    });
    is($status, 3, 'exit status 3');
};

subtest 'run_main: subclass' => sub {
    @My::Exception2::ISA = ('AUR::Exception');
    my ($status) = run_child(sub {
        run_main(sub { die My::Exception2->new("sub", 5) });
    });
    is($status, 5, 'exit status of subclass');
};

subtest 'run_main: exception from a nested call' => sub {
    my $inner = sub { croak(AUR::Exception->new("inner", 6)) };
    my ($status) = run_child(sub {
        run_main(sub { my @x = map { $inner->() } 1..2 });
    });
    is($status, 6, 'propagates through subs and map');
};

subtest 'run_main: caught exception inside main' => sub {
    my ($status, $out) = run_child(sub {
        run_main(sub {
            eval { die AUR::Exception->new("handled", 7) };
            print "handled\n" if $@;
        });
    });
    is($status, 0, 'not handled by run_main');
    is($out, "handled\n", 'handled by main');
};

subtest 'run_main: plain die is re-thrown unchanged' => sub {
    eval { run_main(sub { die "plain\n" }) };
    is($@, "plain\n", 'string error');

    my $obj = bless {}, 'Other::Error';
    eval { run_main(sub { die $obj }) };
    is($@, $obj, 'other object');
};

subtest 'run_main: exit inside main' => sub {
    my ($status) = run_child(sub { run_main(sub { exit(3) }) });
    is($status, 3, 'exit status of main');
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
