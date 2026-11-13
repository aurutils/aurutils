package AUR::Json;
use v5.40;

use Carp;
use AUR::Exception;
use AUR::Term qw(sanitize);
use Exporter qw(import);
our @EXPORT_OK = qw(parse_json parse_json_aur write_json);
our $VERSION = 'unstable';

=head1 NAME

AUR::Json - Perl interface to AurJson

=head1 SYNOPSIS

  use AUR::Json qw(parse_json_aur write_json);

  my $json;
  my @results = parse_json_aur($json);
  my $object  = parse_json($json);
  my $str     = write_json($object);

=head1 DESCRIPTION

This module provides Perl aur(1) scripts a coherent way to deal with
AurJson responses. In particular, parse_json_aur() returns an array of
package results for variable AUR inputs (both from AurJson and
metadata archives.

If JSON::XS is available, this module will use it for JSON
parsing. JSON::PP shipped with Perl is used as a fallback.

TODO: The interface is in its early stages and is prone to change in
later versions. Possible additions include AUR types for common use
with aur-format(1) and aur-search(1).

=head1 FUNCTIONS

=cut

our $aur_json;

# Fallback to slower perl-based JSON parsing
if (eval { require JSON::XS; 1 }) {
    $aur_json = JSON::XS->new;
}
else {
    require JSON::PP;
    $aur_json = JSON::PP->new;
}

=head2 parse_json($str)

Decode the JSON text in C<$str> and return the resulting hash or array
reference. Whitespace around the text is allowed. Dies if C<$str> is
not valid JSON, has text after the first JSON value, or is not an
object or array. The error is one line, without a source location.

=cut

sub parse_json {
    my $str = shift;
    my $obj;

    try {
        $obj = $aur_json->decode($str);
    }
    catch ($e) {
        # decode croaks with the location of this file
        $e =~ s/ at \Q${\__FILE__}\E line \d+(?:, <\S*> (?:line|chunk) \d+)?\.\n\z//;
        chomp($e);
        die "$e\n";
    }

    if (ref($obj) ne 'HASH' and ref($obj) ne 'ARRAY') {
        die "expected JSON object or array\n";
    }
    return $obj;
}

=head2 parse_json_aur($str)

Decode an AUR response and return its package results as a list of hash
references:

=over

=item * the C<results> array of an AurJSON response (C<info>, C<search>)

=item * the elements of a JSON array (C<suggest>, metadata archives such
as F<packages-meta-v1.json>)

=item * a single JSON object (one line of JSONL, as printed by
aur-repo-parse(1))

=back

If C<$str> is not valid input for C<parse_json>, or the response
contains an C<error>, an L<AUR::Exception> with exit code 4 is thrown.

=cut

sub parse_json_aur {
    my $str = shift;
    my $obj;

    try {
        $obj = parse_json($str);
    }
    catch ($e) {
        chomp($e);
        croak(AUR::Exception->new(__PACKAGE__ . ': invalid input (' . sanitize($e) . ')', 4));
    }

    # Possible AUR responses:
    # - JSON arrays: REST (suggests), metadata archives (packages-meta-v1.json)
    # - JSON hashes, `results` array: REST (info, search)
    # - JSON hashes: `repo-parse` (JSONL)
    if (ref($obj) eq 'HASH' and defined($obj->{'results'})) {
        my $error = $obj->{'error'};

        if (defined($error)) {
            croak(AUR::Exception->new(__PACKAGE__ . ': response error (' . sanitize($error) . ')', 4));
        }
        return @{$obj->{'results'}};
    }
    elsif (ref($obj) eq 'HASH') {
        return ($obj);
    }
    else {
        return @{$obj};  # ARRAY, checked by parse_json
    }
}

=head2 write_json($obj)

Encode a hash or array reference as JSON, with sorted keys, and return
the string (without a trailing newline).

=cut

sub write_json {
    my $obj = shift;
    my $str = $aur_json->canonical()->encode($obj);
    return $str;
}

=head1 AUTHORS

Alad Wenter <https://github.com/AladW/aurutils>

=cut

# vim: set et sw=4 sts=4 ft=perl:
