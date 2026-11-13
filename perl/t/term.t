#!/usr/bin/env perl
use v5.40;
use utf8;
use Test::More;

# Check if module can be imported
require_ok "AUR::Term";

use AUR::Term qw(sanitize);

subtest 'sanitize: printable ASCII unchanged' => sub {
    my $ascii = join('', map { chr } 0x20..0x7E);
    is(sanitize($ascii), $ascii, 'U+0020 to U+007E');
    is(sanitize(''), '', 'empty string');
};

subtest 'sanitize: C0 control characters' => sub {
    for my $cp (0x00..0x1F) {
        is(sanitize(chr($cp)), sprintf('\\x%02X', $cp), sprintf('U+%04X', $cp));
    }
};

subtest 'sanitize: DEL and C1 control characters' => sub {
    for my $cp (0x7F..0x9F) {
        is(sanitize(chr($cp)), sprintf('\\x%02X', $cp), sprintf('U+%04X', $cp));
    }
};

subtest 'sanitize: escape sequences' => sub {
    is(sanitize("\e[2Jfoo"),          '\x1B[2Jfoo',          'CSI (7-bit)');
    is(sanitize("\x{9b}31mfoo"),      '\x9B31mfoo',          'CSI (8-bit)');
    is(sanitize("\e]0;title\a"),      '\x1B]0;title\x07',    'OSC with BEL');
    is(sanitize("\e]52;c;Zm9v\e\\"),  '\x1B]52;c;Zm9v\x1B\\', 'OSC 52 with ST');
};

subtest 'sanitize: line structure' => sub {
    is(sanitize("a\tb"),   'a\x09b',   'tab');
    is(sanitize("a\nb"),   'a\x0Ab',   'newline');
    is(sanitize("a\r\nb"), 'a\x0D\x0Ab', 'CRLF');
};

subtest 'sanitize: non-ASCII characters unchanged' => sub {
    for my $str ('é', 'ß', '€', '日本語', "\x{1F600}", "\x{a0}", "\x{ff}") {
        is(sanitize($str), $str, sprintf('U+%04X', ord $str));
    }
};

subtest 'sanitize: backslashes unchanged' => sub {
    is(sanitize('a\x1Bb'), 'a\x1Bb', 'literal \x1B');
    is(sanitize('a\\b'),   'a\\b',   'backslash');
};

subtest 'sanitize: idempotent' => sub {
    my $once = sanitize("\e[2J\x{9b}\n\t€");
    is(sanitize($once), $once, 'sanitize(sanitize($s)) eq sanitize($s)');
};

subtest 'sanitize: undef' => sub {
    ok(!defined sanitize(undef), 'undef returned');
};

subtest 'sanitize: argument not modified' => sub {
    my $str = "a\eb";
    sanitize($str);
    is($str, "a\eb", 'copy');
};

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
