package AUR;
use v5.40;

=head1 NAME

AUR - Perl modules for aurutils

=head1 DESCRIPTION

This package only reserves the C<AUR> namespace. The modules below are
used by the Perl programs of aur(1), and can be loaded separately:

=over

=item L<AUR::Depends>

Resolve and order dependencies of AUR packages.

=item L<AUR::Exception>

Errors with a message and an exit code.

=item L<AUR::Json>

Decode and encode AurJSON and other JSON input.

=item L<AUR::Options>

Helpers for option parsing.

=item L<AUR::Query>

Requests to the AurJSON interface.

=item L<AUR::Vercmp>

Compare package versions with vercmp(8).

=back

=head1 AUTHORS

Alad Wenter <https://github.com/AladW>

=cut
