package AUR::Options;
use strict;
use warnings;
use v5.20;
use Carp;

use Exporter qw(import);
our @EXPORT_OK = qw(add_from_stdin dump_options);
our $VERSION = 'unstable';

=head1 NAME

AUR::Options - Option parsing for AUR scripts

=head1 SYNOPSIS

  use AUR::Options;
  add_from_stdin(\@ARGV, ['-', '/dev/stdin']);

=head1 DESCRIPTION

This module contains methods to assist with option parsing, specifically
when taking arguments from standard input.

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut

sub delete_elements {
    my ($array_ref, @indices) = @_;

    # Remove indices from end of array first
    for (sort { $b <=> $a } @indices) {
        splice @{$array_ref}, $_, 1;
    }
}

=head2 add_from_stdin()

=cut

sub add_from_stdin {
    my ($array_ref, $tokens) = @_;
    my @indices;

    for my $idx (0..@{$array_ref}-1) {
        my $match = grep { $array_ref->[$idx] eq $_ } @{$tokens};
        push(@indices, $idx) if $match > 0;
    }

    if (scalar @indices > 0) {
        delete_elements($array_ref, @indices);

        push(@{$array_ref}, <STDIN>);  # add arguments from stdin
        chomp(@{$array_ref});          # remove newlines
    }
}

=head2 dump_options()

Print long and short options from a GetOptions spec list, one per
line, matching the format of the bash --dump-options output.
Argument-taking options carry a trailing C<:>.

=cut

sub dump_options {
    my ($spec) = @_;
    my (@long, @short);

    for my $entry (@{$spec}) {
        # Split "name|alias|alias2=s" into names and type
        my ($names, $type) = split /[=:]/, $entry, 2;
        my $suffix = defined $type ? ':' : '';

        for my $name (split /\|/, $names) {
            next if $name eq 'dump-options';

            if (length($name) == 1) {
                push @short, "-${name}${suffix}";
            } else {
                push @long, "--${name}${suffix}";
            }
        }
    }
    say for @long;
    say for @short;
}

# vim: set et sw=4 sts=4 ft=perl:
