#!/usr/bin/env perl
use v5.40;
# Test2::V0 is part of perl since 5.40. The srand plugin sets a fixed seed,
# which File::Temp would share between processes; the utf8 plugin changes
# the encoding of the source and of test output.
use Test2::V0 -no_srand => 1, -no_utf8 => 1;

use AUR::Options qw(add_from_stdin dump_options);

# --- Helper: run add_from_stdin with $input as standard input ---
# Returns the modified argument list.
sub with_stdin {
    my ($input, $args, $tokens) = @_;
    my @args = @{$args};

    local *STDIN;
    open STDIN, '<', \$input or die "redirect stdin: $!";
    add_from_stdin(\@args, $tokens);
    return @args;
}

# --- Helper: capture standard output of dump_options ---
# Returns the printed lines.
sub dump_lines {
    my ($spec) = @_;
    my $out = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$out or die "redirect stdout: $!";
        dump_options($spec);
    }
    return split /\n/, $out;
}

my @tokens = ('-', '/dev/stdin');

subtest 'add_from_stdin: no token, stdin untouched' => sub {
    my $input = "should\nnot\nbe\nread\n";
    my @args = ('foo', 'bar');

    local *STDIN;
    open STDIN, '<', \$input or die "redirect stdin: $!";
    add_from_stdin(\@args, \@tokens);

    is(\@args, ['foo', 'bar'], 'arguments unchanged');
    is(scalar(<STDIN>), "should\n", 'stdin not consumed');
};

subtest 'add_from_stdin: single token' => sub {
    is([with_stdin("a\nb\n", ['-'], \@tokens)], ['a', 'b'],
              'token replaced by stdin lines');
};

subtest 'add_from_stdin: alternative token' => sub {
    is([with_stdin("a\n", ['/dev/stdin'], \@tokens)], ['a'],
              '/dev/stdin replaced');
};

subtest 'add_from_stdin: stdin appended after remaining arguments' => sub {
    is([with_stdin("x\ny\n", ['foo', '-', 'bar'], \@tokens)],
              ['foo', 'bar', 'x', 'y'], 'token removed, stdin at end');
};

subtest 'add_from_stdin: multiple tokens read stdin once' => sub {
    is([with_stdin("x\n", ['-', 'foo', '/dev/stdin', '-'], \@tokens)],
              ['foo', 'x'], 'all tokens removed, stdin added once');
};

subtest 'add_from_stdin: adjacent tokens' => sub {
    # delete_elements splices from the end, indices stay valid
    is([with_stdin("x\n", ['a', '-', '-', 'b', '-'], \@tokens)],
              ['a', 'b', 'x'], 'adjacent tokens removed');
};

subtest 'add_from_stdin: empty stdin' => sub {
    is([with_stdin("", ['foo', '-'], \@tokens)], ['foo'],
              'token removed, nothing added');
};

subtest 'add_from_stdin: last line without newline' => sub {
    is([with_stdin("a\nb", ['-'], \@tokens)], ['a', 'b'],
              'final line kept');
};

subtest 'add_from_stdin: empty lines are kept' => sub {
    is([with_stdin("a\n\nb\n", ['-'], \@tokens)], ['a', '', 'b'],
              'empty line becomes empty argument');
};

subtest 'add_from_stdin: whitespace is kept' => sub {
    is([with_stdin(" a b \n", ['-'], \@tokens)], [' a b '],
              'line not split or trimmed');
};

subtest 'add_from_stdin: token match is exact' => sub {
    is([with_stdin("x\n", ['--', '-a', '/dev/stdin2'], \@tokens)],
              ['--', '-a', '/dev/stdin2'], 'no partial matches');
};

subtest 'add_from_stdin: chomp applies to existing arguments' => sub {
    # chomp runs over the whole array once stdin is read
    is([with_stdin("x\n", ["foo\n", '-'], \@tokens)], ['foo', 'x'],
              'trailing newline removed from argument');
};

subtest 'add_from_stdin: empty argument list' => sub {
    is([with_stdin("x\n", [], \@tokens)], [], 'nothing to replace');
};

subtest 'add_from_stdin: empty token list' => sub {
    is([with_stdin("x\n", ['-'], [])], ['-'], 'no tokens, no match');
};

subtest 'add_from_stdin: modifies array in place' => sub {
    my $input = "x\n";
    my @args = ('-');
    my $ref = \@args;

    local *STDIN;
    open STDIN, '<', \$input or die "redirect stdin: $!";
    add_from_stdin($ref, \@tokens);

    is(\@args, ['x'], 'caller array modified');
};

subtest 'dump_options: long and short names' => sub {
    is([dump_lines(['verbose|v'])], ['--verbose', '-v'], 'long then short');
};

subtest 'dump_options: argument suffix' => sub {
    is([dump_lines(['format|f=s'])],    ['--format:', '-f:'], '=s');
    is([dump_lines(['delim|d:s'])],     ['--delim:', '-d:'],  ':s (optional)');
    is([dump_lines(['count=i'])],       ['--count:'],         '=i');
    is([dump_lines(['ignore|i=s@'])],   ['--ignore:', '-i:'], '=s@');
};

subtest 'dump_options: all longs before all shorts' => sub {
    is([dump_lines(['a|all', 'b|bar=s', 'c'])],
              ['--all', '--bar:', '-a', '-b:', '-c'], 'grouped by length');
};

subtest 'dump_options: spec order kept within groups' => sub {
    is([dump_lines(['zeta', 'alpha', 'z', 'a'])],
              ['--zeta', '--alpha', '-z', '-a'], 'not sorted');
};

subtest 'dump_options: multiple aliases' => sub {
    is([dump_lines(['repo|database|d=s'])],
              ['--repo:', '--database:', '-d:'], 'all aliases printed');
};

subtest 'dump_options: dump-options is skipped' => sub {
    is([dump_lines(['dump-options', 'help|h'])], ['--help', '-h'],
              'dump-options omitted');
    is([dump_lines(['dump-options'])], [], 'nothing printed');
};

subtest 'dump_options: empty spec' => sub {
    is([dump_lines([])], [], 'nothing printed');
};

subtest 'dump_options: unsupported specs croak' => sub {
    for my $entry ('color!', 'c|color!', 'verbose+', '<>') {
        eval { dump_lines(['help', $entry]) };
        like($@, qr/^dump_options: unsupported option spec '\Q$entry\E'/, "'$entry' croaks");
    }
};

subtest 'dump_options: optional incremental argument' => sub {
    # `:+` is an argument type, not the `+` modifier
    is([dump_lines(['level|l:+'])], ['--level:', '-l:'], ':+');
};

subtest 'dump_options: spec as used by aur(1) programs' => sub {
    # aur-format, aur-depends etc. filter out references from @opt_spec
    my @opt_spec = ('format|f=s', \my $format, 'json', 'dump-options');
    is([dump_lines([grep { !ref } @opt_spec])],
              ['--format:', '--json', '-f:'], 'filtered spec');
};

done_testing();

# vim: set et sw=4 sts=4 ft=perl:
