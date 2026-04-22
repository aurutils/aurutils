package AUR::Exception;
use strict;
use warnings;
use v5.20;

use overload '""' => \&message;

our $VERSION = 'unstable';

=head1 NAME

AUR::Exception - Structured error with exit code for AUR modules

=head1 SYNOPSIS

  use AUR::Exception;
  use Carp;

  croak AUR::Exception->new("no packages found", 1);

=head1 DESCRIPTION

A lightweight exception class that carries a human-readable message
and a numeric exit code. When stringified (e.g. inside C<die> or
C<warn>), only the message is returned.

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut

sub new {
    my ($class, $message, $exit_code) = @_;
    $exit_code //= 1;
    return bless { message => $message, exit_code => $exit_code }, $class;
}

sub message   { return $_[0]->{message} }
sub exit_code { return $_[0]->{exit_code} }

# vim: set et sw=4 sts=4 ft=perl:
