package AUR::Exception;
use v5.40;

use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(run_main);

# bool: an exception is true whatever its message, for `if ($@)`
# fallback: eq, ne, . etc. are derived from ""
use overload '""' => \&message, bool => sub { 1 }, fallback => 1;

our $VERSION = 'unstable';

=head1 NAME

AUR::Exception - Structured error with exit code for AUR modules

=head1 SYNOPSIS

  use AUR::Exception;
  use Carp;

  use AUR::Exception qw(run_main);
  use Carp;

  croak(AUR::Exception->new("no packages found", 1));

  # top level of a program
  unless (caller) {
      run_main(sub {
          ...
      });
  }

=head1 DESCRIPTION

A lightweight exception class that carries a human-readable message
and a numeric exit code. When stringified (e.g. inside C<die> or
C<warn>) or compared as a string, the message is used. In boolean
context, an exception is always true.

Call C<croak> with parentheses. In a package that loads C<AUR::Exception>
at compile time, C<croak AUR::Exception-E<gt>new(...)> is parsed as the
method call C<AUR::Exception-E<gt>croak>.

Programs run their main code with C<run_main>, which prints the message
of an uncaught exception and exits with its exit code. Without it, Perl
exits with C<$!>, C<$? E<gt>E<gt> 8> or 255 on an uncaught exception, not
with the exit code.

=head1 FUNCTIONS

=head2 run_main($main)

Call C<$main> without arguments. If it throws an C<AUR::Exception>
(or subclass), print its message to standard error and exit with its
exit code. Other errors are re-thrown unchanged. Returns if C<$main>
returns; C<exit> inside C<$main> is not affected.

The message is printed as is: data from outside the program must be
sanitized where the message is built.

C<$main> is a closure, so C<shift> in it takes from C<@_> (empty), not
C<@ARGV>. Use C<shift @ARGV>.

=head1 METHODS

=head2 new($message, $exit_code)

Create an exception. C<$exit_code> defaults to 1, and must be an
integer from 1 to 255: 0 would report success, and C<exit> keeps only
the lower 8 bits of larger values. Croaks otherwise.

=head2 message()

Return the message.

=head2 exit_code()

Return the exit code.

=head1 SEE ALSO

=over

=item L<perlfunc/die>

Exit code of an uncaught exception (C<$!>, C<$? E<gt>E<gt> 8> or 255),
and why it should not be relied upon. C<$SIG{__DIE__}> is called inside
C<eval> too, so it cannot replace C<run_main>.

=item L<perlfunc/exit>

C<END> blocks and destructors run before the program exits, and can
change C<$?>. The exit status is truncated to its lower 8 bits
(C<status & 0377>, L<exit(3)>).

=item L<perlsyn/"Try Catch Exception Handling">, L<feature/"The 'try' feature">

C<try>/C<catch>, as used by C<run_main> (Perl 5.34; stable in 5.40).

=item L<perlobj/"Indirect Object Syntax">, L<feature/"The 'indirect' feature">

Why C<croak AUR::Exception-E<gt>new(...)> needs parentheses.

=item L<overload/"Magic Autogeneration">, L<overload/fallback>

Without a C<bool> method, truth is derived from C<"">; without
C<fallback>, C<eq> is not available.

=back

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut

sub new {
    my ($class, $message, $exit_code) = @_;
    $exit_code //= 1;

    if ($exit_code !~ /\A[0-9]+\z/ or not 1 <= $exit_code <= 255) {
        croak __PACKAGE__ . ": exit code must be an integer from 1 to 255";
    }
    return bless { message => $message, exit_code => $exit_code }, $class;
}

sub run_main {
    my ($main) = @_;

    try {
        $main->();
    }
    catch ($e) {
        # Re-throw other errors unchanged. blessed: $e may be a string or
        # an unblessed reference, which has no isa method. isa is true for
        # this class (__PACKAGE__) and its subclasses.
        die $e if not (blessed($e) and $e->isa(__PACKAGE__));

        say STDERR $e->message;
        exit($e->exit_code);
    }
    return;
}

sub message   { return $_[0]->{message} }
sub exit_code { return $_[0]->{exit_code} }

# vim: set et sw=4 sts=4 ft=perl:
