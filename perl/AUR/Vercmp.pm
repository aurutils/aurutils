package AUR::Vercmp;
use v5.40;

use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(vercmp);
our $VERSION = 'unstable';

=head1 NAME

AUR::Vercmp - Compare package versions with vercmp(8)

=head1 SYNOPSIS

  use AUR::Vercmp qw(vercmp);

  vercmp('1.0-2', '1.0-1', '>');   # true
  vercmp('1.0', undef, '>=');      # true: unversioned dependency

=head1 DESCRIPTION

If C<AUR_DEBUG> is set, calls of vercmp(8) are printed to standard error.

=head1 FUNCTIONS

=cut

sub vercmp_run {
    if (defined $ENV{'AUR_DEBUG'}) {
        say STDERR __PACKAGE__ . ': vercmp ' . join(" ", @_);
    }
    my @command = ('vercmp', @_);
    my $child_pid = open(my $fh, "-|", @command) or die $!;
    my $num;

    if ($child_pid) {
        $num = <$fh>;
        waitpid($child_pid, 0);
    }
    die __PACKAGE__ . ": vercmp failure" if $?;
    return $num;
}

sub vercmp_ops {
    my %ops = (
        '<'  => sub { $_[0] <  $_[1] },
        '>'  => sub { $_[0] >  $_[1] },
        '<=' => sub { $_[0] <= $_[1] },
        '>=' => sub { $_[0] >= $_[1] },
    );
    return %ops;
}

=head2 vercmp($ver1, $ver2, $op)

This function provides a simple way to call C<vercmp(8)> from perl code.
Instead of ordering versions on the command-line, this function takes
an explicit comparison operator (<, >, =, <= or >=) as argument.

Under the hood, this function calls the C<vercmp> binary explicitly.
This avoids any rebuilds for C<libalpm.so> soname bumps. To keep the approach
performant, C<vercmp> is not called for the C<=> operator, which compares
the strings.

Returns true if C<$ver1 $op $ver2> holds. If C<$ver2> or C<$op> is
undefined (an unversioned dependency), the result is always true. Dies
on an unknown operator, or if C<vercmp> fails.

As with C<vercmp> and pacman, C<pkgrel> is only compared if both versions
have one, so that C<2.0-3> equals C<2.0> but not C<2.0-4>.

=cut

sub vercmp {
    my ($ver1, $ver2, $op) = @_;
    my %cmp = vercmp_ops();

    if (not defined $ver2 or not defined $op) {
        return "true";  # unversioned dependency
    }
    elsif ($op eq '=') {
        return ($ver1 eq $ver2 or vercmp_run($ver1, $ver2) == 0);
    }
    elsif (defined $cmp{$op}) {
        # check if cmp(ver1, ver2) holds        
        return $cmp{$op}->(vercmp_run($ver1, $ver2), 0);
    }
    else {
        croak "invalid vercmp operation";
    }
}

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut
