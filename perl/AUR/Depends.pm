package AUR::Depends;
use v5.40;

use List::Util qw(first);
use Carp;
use Exporter qw(import);
use AUR::Vercmp qw(vercmp);
use AUR::Exception;

use constant EX_SUCCESS => 0;
use constant EX_FAILURE => 1;
use constant EX_OUT_OF_RANGE => 34;
our @EXPORT_OK = qw(recurse prune graph tsort);
our $VERSION = 'unstable';

# Maximum number of calling the callback
our $aur_callback_max = $ENV{AUR_DEPENDS_CALLBACK_MAX} // 30;

=head1 NAME

AUR::Depends - Resolve dependencies from AUR package information

=head1 SYNOPSIS

  use AUR::Depends qw(recurse graph prune tsort);

  my ($results, $pkgdeps, $pkgmap) = recurse(\@targets, ['Depends', 'MakeDepends'], $callback);
  my ($dag, $dag_foreign) = graph($results, $pkgdeps, $pkgmap, 1, 1);
  my @removed = prune($dag, \@installed);

=head1 DESCRIPTION

Dependencies are resolved in steps. C<recurse> retrieves package
information level by level until all dependencies are known, C<graph>
builds a dependency graph and checks versioned dependencies, C<prune>
removes installed packages and what is only needed by them, and C<tsort>
sorts pairs of names topologically, as tsort(1).

Errors are thrown as L<AUR::Exception>.

=head1 ENVIRONMENT

=over

=item C<AUR_DEPENDS_CALLBACK_MAX>

The maximum number of callback calls in C<recurse> (default 30). This
limits the depth of the dependency tree.

=item C<AUR_DEBUG>

If set, each callback call is printed to standard error.

=back

=head1 FUNCTIONS

=cut

=head2 recurse($targets, $types, $callback)

Extracts dependency (C<$pkgdeps>) and provider (C<$pkgmap>)
information from an array of package information hashes, retrieved
through a callback function. An example is C<callback_query> in
aur-depends(1), which combines C<query_multi> from L<AUR::Query> with
C<parse_json_aur> from L<AUR::Json>.

Dependencies are tallied and only queried when newly encountered.

Verifying if any versioned dependencies can be fulfilled can be done
subsequently with the C<graph> function.

Parameters:

=over

=item C<$targets>

Reference to an array of package names to resolve.

=item C<$types>

Reference to an array of dependency fields to follow, out of
C<Depends>, C<MakeDepends>, C<CheckDepends> and C<OptDepends>.

=item C<$callback>

Called with a reference to an array of package names. Returns a list of
package hashes in AurJSON form (C<Name>, C<Version>, C<Provides> and the
dependency fields).

=back

Returns three hash references:

=over

=item C<$results>

Package name to package hash, for all packages found.

=item C<$pkgdeps>

Package name to a list of C<[$spec, $type]> pairs, such as
C<< ['foo>=1.0', 'Depends'] >>. Targets also depend on themselves with
type C<Self>.

=item C<$pkgmap>

Provided name to C<[$name, $version]> of the first package that
provides it.

=back

Targets that are not found are reported on standard error. Throws an
C<AUR::Exception> with exit code 1 if no packages are found, or 34 if
C<AUR_DEPENDS_CALLBACK_MAX> is reached.

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
    my $complete = 0;
    while ($a < $aur_callback_max)
    {
        if (defined $ENV{'AUR_DEBUG'}) {
            say STDERR join(" ", "callback: [$a]", @depends);
        }
        # Use callback to retrieve new hash of results
        my @level = $callback->(\@depends);

        if (not scalar(@level) and $a == 1) {
            $complete = 1;
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
            $complete = 1;
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
        croak(AUR::Exception->new(__PACKAGE__ . ": no packages found", EX_FAILURE));
    }
    # Check if request limits have been exceeded
    if (not $complete) {
        croak(AUR::Exception->new(__PACKAGE__ . ": total requests: $a (out of range)", EX_OUT_OF_RANGE));
    }
    return \%results, \%pkgdeps, \%pkgmap;
}

=head2 graph($results, $pkgdeps, $pkgmap, $verify, $provides)

For a set of package-dependency relations (C<$pkgdeps>) and providers
(C<$pkgmap>), verify if all dependencies and their versions can be
fulfilled by the available set of packages. Version relations are
checked with C<vercmp>.

Two hashes are kept: one for packages in the set (C<$dag>), and
another for packages outside it (C<$dag_foreign>). Only relations in
the former are checked.

Parameters:

=over

=item C<$results>, C<$pkgdeps>, C<$pkgmap>

As returned by C<recurse>.

=item C<$verify>

Check versioned dependencies with C<vercmp> (default true).

=item C<$provides>

Let providers in C<$pkgmap> take precedence over packages of the same
name.

=back

Returns two hash references, C<$dag> and C<$dag_foreign>, which map a
dependency to the packages that require it, and those to the dependency
type: C<< $dag->{$dependency}{$package} = $type >>. Dependencies that are
not in C<$results>, such as repository packages, are in C<$dag_foreign>.

Throws an C<AUR::Exception> listing every unfulfilled version
requirement.

=cut

# XXX: <results> only used for versions and checking if AUR target
sub graph {
    my ($results, $pkgdeps, $pkgmap, $verify, $provides) = @_;
    my (%dag, %dag_foreign);
    my @invalid;
    $verify //= 1;  # run vercmp by default

    # Iterate over packages
    for my $name (keys %{$pkgdeps}) {

        # Iterate over dependencies
        for my $dep (@{$pkgdeps->{$name}}) {
            my ($dep_spec, $dep_type) = @{$dep};  # ['foo>=1.0', 'Depends']

            # Retrieve dependency requirements
            my ($dep_name, $dep_op, $dep_req) = split(/(<=|>=|<|=|>)/, $dep_spec);

            if (defined $results->{$dep_name}) {
                # Provides take precedence over regular packages, unless
                # $provides is false.
                my ($prov_name, $prov_ver) = ($dep_name, $results->{$dep_name}->{'Version'});

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
                    push @invalid,
                        "invalid node: $prov_name=$prov_ver (required: $dep_op$dep_req by: $name)";
                }
            }
            # Dependency is foreign
            else {
                $dag_foreign{$dep_name}{$name} = $dep_type;
            }
        }
    }
    if (@invalid) {
        croak(AUR::Exception->new(__PACKAGE__ . ": " . join("\n", @invalid), EX_FAILURE));
    }
    return \%dag, \%dag_foreign;
}

=head2 prune($dag, $installed)

Remove specified nodes from a dependency graph. Every dependency is
checked against every pkgname provided (quadratic complexity).

The keys of removed nodes are returned in an array.

Parameters:

=over

=item C<$dag>

As returned by C<graph>. It is modified in place.

=item C<$installed>

Reference to an array of package names to remove, such as installed
packages. Packages that are only required by removed packages are
removed as well.

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

=head2 tsort($bfs, $input)

Topological sorting adapted from PerlPowerTools.

Performs depth-first traversal by default.

=over

=item C<$bfs>

Perform breadth-first traversal.

=item C<$input>

Reference to a flat array of pairs C<($before, $after)>, as read by
tsort(1). The array is emptied. A pair of equal names adds a node
without an edge.

=back

Returns the sorted list of names. Throws an C<AUR::Exception> if the
number of tokens is odd, or if the graph has a cycle.

=cut

sub tsort {
    my ($bfs, $input) = @_;
    $bfs //= 0;

    my %pairs;  # all pairs ($l, $r)
    my %npred;  # number of predecessors
    my %succ;   # list of successors
    my @output;

    if (scalar(@{$input}) % 2 == 1) {
        croak(AUR::Exception->new(__PACKAGE__ . ": odd number of tokens", EX_FAILURE));
    }

    while (@{$input}) {
        my $l = shift @${input};
        my $r = shift @${input};

        next if defined $pairs{$l}{$r};
        $pairs{$l}{$r}++;
        $npred{$l} += 0;

        next if $l eq $r;
        ++$npred{$r};
        push @{$succ{$l}}, $r;
    }

    # create a list of nodes without predecessors
    my @list = grep {!$npred{$_}} keys %npred;

    while (@list) {
        $_ = pop @list;
        push @output, $_;

        foreach my $child (@{$succ{$_}}) {
            if ($bfs) {     # breadth-first
                unshift @list, $child unless --$npred{$child};
            } else {        # depth-first (default)
                push @list, $child unless --$npred{$child};
            }

        }
    }
    if (grep {$npred{$_}} keys %npred) {
        croak(AUR::Exception->new(__PACKAGE__ . ": cycle detected", EX_FAILURE));
    }

    return @output;
}
=head1 AUTHORS

Alad Wenter <https://github.com/AladW/aurutils>

=cut

# vim: set et sw=4 sts=4 ft=perl:
