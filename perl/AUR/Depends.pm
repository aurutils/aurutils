package AUR::Depends;
use strict;
use warnings;
use v5.20;

use List::Util qw(first);
use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(vercmp recurse prune graph solve);
our $VERSION = 'unstable';

# Maximum number of calling the callback
our $aur_callback_max = $ENV{AUR_DEPENDS_CALLBACK_MAX} // 30;

=head1 NAME

AUR::Depends - Resolve dependencies from AUR package information

=head1 SYNOPSIS

  use AUR::Depends qw(vercmp recurse prune graph solve);

=head1 DESCRIPTION

=head1 AUTHORS

Alad Wenter <https://github.com/AladW/aurutils>

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

=head2 vercmp()

This function provides a simple way to call C<vercmp(8)> from perl code.
Instead of ordering versions on the command-line, this function takes
an explicit comparison operator (<, >, =, <= or >=) as argument.

Under the hood, this function calls the C<vercmp> binary explicitly.
This avoids any rebuilds for C<libalpm.so> soname bumps. To keep the approach
performant, C<vercmp> is only called when input versions differ.

=cut

sub vercmp {
    my ($ver1, $ver2, $op) = @_;
    my %cmp = vercmp_ops();

    if (not defined $ver2 or not defined $op) {
        return "true";  # unversioned dependency
    }
    elsif ($op eq '=') {
        return $ver1 eq $ver2;
    }
    elsif (defined $cmp{$op}) {
        # check if cmp(ver1, ver2) holds        
        return $cmp{$op}->(vercmp_run($ver1, $ver2), 0);
    }
    else {
        croak "invalid vercmp operation";
    }
}

=head2 recurse()

Solve dependencies rescursively with a callback function (C<$callback>), for a
matching series of dependency types (C<$types>). An example is <callback_query>
from C<Query.pm> combined with <parse_json_aur> from C<Json.pm>.

Dependencies are tallied and only queried when newly encountered.

Verifying if any versioned dependencies can be fulfilled can be done
subsequently with the C<graph> function.

Parameters:

=over

=item C<$targets>

The pkgnames for which to compute the dependency tree(s) of.

=item C<$types>

=item C<$callback>

=back

=cut

sub recurse {
    my ($targets, $types, $callback) = @_;
    my (%results, %tally);  # indexed by pkgname

    # Main loop
    my $a;
    my @depends = @{$targets};

    for ($a = 1; $a < $aur_callback_max; $a++) {
        if (defined $ENV{'AUR_DEBUG'}) {
            say STDERR join(" ", "callback: [$a]", @depends);
        }
        # Use callback to retrieve new hash of results
        my @level = $callback->(\@depends);

        if (not scalar(@level) and $a == 1) {
            last;  # no results
        }
        # Retrieve next level of dependencies from results
        @depends = ();

        for my $node (@level) {
            my $name = $node->{'Name'};
            $results{$name} = $node;

            # Filter out dependency types early (#882)
            $tally{$name} = $a;

            for my $deptype (@{$types}) {
                if (not defined($node->{$deptype})) {
                    next;  # no dependency of this type
                }
                for my $spec (@{$node->{$deptype}}) {
                     # Valid operators (important: <= before <)
                    my ($dep, $op, $ver) = split(/(<=|>=|<|=|>)/, $spec);

                    # Avoid querying duplicate packages (#4)
                    if (defined $tally{$dep}) {
                        next;
                    }
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
        exit(1);
    }
    # Check if request limits have been exceeded
    if ($a == $aur_callback_max) {
        say STDERR __PACKAGE__ . ": total requests: $a (out of range)";
        exit(34);
    }
    return \%results, $a
}

=head2 graph()

For a set of results (C<$results>), verify if all dependencies and their
versions can be fulfilled by the available set of packages. Version relations
are checked with C<vercmp>.

Two hashes are kept: one for packages in the set (C<$dag>), and
another for packages outside it (C<$dag_foreign>). Only relations in
the former are checked.

Parameters:

=over

=item C<$results>

=item C<$types>

=item C<$verify>

=item C<$provides>

=back

=cut

sub graph {
    my ($results, $types, $verify, $provides) = @_;
    my (%dag, %dag_foreign, %pkgdeps, %pkgmap);

    my $dag_valid = 1;
    $verify //= 1;  # run vercmp by default

    # Iterate over packages, retrieve provides
    for my $name (keys %{$results}) {
        my $node = $results->{$name};

        # Iterate over explicit provides
        for my $spec (@{$node->{'Provides'} // []}) {
            my ($prov, $prov_version) = split(/=/, $spec);

            # XXX: the first provider takes precedence
            #      keep multiple providers and warn on ambiguity instead
            if (not defined $pkgmap{$prov} and $prov ne $name) {
                $pkgmap{$prov} = [$name, $prov_version];
            }
        }
        for my $deptype (@{$types}) {
            if (not defined($node->{$deptype})) {
                next;  # no dependency of this type
            }
            for my $spec (@{$node->{$deptype}}) {
                # Push versioned dependency to depends map
                push(@{$pkgdeps{$name}}, [$spec, $deptype]);
            }
        }
    }
    # Iterate over depends
    for my $name (keys %pkgdeps)
    {
        for my $dep (@{$pkgdeps{$name}}) {
            # Retrieve dependency requirements
            my ($dep_spec, $dep_type) = @{$dep};  # ['foo>=1.0', 'Depends']
            my ($dep_name, $dep_op, $dep_req) = split(/(<=|>=|<|=|>)/, $dep_spec);

            if (defined $results->{$dep_name}) {
                # Split results version to pkgver and pkgrel
                my @dep_ver = split("-", $results->{$dep_name}->{'Version'}, 2);

                # Provides precede regular packages, unless $provides is false.
                my ($prov_name, $prov_ver) = ($dep_name, $dep_ver[0]);

                if ($provides and defined $pkgmap{$dep_name}) {
                    ($prov_name, $prov_ver) = @{$pkgmap{$dep_name}};
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
        exit(1);
    }
    return \%dag, \%dag_foreign, \%pkgmap;
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
            delete $dag->{$dep};  # remove targets that are no longer required
            push(@removals, $dep);
        }
        my $found = first { $dep eq $_ } @{$installed};

        if (defined $found) {
            delete $dag->{$dep};  # remove targets that are installed
            push(@removals, $dep);
        }
    }
    # Remove non-unique elements
    @removals = keys %{{ map { $_ => 1 } @removals }};
    # XXX: return complement dict instead of array
    return \@removals;
}

=head2 solve()

High-level function which combines C<recurse>, C<prune> and C<graph>.

Parameters:

=over

=item C<$targets>

=item C<$types>

=item C<$callback>

=item C<$opt_verify>

=item C<$opt_provides>

=item C<$opt_installed>

=back

=cut

sub solve {
    my ($targets, $types, $callback, $opt_verify, $opt_provides, $opt_installed) = @_;
    
    # Retrieve AUR results (JSON -> dict -> extract depends -> repeat until none)
    my ($results, undef) = recurse($targets, $types, $callback);

    # Verify dependency requirements
    my ($dag, $dag_foreign, $pkgmap) = graph($results, $types, $opt_verify, $opt_provides);
    my $removals = [];

    # Add a loop to command-line targets (#402, #1065, #1136)
    for my $name (@{$targets}) {
        $dag->{$name}{$name} = 'Self';
    }
    # Remove virtual dependencies from dependency graph (#1063)
    # XXX: handle this logic in graph()
    if ($opt_provides) {
        my @virtual = keys %{$pkgmap};

        # XXX: assumes <pkgmap> only contains keys with provides != pkgname
        $removals = prune($dag, \@virtual);
    }
    # Remove transitive dependencies for installed targets (#592)
    # XXX: prune from $dag_foreign as well?
    if (scalar @{$opt_installed}) {
        $removals = prune($dag, $opt_installed);
    }
    # Remove packages no longer in graph from results
    if (scalar @{$removals}) {
        map { delete $results->{$_} } @{$removals};
    }
    # Return $dag for subsequent application of C<prune>
    return $results, $dag, $dag_foreign;
}

# vim: set et sw=4 sts=4 ft=perl:
