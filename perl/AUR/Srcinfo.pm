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

# Attributes which (where applicable) match AurJson, such that output can be
# reused with `aur-format`.
# Note: `Version` has no matching .SRCINFO attribute, since it consists of
# epoch+pkgver+pkgrel.
# XXX: reuse types defined in `aur-format` (KEY => [<type>, <field>])
# XXX: some attributes (eg. changelog) have no equivalent AUR keys,
# and the transformation could be left in a different module
our %srcinfo_attributes = (
    'pkgbase'      => ['string', 'PackageBase' ],
    'pkgname'      => ['string', 'Name'        ],
    'pkgdesc'      => ['string', 'Description' ],
    'url'          => ['string', 'URL'         ],
    'arch'         => ['string', 'Arch'        ],
    'license'      => ['array',  'License'     ],
    'depends'      => ['array',  'Depends'     ],
    'makedepends'  => ['array',  'MakeDepends' ],
    'checkdepends' => ['array',  'CheckDepends'],
    'optdepends'   => ['array',  'OptDepends'  ],
    'provides'     => ['array',  'Provides'    ],
    'conflicts'    => ['array',  'Conflicts'   ]
);

=item parse

=cut

sub parse {
    my ($fh) = @_;
    my $split_pkg;
    my %pkg = ();
    $pkg{'Packages'} = ();
    my ($set_pkgbase, $set_pkgver, $set_pkgrel, $set_epoch) = (0, 0, 0, 0);

    while (my $row = <$fh>) {
        chomp($row);

        if ($row =~ /^$/) {
            # Use `pkgname` as marker, reset on empty line
            $split_pkg = "";
        }
        else {
            my ($key, $value) = split(/=/, $row, 2);
            $key   =~ s/^\s+//;  # trim left
            $value =~ s/^\s+//;
            $key   =~ s/\s+$//;  # trim right

            # Global fields
            if ($key eq 'pkgbase') {
                # $split_pkg = 0
                # Consider package processed upon subsequent `pkgbase`
                last if (defined $pkg{'PackageBase'});

                $pkg{'PackageBase'} = $value;
                $pkg{'Version'} = "";
                $set_pkgbase = 1;
            }
            # XXX: verify python-srcinfo behavior on ambiguous version keys
            elsif ($key eq 'pkgver') {                
                if ($set_pkgver) {
                    die __PACKAGE__ . ": $key ambiguous";
                }
                $pkg{'Version'} = $pkg{'Version'} . $value;
                $set_pkgver = 1;
            }
            elsif ($key eq 'pkgrel') {
                if ($set_pkgrel) {
                    die __PACKAGE__ . ": $key ambiguous";
                }
                $pkg{'Version'} = $pkg{'Version'} . "-" . $value;
                $set_pkgrel = 1;
            }
            elsif ($key eq 'epoch') {
                if ($set_epoch) {
                    die __PACKAGE__ . ": $key ambiguous";
                }
                $pkg{'Version'} = $value . ":" . $pkg{'Version'};
                $set_epoch = 1;
            }
            # Handle remaining fields
            elsif ($key eq 'pkgname') {
                if ($split_pkg) {
                    die __PACKAGE__ . ": $key not delimited by newline";
                }
                $pkg{'Packages'}{$value} = ();
                $split_pkg = $value;
            }
            # XXX: `pkgname` for a split package should be handled as `pkgbase`
            elsif (defined $srcinfo_attributes{$key} and
                   $srcinfo_attributes{$key}->[0] eq 'string') {
                my $label = $srcinfo_attributes{$key}->[1];

                if ($split_pkg) {
                    $pkg{'Packages'}{$split_pkg}{$label} = $value;
                } else {
                    $pkg{$label} = $value;
                }
            }
            elsif (defined $srcinfo_attributes{$key} and
                   $srcinfo_attributes{$key}->[0] eq 'array') {
                my $label = $srcinfo_attributes{$key}->[1];

                if ($split_pkg) {
                    push(@{$pkg{'Packages'}{$split_pkg}{$label}}, $value);
                } else {
                    push(@{$pkg{$label}}, $value);
                }
            }
        }
    }
    if (not $set_pkgbase) {
        die __PACKAGE__ . ": pkgbase not set";
    }
    if (not defined $pkg{'Packages'}) {
        die __PACKAGE__ . ": no packages defined";
    }
    return %pkg;
}

=item expand

=cut

sub expand {

}
