package AUR::Term;
use v5.40;

use Exporter qw(import);
our @EXPORT_OK = qw(sanitize);
our $VERSION = 'unstable';

=head1 NAME

AUR::Term - Helpers for text output of AUR data

=head1 SYNOPSIS

  use AUR::Term qw(sanitize);

  say sanitize($pkg->{'Description'});

=head1 DESCRIPTION

AUR metadata such as package descriptions is written by AUR users. Text
output must not pass control characters from such fields to the
terminal, where they start escape sequences, or to line-based consumers,
where tabs and newlines forge columns and records.

=head1 FUNCTIONS

=head2 sanitize($str)

Return C<$str> with every C0 control character (U+0000 to U+001F,
including tab and newline), DEL (U+007F) and C1 control character
(U+0080 to U+009F) replaced by C<\xNN>, where C<NN> is its code point
in upper-case hexadecimal. Other characters, including backslashes, are
unchanged; the result is for display and cannot be reversed. C<undef>
is returned as is.

C<$str> must be a character string (decoded from UTF-8). On a byte
string, the C1 range matches UTF-8 continuation bytes and corrupts
non-ASCII text.

=cut

sub sanitize {
    my $str = shift;
    return $str if not defined $str;

    $str =~ s/([\x00-\x1F\x7F-\x9F])/sprintf('\\x%02X', ord $1)/ge;
    return $str;
}

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut

# vim: set et sw=4 sts=4 ft=perl:
