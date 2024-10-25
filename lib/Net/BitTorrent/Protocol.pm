package Net::BitTorrent::Protocol v2.0.0 {
    use v5.38;
    use lib '../../../lib';
    use Net::BitTorrent::Protocol::BEP03          qw[:all];
    use Net::BitTorrent::Protocol::BEP03::Bencode qw[:all];
    use Net::BitTorrent::Protocol::BEP05          qw[:all];
    use Net::BitTorrent::Protocol::BEP06          qw[:all];
    use Net::BitTorrent::Protocol::BEP07          qw[:all];
    use Net::BitTorrent::Protocol::BEP09          qw[:all];
    use Net::BitTorrent::Protocol::BEP10          qw[:all];
    use Net::BitTorrent::Protocol::BEP23          qw[:all];
    use Net::BitTorrent::Protocol::BEP52          qw[:all];

    #use Net::BitTorrent::Protocol::BEP44 qw[:all];
    use Carp qw[carp croak];
    use parent 'Exporter';
    our %EXPORT_TAGS = (
        build => [
            @{ $Net::BitTorrent::Protocol::BEP03::EXPORT_TAGS{build} }, @{ $Net::BitTorrent::Protocol::BEP05::EXPORT_TAGS{build} },
            @{ $Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{build} }, @{ $Net::BitTorrent::Protocol::BEP09::EXPORT_TAGS{build} },
            @{ $Net::BitTorrent::Protocol::BEP10::EXPORT_TAGS{build} },

            #@{$Net::BitTorrent::Protocol::BEP44::EXPORT_TAGS{build}},
            @{ $Net::BitTorrent::Protocol::BEP52::EXPORT_TAGS{build} },
        ],
        bencode => [ @{ $Net::BitTorrent::Protocol::BEP03::Bencode::EXPORT_TAGS{all} }, ],
        compact => [ @{ $Net::BitTorrent::Protocol::BEP07::EXPORT_TAGS{all} }, @{ $Net::BitTorrent::Protocol::BEP23::EXPORT_TAGS{all} } ],
        dht     => [
            @{ $Net::BitTorrent::Protocol::BEP05::EXPORT_TAGS{all} },

            #@{$Net::BitTorrent::Protocol::BEP44::EXPORT_TAGS{build}}
        ],
        parse => [
            @{ $Net::BitTorrent::Protocol::BEP03::EXPORT_TAGS{parse} },
            @{ $Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{parse} },
            @{ $Net::BitTorrent::Protocol::BEP10::EXPORT_TAGS{parse} },
            @{ $Net::BitTorrent::Protocol::BEP52::EXPORT_TAGS{parse} },
            qw[parse_packet register_packet register_packets]
        ],
        types => [
            @{ $Net::BitTorrent::Protocol::BEP03::EXPORT_TAGS{types} },
            @{ $Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{types} },
            @{ $Net::BitTorrent::Protocol::BEP10::EXPORT_TAGS{types} },
            @{ $Net::BitTorrent::Protocol::BEP52::EXPORT_TAGS{types} }
        ],
        utils => [ @{ $Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{utils} } ]
    );
    $EXPORT_TAGS{'all'} = [ our @EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS ];
    #
    use Carp qw[carp];
    #
    my %registry;
    #
    sub register_packet( $type, $cb ) { $registry{$type} = $cb; }
    sub register_packets(%kv)         { register_packet( $_, $kv{$_} ) for keys %kv; }

    sub parse_packet($data) {
        return !carp 'Scalar reference expected' unless ref $data eq 'SCALAR';
        return                                   unless length $$data >= 4;

        #~ my $type = unpack 'c', $$data;
        my $type;
        my $length;
        if ( unpack( 'c', $$data ) == 19 && unpack( 'c/a', $$data ) eq 'BitTorrent protocol' ) {
            $type   = -1;    # handshake
            $length = 64;
        }
        else {
            $length = unpack 'N', substr $$data, 0, 4;
            if ( $length == 0 ) {
                $type = -2;    # keepalive
            }
            else {
                return if $length == 0;
                return unless $length <= length($$data) - 4;
                $type = unpack 'C', substr $$data, 4, 1;
            }
        }

        #~ warn sprintf 'type: %d, real: %d, expected: %d', $type, length($$data), $length + 4;
        carp 'Not enough data for packet' && return () unless length $$data >= $length + 4;
        if ( defined $registry{$type} ) {
            my ( $type, $payload ) = $registry{$type}->( substr $$data, 0, $length + 4, '' );
            return { type => $type, payload => $payload // undef };
        }
        carp 'Unhandled packet type: ' . $type;
        ();
    }

    # Register parsers with NBP
    Net::BitTorrent::Protocol::register_packets(
        int $HANDSHAKE      => \&Net::BitTorrent::Protocol::BEP03::parse_handshake,
        int $KEEPALIVE      => \&Net::BitTorrent::Protocol::BEP03::parse_keepalive,
        int $CHOKE          => \&Net::BitTorrent::Protocol::BEP03::parse_choke,
        int $UNCHOKE        => \&Net::BitTorrent::Protocol::BEP03::parse_unchoke,
        int $INTERESTED     => \&Net::BitTorrent::Protocol::BEP03::parse_interested,
        int $NOT_INTERESTED => \&Net::BitTorrent::Protocol::BEP03::parse_not_interested,
        int $HAVE           => \&Net::BitTorrent::Protocol::BEP03::parse_have,
        int $BITFIELD       => \&Net::BitTorrent::Protocol::BEP03::parse_bitfield,
        int $REQUEST        => \&Net::BitTorrent::Protocol::BEP03::parse_request,
        int $PIECE          => \&Net::BitTorrent::Protocol::BEP03::parse_piece,
        int $CANCEL         => \&Net::BitTorrent::Protocol::BEP03::parse_cancel,
        #
        int $EXTENDED => \&Net::BitTorrent::Protocol::BEP10::parse_extended,
        #
        int $HASH_REQUEST => \&Net::BitTorrent::Protocol::BEP52::parse_hash_request,
        int $HASHES       => \&Net::BitTorrent::Protocol::BEP52::parse_hashes,
        int $HASH_REJECT  => \&Net::BitTorrent::Protocol::BEP52::parse_hash_reject
    );
}
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol - Basic, Protocol-level BitTorrent Utilities

=head1 Synopsis

    use Net::BitTorrent::Protocol;
    ...

=head1 Functions

In addition to the functions found in L<Net::BitTorrent::Protocol::BEP03>,
L<Net::BitTorrent::Protocol::BEP03::Bencode>, L<Net::BitTorrent::Protocol::BEP06>, L<Net::BitTorrent::Protocol::BEP07>,
L<Net::BitTorrent::Protocol::BEP09>, L<Net::BitTorrent::Protocol::BEP10>, L<Net::BitTorrent::Protocol::BEP23>,
L<Net::BitTorrent::Protocol::BEP44>, L<Net::BitTorrent::Protocol::BEP52>, TODO..., a function which wraps all the
packet parsing functions is provided:

=over

=item C<parse_packet( \$data )>

Attempts to parse any known packet from the data (a scalar ref) passed to it. On success, the payload and type are
returned and the packet is removed from the incoming data reference. C<undef> is returned on failure and the data in
the reference is unchanged.

=back

=head1 Importing from Net::BitTorrent::Protocol

You may import from this module manually...

    use Net::BitTorrent::Protocol 'build_handshake';

...or by using one or more of the provided tags:

    use Net::BitTorrent::Protocol ':all';

Supported tags include...

=over

=item C<all>

Imports everything.

=item C<build>

Imports all packet building functions from L<BEP03|Net::BitTorrent::Protocol::BEP03>,
L<BEP03|Net::BitTorrent::Protocol::BEP05>, L<BEP06|Net::BitTorrent::Protocol::BEP06>,
L<BEP06|Net::BitTorrent::Protocol::BEP09>, L<BEP10|Net::BitTorrent::Protocol::BEP10>, and
L<BEP52|Net::BitTorrent::Protocol::BEP52>.

=item C<bencode>

Imports the bencode and bdecode functions found in L<BEP03|Net::BitTorrent::Protocol::BEP03>.

=item C<compact>

Imports the compact and inflation functions for IPv4 (L<BEP23|Net::BitTorrent::Protocol::BEP23>) and IPv6
(L<BEP07|Net::BitTorrent::Protocol::BEP07>) peer lists.

=item C<dht>

Imports all functions related to L<BEP05|Net::BitTorrent::Protocol::BEP05> and
L<BEP44|Net::BitTorrent::Protocol::BEP44>.

=item C<parse>

Imports all packet parsing functions from L<BEP03|Net::BitTorrent::Protocol::BEP03>,
L<BEP06|Net::BitTorrent::Protocol::BEP06>, and L<BEP10|Net::BitTorrent::Protocol::BEP10>,
L<BEP52|Net::BitTorrent::Protocol::BEP52> as well as the locally defined L<C<parse_packet( ... )>|/parse_packet( \$data
)> function.

=item C<types>

Imports the packet type values from L<BEP03|Net::BitTorrent::Protocol::BEP03>,
L<BEP06|Net::BitTorrent::Protocol::BEP06>, and L<BEP10|Net::BitTorrent::Protocol::BEP10>,
L<BEP52|Net::BitTorrent::Protocol::BEP52>.

=item C<utils>

Imports the utility functions from L<BEP06|Net::BitTorrent::Protocol::BEP06>.

=back

=head1 See Also

L<AnyEvent::BitTorrent> - Simple client which uses L<Net::BitTorrent::Protocol>

http://bittorrent.org/beps/bep_0003.html - The BitTorrent Protocol Specification

http://bittorrent.org/beps/bep_0006.html - Fast Extension

http://bittorrent.org/beps/bep_0009.html - Extension for Peers to Send Metadata Files

http://bittorrent.org/beps/bep_0010.html - Extension Protocol

http://bittorrent.org/beps/bep_0044.html - Storing arbitrary data in the DHT

http://bittorrent.org/beps/bep_0052.html - The BitTorrent Protocol Specification v2

http://wiki.theory.org/BitTorrentSpecification - An annotated guide to the BitTorrent protocol

L<Net::BitTorrent::PeerPacket|Net::BitTorrent::PeerPacket> - by Joshua McAdams

L<Protocol::BitTorrent|Protocol::BitTorrent> - by Tom Molesworth

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

=for stopwords bencode bdecode

=cut
