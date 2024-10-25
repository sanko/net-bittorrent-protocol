package Net::BitTorrent::Protocol::BEP07 v1.5.3 {
    use v5.38;
    use Carp   qw[carp];
    use Socket qw[AF_INET6 inet_pton inet_ntop];
    use parent 'Exporter';
    our %EXPORT_TAGS = ( all => [ our @EXPORT_OK = qw[compact_ipv6 uncompact_ipv6] ] );
    #
    sub compact_ipv6 (@peers) {
        my $return = '';
        my %seen;
        for my $peer (@peers) {
            next if not $peer;
            if ( ref $peer ) {
                my ( $ip, $port ) = @$peer;
                carp 'Port number beyond ephemeral range: ' . $port if $port > 2**16;
                $peer = inet_pton( AF_INET6, $ip ) . pack 'n', int $port;
            }
            elsif ( $peer =~ m[^\[(.*)\](\d+)$] ) {
                my ( $ip, $port ) = ( $1, $2 );
                carp 'Port number beyond ephemeral range: ' . $port if $port > 2**16;
                $peer = inet_pton( AF_INET6, $ip ) . pack 'n', int $port;
            }
            else {
                $peer = inet_pton( AF_INET6, $peer );
            }
            next if $seen{$peer}++;
            $return .= $peer;
        }
        return $return;
    }

    sub uncompact_ipv6 ($peers) {
        map {
            my ( $ip, $port ) = $_ =~ m[^(.{16})(..)$];
            [ inet_ntop( AF_INET6, $ip ), unpack( 'n', $port ) ];
        } $peers =~ m[(.{18})]g;
    }
};
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP07 - Utility functions for BEP07: IPv6 Tracker Extension

=head1 Importing From Net::BitTorrent::Protocol::BEP07

By default, nothing is exported.

You may import any of the following or use one or more of these tag:

=over

=item C<:all>

Imports the tracker response-related functions L<compact|/"compact_ipv6 ( @list )"> and L<uncompact|/"uncompact_ipv6 (
$string )">.

=back

=head1 Functions

=over

=item C<compact_ipv6 ( @list )>

Compacts a list of [IPv6, port] values into a single string.

A compact peer is 18 bytes; the first 16 bytes are the host and the last two bytes are the port.

=item C<uncompact_ipv6 ( $string )>

Inflates a compacted string of peers and returns a list of [IPv6, port] values.

=back

=head1 See Also

=over

=item BEP 07: IPv6 Tracker Extension - http://bittorrent.org/beps/bep_0007.html

=back

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2010-2012 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under the terms of L<The Artistic License
2.0|http://www.perlfoundation.org/artistic_license_2_0>. See the F<LICENSE> file included with this distribution or
L<notes on the Artistic License 2.0|http://www.perlfoundation.org/artistic_2_0_notes> for clarification.

When separated from the distribution, all original POD documentation is covered by the L<Creative Commons
Attribution-Share Alike 3.0 License|http://creativecommons.org/licenses/by-sa/3.0/us/legalcode>. See the
L<clarification of the CCA-SA3.0|http://creativecommons.org/licenses/by-sa/3.0/us/>.

Neither this module nor the L<Author|/Author> is affiliated with BitTorrent, Inc.

=cut
