package AUR::Query;
use v5.40;
use Carp;
use AUR::Exception;

use Exporter qw(import);
our @EXPORT_OK = qw(urlencode query query_multi);
our $VERSION = 'unstable';

=head1 NAME

AUR::Query - Retrieve data from AurJSON

=head1 SYNOPSIS

  use AUR::Query;

  # type=search, one GET request per argument
  my $search = query(term => 'foo', type => 'search', by => 'name-desc');

  # type=info, one POST request for multiple arguments
  my @info = query_multi(terms => ['bar', 'baz'], type => 'info');

=head1 DESCRIPTION

This module offers perl aur(1) scripts a direct way to retrieve data from AurJson
using GET or POST requests. Arguments are url-encoded beforehand.

Requests are made with curl(1). If curl is not found, fails, or prints
more than one line, an L<AUR::Exception> with exit code 2 is thrown.
This generic code avoids overlap with exit codes of other programs in
pipelines, such as aur-repo(1).

=head1 ENVIRONMENT

=over

=item C<AUR_LOCATION>

The AUR to use. Defaults to L<https://aur.archlinux.org>.

=item C<AUR_QUERY_RPC>

The AurJSON endpoint. Defaults to F<$AUR_LOCATION/rpc>.

=item C<AUR_QUERY_RPC_VERSION>

The AurJSON version. Defaults to 5.

=item C<AUR_QUERY_RPC_SPLITNO>

The maximum number of arguments per request of C<query_multi>. Defaults
to 5000.

=item C<AUR_DEBUG>

If set, curl commands are printed to standard error.

=back

=head1 FUNCTIONS

=cut

# environment variables
our $aur_location = $ENV{AUR_LOCATION}  // 'https://aur.archlinux.org';
our $aur_rpc      = $ENV{AUR_QUERY_RPC} // $aur_location . "/rpc";
our $aur_rpc_ver  = $ENV{AUR_QUERY_RPC_VERSION} // 5;
our $aur_splitno  = $ENV{AUR_QUERY_RPC_SPLITNO} // 5000;

=head2 urlencode($str)

Return C<$str> with every character except C<A-Z>, C<a-z> and C<0-9>
percent-encoded. C<$str> is a byte string, such as an undecoded
argument from C<@ARGV>: UTF-8 input results in percent-encoded UTF-8.
Characters above U+00FF are not encoded correctly.

=cut

# https://code.activestate.com/recipes/577450-perl-url-encode-and-decode/#c6
sub urlencode {
    my $s = shift;
    $s =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
    return $s;
}

sub query_curl {
    my @cmd = ('curl', '-q', '-A', 'aurutils', '-fgLsS', @_);
    
    if (defined $ENV{'AUR_DEBUG'}) {
        say STDERR join(" ", map(qq/'$_'/, @cmd));
    }
    # A generic exit code on `curl` failure, to avoid overlap with codes
    # from other tools which use pipelines (`aur-repo`, `aur-vercmp`).
    my $child_pid = open(my $fh, "-|", @cmd)
        or croak(AUR::Exception->new(__PACKAGE__ . ": curl: $!", 2));

    my $str = <$fh>;
    my $multi_line = defined(<$fh>);
    waitpid($child_pid, 0);

    if ($?) {
        croak(AUR::Exception->new(__PACKAGE__ . ": curl failed (exit status " . ($? >> 8) . ")", 2));
    }
    if ($multi_line) {
        croak(AUR::Exception->new(__PACKAGE__ . ": response error (multi-line output)", 2));
    }
    return $str;
}

=head2 query(type => $type, term => $term, by => $by, callback => $callback)

Send a GET request for one term, such as C<< type => 'search' >>, and
return the response string. C<by> selects the search field (for example
C<name-desc>). If C<callback> is given, the response is passed to it and
its result is returned instead. Dies if no term is given.

=cut

# XXX: accept arbitrary suffix/parameter instead of $by
sub query {
    my %args = (type => undef, term => undef, by => undef, callback => undef, @_);
    if (not defined $args{term}) {
        die 'query: no search term supplied';
    }
    my $term = urlencode($args{term});
    my $path = "$aur_rpc/v$aur_rpc_ver/$args{type}/$term";

    if (defined $args{by}) {
        $path = join('?by=', $path, $args{by});
    }
    my $response = query_curl($path);

    defined $args{callback} ? return $args{callback}->($response)
                            : return $response;
}

=head2 query_multi(type => $type, terms => \@terms, splitno => $n, callback => $callback)

Send POST requests for many terms, such as C<< type => 'info' >>, with at
most C<splitno> terms per request, and return the list of responses (or
of C<callback> results, if given). The C<@terms> array is emptied. Dies
if no terms are given; C<by> is not supported (use C<query>).

=cut

# XXX: this can also be used to split GET requests
sub query_multi {
    my %args = (type => undef, terms => [], splitno => $aur_splitno, callback => undef, @_);
    croak if defined $args{by}; # searches should be done with query()
    
    if (scalar @{$args{terms}} == 0) {
        die 'query_multi: no search terms supplied';
    }
    my @results;

    # n-ary queue processing (aurweb term limit)
    while (my @next = splice(@{$args{terms}}, 0, $args{splitno})) {
        my $data;
        map { $data .= '&arg[]=' . urlencode($_) } @next;

        # XXX: let callback handle both @results and $response (aur-search union/intersection)
        my $response = query_curl("$aur_rpc/v$aur_rpc_ver/$args{type}", '--data-raw', $data);

        defined $args{callback} ? push(@results, $args{callback}->($response))
                                : push(@results, $response);
    }
    return @results;
}

=head1 SEE ALSO

=over

=item L<AUR::Exception>

Exceptions thrown on C<curl> failure, and C<run_main>.

=item L<perlfunc/open>

The list form of a piped open runs C<curl> without a shell, and returns
the pid of the subprocess.

=item L<perlvar/"$?">

The exit status of C<curl> is C<$? E<gt>E<gt> 8> after C<waitpid>.

=item L<perllocale>

C<$!> (in the message for a missing C<curl>) is translated according to
C<LC_MESSAGES> only within the scope of C<use locale>.

=back

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut

# vim: set et sw=4 sts=4 ft=perl:
