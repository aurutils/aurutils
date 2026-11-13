package AUR::Exception;
use v5.40;

# bool: an exception is true whatever its message, for `if ($@)`
# fallback: eq, ne, . etc. are derived from ""
use overload '""' => \&message, bool => sub { 1 }, fallback => 1;

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
C<warn>) or compared as a string, the message is used. In boolean
context, an exception is always true.

Programs catch these exceptions at the top level, print the message and
exit with the exit code:

  use v5.40;

  try {
      main();
  }
  catch ($error) {
      if ($error isa AUR::Exception) {
          say STDERR $error->message;
          exit($error->exit_code);
      }
      die $error;
  }

=head1 METHODS

=head2 new($message, $exit_code)

Create an exception. C<$exit_code> defaults to 1.

=head2 message()

Return the message.

=head2 exit_code()

Return the exit code.

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
