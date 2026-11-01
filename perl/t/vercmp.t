#!/usr/bin/env perl
use strict;
use warnings;
use v5.20;
use Test::More;

# Check if module can be imported
require_ok "AUR::Vercmp";

use AUR::Vercmp qw(vercmp);

ok(vercmp("1.0", "1.0", '='));
ok(vercmp("1.0a", "1.0b", '<'));
ok(vercmp("1", "1.0", '<='));
ok(vercmp("1:1", "1", '>'));
ok(vercmp("2.0", "1.0", '>='));
ok(vercmp("abc", undef, '<'));

# pkgrel is only compared if both versions have one
ok(vercmp("2.0-3", "2.0-3", '='));
ok(vercmp("2.0-3", "2.0", '='));
ok(!vercmp("2.0-3", "2.0-4", '='));
ok(!vercmp("1:2.0-3", "2.0", '='));
ok(!vercmp("2.0-3", "2.0-4", '>='));
ok(vercmp("2.0-3", "2.0-4", '<'));

done_testing();
