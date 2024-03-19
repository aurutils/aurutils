package AUR::Srcinfo;
use strict;
use warnings;
use v5.20;

use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(parse expand);
our $VERSION   = 'unstable';

=head1 NAME

AUR::Srcinfo - Convert .SRCINFO files to perl dictionary

=head1 SYNOPSIS

  use AUR::Srcinfo qw(parse expand);

=head1 DESCRIPTION

=head1 AUTHORS

Alad Wenter <https://github.com/AladW/aurutils>

=cut

our @arrays = ('pkgname', 'arch', 'license', 'groups', 'options', 'conflicts', 'provides',
              'replaces', 'source', 'noextract', 'backup', 'validpgpkeys', 'b2sums', 'md5sums',
              'sha1sums', 'sha224sums', 'sha256sums', 'sha384sums', 'sha512sums', 'depends',
              'makedepends', 'checkdepends', 'optdepends'
          );

=item parse

Parameters:

=over

=item $fh

=back

=cut

sub parse {
    my ($fh) = @_;
    my $pkg_split;

    my %pkg = ();
    $pkg{'packages'} = {};
    my ($set_pkgbase, $set_pkgver, $set_pkgrel, $set_epoch) = (0, 0, 0, 0);

    while (my $row = <$fh>) {
        chomp($row);

        if ($row =~ /^$/) {
            # Use $pkgname as marker, reset on empty line
            $pkg_split = "";
        }
        else {
            my ($key, $value) = split(/=/, $row, 2);
            $key   =~ s/^\s+//;  # trim left
            $value =~ s/^\s+//;
            $key   =~ s/\s+$//;  # trim right

            # Global fields
            if ($key eq 'pkgbase') {
                # Consider package processed upon subsequent `pkgbase`
                last if (defined $pkg{'pkgbase'});

                $pkg{$key}   = $value;
                $set_pkgbase = 1;
                $pkg_split   = "";
            }
            # Handle remaining fields
            elsif ($key eq 'pkgname') {
                if (not $set_pkgbase) {
                    die __PACKAGE__ . ": pkgbase declared after pkgname";
                }
                $pkg{'packages'}{$value} = {};
                $pkg_split = $value;
            }
            elsif (grep /^$key/, @arrays) {
                if (length $pkg_split) {
                    push(@{$pkg{'packages'}{$pkg_split}{$key}}, $value);
                } else {
                    push(@{$pkg{$key}}, $value);
                }
            }
            else {
                if (length $pkg_split) {
                    $pkg{'packages'}{$pkg_split}{$key} = $value;
                } else {
                    $pkg{$key} = $value;
                }
            }
        }
    }
    if (not $set_pkgbase) {
        die __PACKAGE__ . ": pkgbase not set";
    }
    if (not scalar keys %{$pkg{'packages'}}) {
        die __PACKAGE__ . ": no packages defined";
    }
    return %pkg;
}

=item expand

=cut

# TODO
sub expand {
    # XXX: verify python-srcinfo behavior on ambiguous version keys
    #     if ($key eq 'pkgver') {                
    #         if ($set_pkgver) {
    #             die __PACKAGE__ . ": $key ambiguous";
    #         }
    #         $pkg{'Version'} = $pkg{'Version'} . $value;
    #         $set_pkgver = 1;
    #     }
    #     elsif ($key eq 'pkgrel') {
    #         if ($set_pkgrel) {
    #             die __PACKAGE__ . ": $key ambiguous";
    #         }
    #         $pkg{'Version'} = $pkg{'Version'} . "-" . $value;
    #         $set_pkgrel = 1;
    #     }
    #     elsif ($key eq 'epoch') {
    #         if ($set_epoch) {
    #             die __PACKAGE__ . ": $key ambiguous";
    #         }
    #         $pkg{'Version'} = $value . ":" . $pkg{'Version'};
    #         $set_epoch = 1;
    #     }
}
