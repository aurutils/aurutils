package AUR::Depends;
use strict;
use warnings;
use v5.20;

use List::Util qw(first);
use Carp;
use Exporter qw(import);
use AUR::Vercmp qw(vercmp);
our @EXPORT_OK = qw(recurse prune graph);

use constant EX_SUCCESS => 0;
use constant EX_FAILURE => 1;
use constant EX_OUT_OF_RANGE => 34;
our $VERSION = 'unstable';

# Maximum number of calling the callback
our $aur_callback_max = $ENV{AUR_DEPENDS_CALLBACK_MAX} // 30;

=head1 NAME

AUR::Depends - Resolve dependencies from AUR package information

=head1 SYNOPSIS

  use AUR::Depends qw(recurse prune graph);

=head1 DESCRIPTION

=head1 AUTHORS

Alad Wenter <https://github.com/AladW/aurutils>

=cut

=head2 recurse()

Extracts dependency (C<$pkgdeps>) and provider (C<$pkgmap>)
information from an array of package information hashes, retrieved
through a callback function. An example is <callback_query> from
C<Query.pm> combined with <parse_json_aur> from C<Json.pm>.

Dependencies are tallied and only queried when newly encountered.

Verifying if any versioned dependencies can be fulfilled can be done
subsequently with the C<graph> function.

Parameters:

=over

=item C<$targets>

=item C<$types>

=item C<$callback>

=back

=cut

sub recurse {
    my ($targets, $types, $callback) = @_;
    my @depends = @{$targets};

    my (%results, %pkgdeps, %pkgmap, %tally);

    # Populate depends map with command-line targets (#1136)
    for my $target (@{$targets}) {
        push(@{$pkgdeps{$target}}, [$target, 'Self']);
    }

    # XXX: return $a for testing number of requests, e.g. 7 for ros-noetic-desktop
    my $a = 1;
    while ($a < $aur_callback_max)
    {
        if (defined $ENV{'AUR_DEBUG'}) {
            say STDERR join(" ", "callback: [$a]", @depends);
        }
        # Use callback to retrieve new hash of results
        my @level = $callback->(\@depends);

        if (not scalar(@level) and $a == 1) {
            last;  # no results
        }
        $a++;

        # Retrieve next level of dependencies from results
        @depends = ();

        for my $node (@level) {
            my $name    = $node->{'Name'};
            my $version = $node->{'Version'};
            $results{$name} = $node;

            # Iterate over explicit provides
            for my $spec (@{$node->{'Provides'} // []}) {
                my ($prov, $prov_version) = split(/=/, $spec);

                # XXX: the first provider takes precedence
                #      keep multiple providers and warn on ambiguity instead
                if (not defined $pkgmap{$prov} and $prov ne $name) {
                    $pkgmap{$prov} = [$name, $prov_version];
                }
            }

            # Filter out dependency types early (#882)
            $tally{$name} = $a;

            for my $deptype (@{$types}) {
                next if (not defined($node->{$deptype}));  # no dependency of this type

                for my $spec (@{$node->{$deptype}}) {
                    # Push versioned dependency to depends map
                    push(@{$pkgdeps{$name}}, [$spec, $deptype]);

                    # Valid operators (important: <= before <)
                    my ($dep, $op, $ver) = split(/(<=|>=|<|=|>)/, $spec);

                    # Avoid querying duplicate packages (#4)
                    next if defined $tally{$dep};
                    push(@depends, $dep);

                    # Mark as incomplete (retrieved in next level or repo package)
                    $tally{$dep} = $a;
                }
            }
        }
        if (not scalar(@depends)) {
            last;  # no further results
        }
    }
    # Print which targets have not been found
    for my $name (@{$targets}) {
        if (not defined $results{$name}) {
            say STDERR __PACKAGE__ . ": target not found: $name";
        }
    }
    # Check if results are available
    if (scalar keys %results == 0) {
        say STDERR __PACKAGE__ . ": no packages found";
        exit EX_FAILURE;
    }
    # Check if request limits have been exceeded
    if ($a == $aur_callback_max) {
        say STDERR __PACKAGE__ . ": total requests: $a (out of range)";
        exit EX_OUT_OF_RANGE;
    }
    return \%results, \%pkgdeps, \%pkgmap;
}

=head2 graph()

For a set of package-dependency relations (C<$pkgdeps>) and providers
(C<$pkgmap>), verify if all dependencies and their versions can be
fulfilled by the available set of packages. Version relations are
checked with C<vercmp>.

Two hashes are kept: one for packages in the set (C<$dag>), and
another for packages outside it (C<$dag_foreign>). Only relations in
the former are checked.

Parameters:

=over

=item C<$results>

=item C<$pkgdeps>

=item C<$pkgmap>

=item C<$verify>

=item C<$provides>

=back

=cut

# XXX: <results> only used for versions and checking if AUR target
sub graph {
    my ($results, $pkgdeps, $pkgmap, $verify, $provides) = @_;
    my (%dag, %dag_foreign);

    my $dag_valid = 1;
    $verify //= 1;  # run vercmp by default

    # Iterate over packages
    for my $name (keys %{$pkgdeps}) {
        # Add a loop to command-line targets (#402, #1065, #1136)
        if (defined $pkgdeps->{$name} and $pkgdeps->{$name} eq $name) {
            $dag{$name}{$name} = 'Self';
        }

        # Iterate over dependencies
        for my $dep (@{$pkgdeps->{$name}}) {
            my ($dep_spec, $dep_type) = @{$dep};  # ['foo>=1.0', 'Depends']

            # Retrieve dependency requirements
            my ($dep_name, $dep_op, $dep_req) = split(/(<=|>=|<|=|>)/, $dep_spec);

            if (defined $results->{$dep_name}) {
                # Split results version to pkgver and pkgrel
                my @dep_ver = split("-", $results->{$dep_name}->{'Version'}, 2);

                # Provides take precedence over regular packages, unless
                # $provides is false.
                my  ($prov_name, $prov_ver) = ($dep_name, $dep_ver[0]);

                if ($provides and defined $pkgmap->{$dep_name}) {
                    ($prov_name, $prov_ver) = @{$pkgmap->{$dep_name}};
                }

                # Run vercmp with provider and versioned dependency
                # XXX: a dependency can be both fulfilled by a package and a
                # different package (provides). In this case an error should
                # only be returned if neither fulfill the version requirement.
                if (not $verify or vercmp($prov_ver, $dep_req, $dep_op)) {
                    $dag{$prov_name}{$name} = $dep_type;
                }
                else {
                    say STDERR "invalid node: $prov_name=$prov_ver (required: $dep_op$dep_req by: $name)";
                    $dag_valid = 0;
                }
            }
            # Dependency is foreign
            else {
                $dag_foreign{$dep_name}{$name} = $dep_type;
            }
        }
    }
    if (not $dag_valid) {
        exit EX_FAILURE;
    }
    return \%dag, \%dag_foreign;
}

=head2 prune()

Remove specified nodes from a dependency graph. Every dependency is
checked against every pkgname provided (quadratic complexity).

The keys of removed nodes are returned in an array.

Parameters:

=over

=item C<$dag>

=item C<$installed>

=back

=cut

sub prune {
    my ($dag, $installed) = @_;

    if (not scalar @{$installed}) {
        return ();
    }
    my @removals;

    # Remove reverse dependencies for installed targets
    for my $dep (keys %{$dag}) {  # list returned by `keys` is a copy
        for my $name (keys %{$dag->{$dep}}) {
            my $found = first { $name eq $_ } @{$installed};

            if (defined $found) {
                delete $dag->{$dep}->{$found};
            }
        }
    }

    for my $dep (keys %{$dag}) {
        if (not scalar keys %{$dag->{$dep}}) {
            delete $dag->{$dep};  # Remove targets that are no longer required
            push(@removals, $dep);
        }
        my $found = first { $dep eq $_ } @{$installed};

        if (defined $found) {
            delete $dag->{$dep};  # Remove targets that are installed
            push(@removals, $dep);
        }
    }
    # Remove non-unique elements
    @removals = keys %{{ map { $_ => 1 } @removals }};

    # Remove dependencies recursively (#1184)
    push(@removals, prune($dag, \@removals));

    # XXX: return complement dict instead of array
    return @removals;
}

# vim: set et sw=4 sts=4 ft=perl:
