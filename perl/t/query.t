#!/usr/bin/env perl
use v5.40;
use File::Temp qw(tempdir tempfile);
use Test::More;

# dies { ... } returns the exception thrown by the block, or undef if
# there is none. Test2::Tools::Exception is part of perl since 5.40.
use Test2::Tools::Exception qw(dies);

# Check if module can be imported
require_ok "AUR::Query";

use AUR::Query qw(urlencode query query_multi);

# --- Fake curl ---
# Prints its arguments on one line, separated by tabs. FAKE_CURL selects
# other modes: `fail` exits non-zero, `multi` prints two lines, `utf8`
# prints U+00E9 encoded as UTF-8.
my $bindir = tempdir(CLEANUP => 1);
{
    open my $fh, '>', "$bindir/curl" or die "$bindir/curl: $!";
    print $fh <<'EOF';
#!/bin/sh
case $FAKE_CURL in
    fail)  echo 'curl: (22) The requested URL returned error: 503' >&2; exit 22 ;;
    multi) printf 'line1\nline2\n' ;;
    utf8)  printf '\303\251\n' ;;
    *)     printf '%s\t' "$@"; printf '\n' ;;
esac
EOF
    close $fh;
    chmod 0755, "$bindir/curl" or die "chmod: $!";
}
local $ENV{PATH} = "$bindir:$ENV{PATH}";
delete local $ENV{AUR_DEBUG};
delete local $ENV{FAKE_CURL};

# Fixed endpoint, independent of the caller's environment
local $AUR::Query::aur_rpc     = 'https://aur.test/rpc';
local $AUR::Query::aur_rpc_ver = 5;

# --- Helper: split fake curl output into arguments ---
sub curl_args {
    my ($response) = @_;
    chomp(my $line = $response);
    return split /\t/, $line;
}

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

# --- Helper: dies { ... } with standard error ---
# Standard error goes to a file, so that curl (a child process) writes
# there too. Returns the exception (or undef) and standard error.
sub dies_stderr :prototype(&) {
    my ($code) = @_;
    my ($fh, $file) = tempfile(UNLINK => 1);
    my $e;
    {
        open(my $saved, '>&', \*STDERR) or die "dup stderr: $!";
        open(STDERR, '>&', $fh) or die "redirect stderr: $!";
        $e = dies { $code->() };
        open(STDERR, '>&', $saved) or die "restore stderr: $!";
    }
    open my $in, '<', $file or die "$file: $!";
    my $err = do { local $/; <$in> };
    return ($e, $err);
}

my @curl_opts = ('-q', '-A', 'aurutils', '-fgLsS');

subtest 'urlencode: unreserved alphanumerics' => sub {
    is(urlencode('abcXYZ019'), 'abcXYZ019', 'unchanged');
    is(urlencode(''), '', 'empty string');
};

subtest 'urlencode: everything else is encoded' => sub {
    is(urlencode('foo-bar'),  'foo%2Dbar',   'hyphen');
    is(urlencode('foo_bar'),  'foo%5Fbar',   'underscore');
    is(urlencode('a.b~c'),    'a%2Eb%7Ec',   'dot and tilde');
    is(urlencode('a b'),      'a%20b',       'space');
    is(urlencode('c++'),      'c%2B%2B',     'plus');
    is(urlencode('a&b=c'),    'a%26b%3Dc',   'query separators');
    is(urlencode('a/b?#%'),   'a%2Fb%3F%23%25', 'path separators and percent');
    is(urlencode("\n"),       '%0A',         'newline');
};

subtest 'urlencode: two hex digits, upper case' => sub {
    is(urlencode("\x01"), '%01', 'zero padded');
    is(urlencode("\x1b"), '%1B', 'upper case');
};

subtest 'urlencode: characters are encoded as UTF-8' => sub {
    is(urlencode("\x{e9}"),    '%C3%A9',    'U+00E9');
    is(urlencode("\x{263a}"),  '%E2%98%BA', 'U+263A');
    is(urlencode("caf\x{e9}"), 'caf%C3%A9', 'mixed');
};

subtest 'query: GET request path' => sub {
    my @args = curl_args(query(type => 'info', term => 'foo'));

    is_deeply(\@args, [@curl_opts, 'https://aur.test/rpc/v5/info/foo'], 'curl arguments');
};

subtest 'query: term is url-encoded' => sub {
    my @args = curl_args(query(type => 'search', term => 'foo bar/baz'));

    is($args[-1], 'https://aur.test/rpc/v5/search/foo%20bar%2Fbaz', 'encoded term');
};

subtest 'query: by parameter' => sub {
    my @args = curl_args(query(type => 'search', term => 'foo', by => 'name-desc'));

    is($args[-1], 'https://aur.test/rpc/v5/search/foo?by=name-desc', 'by appended');
};

subtest 'query: RPC version and endpoint' => sub {
    local $AUR::Query::aur_rpc     = 'http://localhost/rpc.php';
    local $AUR::Query::aur_rpc_ver = 6;
    my @args = curl_args(query(type => 'info', term => 'foo'));

    is($args[-1], 'http://localhost/rpc.php/v6/info/foo', 'variables used');
};

subtest 'query: response returned with trailing newline' => sub {
    my $response = query(type => 'info', term => 'foo');
    like($response, qr/\n\z/, 'raw first line');
};

subtest 'query: response is decoded from UTF-8' => sub {
    local $ENV{FAKE_CURL} = 'utf8';
    is(query(type => 'info', term => 'foo'), "\x{e9}\n", 'character string');
};

subtest 'query: callback' => sub {
    my @seen;
    my $result = query(type => 'info', term => 'foo',
                       callback => sub { push @seen, @_; return 'cb' });

    is($result, 'cb', 'callback result returned');
    is(scalar @seen, 1, 'callback called once');
    like($seen[0], qr{/v5/info/foo\t}, 'callback receives response');
};

subtest 'query: callback list context' => sub {
    my @result = query(type => 'info', term => 'foo', callback => sub { return (1, 2, 3) });
    is_deeply(\@result, [1, 2, 3], 'list returned');
};

subtest 'query: missing term dies' => sub {
    eval { query(type => 'info') };
    like($@, qr/^query: no search term supplied/, 'dies');

    eval { query(type => 'info', term => undef) };
    like($@, qr/^query: no search term supplied/, 'dies on undef');
};

subtest 'query: term "0" is valid' => sub {
    my @args = curl_args(query(type => 'info', term => '0'));
    is($args[-1], 'https://aur.test/rpc/v5/info/0', 'false term accepted');
};

subtest 'query: AUR_DEBUG prints curl command' => sub {
    my ($status, $out, $err) = run_child(sub {
        local $ENV{AUR_DEBUG} = 1;
        query(type => 'info', term => 'foo');
    });
    is($status, 0, 'exit status 0');
    is($err, "'curl' '-q' '-A' 'aurutils' '-fgLsS' 'https://aur.test/rpc/v5/info/foo'\n",
       'quoted command on stderr');
};

subtest 'query: curl failure throws exit code 2' => sub {
    local $ENV{FAKE_CURL} = 'fail';
    my ($e, $err) = dies_stderr { query(type => 'info', term => 'foo') };

    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 2, 'exit code 2');
    is($e->message, 'AUR::Query: curl failed (exit status 22)', 'message');
    like($err, qr/^curl: \(22\)/, 'curl error on stderr');
};

subtest 'query: curl not found throws exit code 2' => sub {
    local $ENV{PATH} = tempdir(CLEANUP => 1);
    my ($e, $err) = dies_stderr { query(type => 'info', term => 'foo') };

    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 2, 'exit code 2');
    like($e->message, qr/^AUR::Query: curl: No such file or directory\z/, 'message');
};

subtest 'query: multi-line response throws exit code 2' => sub {
    local $ENV{FAKE_CURL} = 'multi';
    my ($e) = dies_stderr { query(type => 'info', term => 'foo') };

    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 2, 'exit code 2');
    is($e->message, 'AUR::Query: response error (multi-line output)', 'message');
};

subtest 'query: no zombie process after an error' => sub {
    local $ENV{FAKE_CURL} = 'multi';
    dies_stderr { query(type => 'info', term => 'foo') };
    is(waitpid(-1, 1), -1, 'curl reaped');  # 1: WNOHANG
};

subtest 'query_multi: POST request' => sub {
    my @responses = query_multi(type => 'info', terms => ['foo', 'bar']);

    is(scalar @responses, 1, 'one request');
    is_deeply([curl_args($responses[0])],
              [@curl_opts, 'https://aur.test/rpc/v5/info', '--data-raw', '&arg[]=foo&arg[]=bar'],
              'curl arguments');
};

subtest 'query_multi: terms are url-encoded' => sub {
    my ($response) = query_multi(type => 'info', terms => ['c++', 'a b']);
    is((curl_args($response))[-1], '&arg[]=c%2B%2B&arg[]=a%20b', 'encoded data');
};

subtest 'query_multi: splitno' => sub {
    my @terms = map { "pkg$_" } 1..5;
    my @responses = query_multi(type => 'info', terms => \@terms, splitno => 2);

    is(scalar @responses, 3, 'ceil(5/2) requests');
    is_deeply([map { (curl_args($_))[-1] } @responses],
              ['&arg[]=pkg1&arg[]=pkg2', '&arg[]=pkg3&arg[]=pkg4', '&arg[]=pkg5'],
              'terms split in order');
};

subtest 'query_multi: splitno equal to number of terms' => sub {
    my @responses = query_multi(type => 'info', terms => ['a', 'b'], splitno => 2);
    is(scalar @responses, 1, 'one request');
};

subtest 'query_multi: default splitno' => sub {
    local $AUR::Query::aur_splitno = 1;
    # Default argument is evaluated per call
    my @responses = query_multi(type => 'info', terms => ['a', 'b']);
    is(scalar @responses, 2, '$aur_splitno used');
};

subtest 'query_multi: terms array is emptied' => sub {
    my @terms = ('a', 'b', 'c');
    query_multi(type => 'info', terms => \@terms, splitno => 2);
    is(scalar @terms, 0, 'caller array consumed');
};

subtest 'query_multi: callback per request' => sub {
    my $calls = 0;
    my @results = query_multi(type => 'info', terms => ['a', 'b', 'c'], splitno => 1,
                              callback => sub { $calls++; return ("r$calls", "s$calls") });

    is($calls, 3, 'one callback per request');
    is_deeply(\@results, ['r1', 's1', 'r2', 's2', 'r3', 's3'], 'callback lists flattened');
};

subtest 'query_multi: no terms dies' => sub {
    eval { query_multi(type => 'info') };
    like($@, qr/^query_multi: no search terms supplied/, 'default terms');

    eval { query_multi(type => 'info', terms => []) };
    like($@, qr/^query_multi: no search terms supplied/, 'empty terms');
};

subtest 'query_multi: by croaks' => sub {
    eval { query_multi(type => 'search', terms => ['a'], by => 'name') };
    ok($@, 'croaks on by');
};

subtest 'query_multi: curl failure throws exit code 2' => sub {
    local $ENV{FAKE_CURL} = 'fail';
    my ($e) = dies_stderr { query_multi(type => 'info', terms => ['a']) };

    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 2, 'exit code 2');
};

subtest 'environment: defaults' => sub {
    my ($status, $out) = run_child(sub {
        delete local @ENV{qw(AUR_LOCATION AUR_QUERY_RPC AUR_QUERY_RPC_VERSION AUR_QUERY_RPC_SPLITNO)};
        delete $INC{'AUR/Query.pm'};
        no warnings 'redefine';
        require AUR::Query;
        say join(' ', $AUR::Query::aur_location, $AUR::Query::aur_rpc,
                      $AUR::Query::aur_rpc_ver, $AUR::Query::aur_splitno);
    });
    is($status, 0, 'module loaded');
    is($out, "https://aur.archlinux.org https://aur.archlinux.org/rpc 5 5000\n", 'default values');
};

subtest 'environment: AUR_LOCATION' => sub {
    my ($status, $out) = run_child(sub {
        delete local @ENV{qw(AUR_QUERY_RPC)};
        local $ENV{AUR_LOCATION} = 'https://aur.test';
        delete $INC{'AUR/Query.pm'};
        no warnings 'redefine';
        require AUR::Query;
        say $AUR::Query::aur_rpc;
    });
    is($out, "https://aur.test/rpc\n", 'endpoint derived from AUR_LOCATION');
};

subtest 'environment: overrides' => sub {
    my ($status, $out) = run_child(sub {
        local $ENV{AUR_LOCATION}          = 'https://aur.test';
        local $ENV{AUR_QUERY_RPC}         = 'https://rpc.test/api';
        local $ENV{AUR_QUERY_RPC_VERSION} = 6;
        local $ENV{AUR_QUERY_RPC_SPLITNO} = 100;
        delete $INC{'AUR/Query.pm'};
        no warnings 'redefine';
        require AUR::Query;
        say join(' ', $AUR::Query::aur_rpc, $AUR::Query::aur_rpc_ver, $AUR::Query::aur_splitno);
    });
    is($out, "https://rpc.test/api 6 100\n", 'AUR_QUERY_RPC takes precedence');
};

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
