#!/usr/bin/env perl
use strict;
use warnings;
use v5.20;
use Test::More;

# Check if module can be imported
require_ok "AUR::Srcinfo";

use AUR::Srcinfo qw(parse expand);

done_testing();
