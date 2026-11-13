#!/usr/bin/env perl
use v5.40;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
# Test2::V0 is part of perl since 5.40. The srand plugin sets a fixed seed,
# which File::Temp would share between processes; the utf8 plugin changes
# the encoding of the source and of test output.
use Test2::V0 -no_srand => 1, -no_utf8 => 1;

use AUR::Json qw(parse_json parse_json_aur write_json);

subtest 'backend: JSON::XS or JSON::PP' => sub {
    my $ref = ref($AUR::Json::aur_json);
    ok($ref eq 'JSON::XS' || $ref eq 'JSON::PP', "backend is $ref");
};

subtest 'parse_json: object' => sub {
    my $obj = parse_json('{"Name":"foo","Version":"1.0-1"}');

    is(ref($obj), 'HASH', 'hash reference');
    is($obj, { Name => 'foo', Version => '1.0-1' }, 'content');
};

subtest 'parse_json: array' => sub {
    my $obj = parse_json('[1,"two",{"three":3}]');

    is(ref($obj), 'ARRAY', 'array reference');
    is($obj, [1, 'two', { three => 3 }], 'content');
};

subtest 'parse_json: nested values and literals' => sub {
    my $obj = parse_json('{"a":[],"b":{},"c":null,"d":true,"e":false,"f":1.5}');

    is($obj->{a}, [], 'empty array');
    is($obj->{b}, {}, 'empty object');
    ok(!defined $obj->{c},   'null is undef');
    ok($obj->{d},            'true');
    ok(!$obj->{e},           'false');
    is($obj->{f}, 1.5,       'number');
};

subtest 'parse_json: surrounding whitespace' => sub {
    is(parse_json("  [1]  "), [1], 'leading and trailing spaces');
    is(parse_json("{}\n"),    {},  'trailing newline');
};

subtest 'parse_json: unicode' => sub {
    my $obj = parse_json('{"s":"\u00e9"}');
    is($obj->{s}, "\x{e9}", 'escaped code point decoded');
};

subtest 'parse_json: text after the JSON value dies' => sub {
    eval { parse_json('{"a":1}{"b":2}') };
    ok($@, 'second object');
    eval { parse_json('[1] x') };
    ok($@, 'trailing text');
};

subtest 'parse_json: consecutive calls are independent' => sub {
    is(parse_json('[1]'), [1], 'first call');
    is(parse_json('[2]'), [2], 'second call');
    is(parse_json('{"x":3}'), { x => 3 }, 'third call');
};

subtest 'parse_json: empty string dies' => sub {
    eval { parse_json('') };
    ok($@, 'dies');
};

subtest 'parse_json: incomplete JSON dies' => sub {
    eval { parse_json('{"a":') };
    ok($@, 'dies');
};

subtest 'parse_json: malformed JSON dies' => sub {
    eval { parse_json('garbage') };
    ok($@, 'dies on malformed input');
};

subtest 'parse_json: scalar top-level value dies' => sub {
    for my $str ('"str"', '1', 'null', 'true') {
        eval { parse_json($str) };
        is($@, "expected JSON object or array\n", "$str rejected");
    }
};

subtest 'parse_json: error is one line without source location' => sub {
    for my $str ('', 'garbage', '{"a":', '{}{}') {
        eval { parse_json($str) };
        like($@, qr/\A[^\n]+\n\z/, "one line for '$str'");
        unlike($@, qr/ line \d+/,  "no source location for '$str'");
    }
};

subtest 'parse_json: state after a failed parse' => sub {
    eval { parse_json('{"a":') };

    my $obj = eval { parse_json('[1]') };
    is($obj, [1], 'valid input parses after incomplete input');

    eval { parse_json('garbage') };
    $obj = eval { parse_json('[1]') };
    is($obj, [1], 'valid input parses after malformed input');
};

subtest 'parse_json_aur: info/search response' => sub {
    my $str = '{"resultcount":2,"results":[{"Name":"a"},{"Name":"b"}],'
            . '"type":"multiinfo","version":5}';
    my @results = parse_json_aur($str);

    is(scalar @results, 2, 'two results');
    is([map { $_->{Name} } @results], ['a', 'b'], 'results in order');
};

subtest 'parse_json_aur: empty results' => sub {
    my @results = parse_json_aur('{"resultcount":0,"results":[],"type":"search","version":5}');
    is(scalar @results, 0, 'no results');
};

subtest 'parse_json_aur: array (suggest, metadata archive)' => sub {
    is([parse_json_aur('["foo","foo-git"]')], ['foo', 'foo-git'], 'suggest');
    is([parse_json_aur('[{"Name":"a"},{"Name":"b"}]')],
              [{ Name => 'a' }, { Name => 'b' }], 'metadata archive');
    is([parse_json_aur('[]')], [], 'empty array');
};

subtest 'parse_json_aur: single object (JSONL)' => sub {
    my @results = parse_json_aur('{"Name":"a","Version":"1-1"}');

    is(scalar @results, 1, 'one result');
    is($results[0], { Name => 'a', Version => '1-1' }, 'object returned as-is');
};

subtest 'parse_json_aur: null results is a single object' => sub {
    # `results` must be defined to be unpacked
    my @results = parse_json_aur('{"results":null,"Name":"a"}');

    is(scalar @results, 1, 'one result');
    is($results[0]{Name}, 'a', 'whole object returned');
};

subtest 'parse_json_aur: error response throws exit code 4' => sub {
    my $e = dies {
        parse_json_aur('{"error":"Too many package results.","resultcount":0,'
                     . '"results":[],"type":"error","version":5}');
    };
    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 4, 'exit code 4');
    is($e->message, 'AUR::Json: response error (Too many package results.)', 'message');
};

subtest 'parse_json_aur: error without results' => sub {
    # The error check only applies to responses with a `results` array
    my @results = parse_json_aur('{"error":"x"}');
    is(\@results, [{ error => 'x' }], 'returned as single object');
};

subtest 'parse_json_aur: scalar throws exit code 4' => sub {
    my $e = dies { parse_json_aur('"str"') };
    isa_ok($e, 'AUR::Exception');
    is($e->exit_code, 4, 'exit code 4');
    is($e->message, 'AUR::Json: invalid input (expected JSON object or array)', 'message');
};

subtest 'parse_json_aur: invalid input throws exit code 4' => sub {
    for my $str ('', 'garbage', '{"a":', '{}{}') {
        my $e = dies { parse_json_aur($str) };
        isa_ok($e, 'AUR::Exception');
        is($e->exit_code, 4, "exit code 4 for '$str'");
        like($e->message, qr/^AUR::Json: invalid input \(.+\)\z/s, "message for '$str'");
        unlike($e->message, qr/ line \d+/, "no source location for '$str'");
    }
};

subtest 'parse_json_aur: invalid input from a file handle' => sub {
    # die appends ", <$fh> line N." after reading from a handle
    my $e = dies {
        open my $fh, '<', \"garbage\n" or die;
        while (my $row = <$fh>) { parse_json_aur($row) }
    };
    isa_ok($e, 'AUR::Exception');
    unlike($e->message, qr/ line \d+/, 'no source location');
};

subtest 'parse_json_aur: invalid input, module path with spaces' => sub {
    # The location is removed by its file name: load the modules from a
    # path with spaces, which itself looks like a location
    my $dir = tempdir(CLEANUP => 1) . '/a b at c line 1';
    mkdir($dir) or die "mkdir: $!";
    symlink(dirname(abs_path($INC{'AUR/Json.pm'})), "$dir/AUR") or die "symlink: $!";

    # The first line of output is the path the module was loaded from
    open(my $fh, '-|', $^X, "-I$dir", '-MAUR::Json=parse_json_aur', '-e',
         'print $INC{"AUR/Json.pm"}, "\n"; eval { parse_json_aur("garbage") }; print $@->message')
        or die "perl: $!";
    chomp(my $path = <$fh>);
    my $message = do { local $/; <$fh> };
    close $fh;

    is($path, "$dir/AUR/Json.pm", 'module loaded from the path with spaces');
    like($message, qr/^AUR::Json: invalid input \(/, 'message');
    unlike($message, qr/ line \d+/, 'no source location');
};

subtest 'write_json: sorted keys, no newline' => sub {
    is(write_json({ b => 2, a => 1, c => 3 }), '{"a":1,"b":2,"c":3}', 'keys sorted');
    is(write_json({ z => { y => 1, x => 2 } }), '{"z":{"x":2,"y":1}}', 'nested keys sorted');
};

subtest 'write_json: arrays and literals' => sub {
    is(write_json([3, 1, 2]), '[3,1,2]', 'array order kept');
    is(write_json([]), '[]', 'empty array');
    is(write_json({}), '{}', 'empty hash');
    is(write_json([undef]), '[null]', 'undef is null');
    is(write_json(['1', 1]), '["1",1]', 'string and number distinguished');
};

subtest 'write_json: round trip' => sub {
    my $obj = { Name => 'foo', Depends => ['bar', 'baz>=1.0'], NumVotes => 10 };
    my $str = write_json($obj);

    is(parse_json($str), $obj, 'parse_json(write_json($obj))');
    is(write_json(parse_json($str)), $str, 'write_json(parse_json($str))');
};

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
