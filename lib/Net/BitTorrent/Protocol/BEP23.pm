package Net::BitTorrent::Protocol::BEP23 v1.5.3 {
    use v5.38;
    use Carp   qw[carp];
    use Socket qw[AF_INET inet_pton inet_ntop];
    use parent 'Exporter';
    our @EXPORT_OK   = qw[compact_ipv4 uncompact_ipv4];
    our %EXPORT_TAGS = ( all => [@EXPORT_OK], bencode => [@EXPORT_OK] );
    #
    sub compact_ipv4 (@peers) {
        my $return;
        my %seen;
        for my $peer (@peers) {
            next if not $peer;
            if ( ref $peer ) {
                my ( $ip, $port ) = @$peer;
                next                                                if $seen{ $ip . ':' . $port }++;
                carp 'Port number beyond ephemeral range: ' . $port if $port > 2**16;
                $return .= pack 'a4n', inet_pton( AF_INET, $ip ), int $port;
            }
            else {
                $return .= inet_pton( AF_INET, $peer );
            }
        }
        return $return;
    }

    sub uncompact_ipv4 ($peers) {
        map {
            my ( $ip, $port ) = $_ =~ m[^(....)(..)?$];
            [ inet_ntop( AF_INET, $ip ), unpack 'n', $port ];
        } $peers =~ m[(.{6})]mg;
    }
};
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP23 - Utility functions for BEP23: Tracker Returns Compact Peer Lists

=head1 Importing From Net::BitTorrent::Protocol::BEP23

By default, nothing is exported.

You may import any of the following or use one or more of these tag:

=over

=item C<:all>

Imports the tracker response-related functions L<compact|/"compact_ipv4 ( @list )"> and L<uncompact|/"uncompact_ipv4 (
$string )">.

=back

=head1 Functions

=over

=item C<compact_ipv4 ( @list )>

Compacts a list of IPv4:port strings into a single string.

A compact peer is 6 bytes; the first four bytes are the host (in network byte order), the last two bytes are the port
(again, in network byte order).

=item C<uncompact_ipv4 ( $string )>

Inflates a compacted string of peers and returns a list of IPv4:port strings.

=back

=head1 See Also

=over

=item BEP 23: Tracker Returns Compact Peer Lists

http://bittorrent.org/beps/bep_0023.html

=back

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2008-2024 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under the terms of L<The Artistic License
2.0|http://www.perlfoundation.org/artistic_license_2_0>. See the F<LICENSE> file included with this distribution or
L<notes on the Artistic License 2.0|http://www.perlfoundation.org/artistic_2_0_notes> for clarification.

When separated from the distribution, all original POD documentation is covered by the L<Creative Commons
Attribution-Share Alike 3.0 License|http://creativecommons.org/licenses/by-sa/3.0/us/legalcode>. See the
L<clarification of the CCA-SA3.0|http://creativecommons.org/licenses/by-sa/3.0/us/>.

Neither this module nor the L<Author|/Author> is affiliated with BitTorrent, Inc.

=for stopwords IPv4:port

=cut
