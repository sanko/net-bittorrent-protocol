package Net::BitTorrent::Protocol::BEP52 v2.0.0 {
    use v5.38;
    use Scalar::Util qw[dualvar];
    use parent 'Exporter';
    our %EXPORT_TAGS = (
        build => [
            qw[
                build_hash_request
                build_hashes
                build_hash_reject
            ]
        ],
        parse => [
            qw[
                parse_hash_request
                parse_hashes
                parse_hash_reject
            ]
        ],
        types => [
            qw[ $HASH_REQUEST
                $HASHES
                $HASH_REJECT
            ]
        ]
    );
    $EXPORT_TAGS{'all'} = [ our @EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS ];

    # Packet types
    our $HASH_REQUEST = dualvar 21, 'hash request';
    our $HASHES       = dualvar 22, 'hashes';
    our $HASH_REJECT  = dualvar 23, 'hash reject';

    # Wire
    sub build_hash_request( $pieces_root, $base_layer, $index, $length, $proof_layers ) {
        pack 'Nca32NNN', 49, $HASH_REQUEST, $pieces_root, $base_layer, $index, $length, $proof_layers;
    }
    sub build_hashes ()     { }
    sub build_hash_reject() { pack 'Nc', 1, 1 }
    #
    sub parse_hash_request($data) { $HASH_REQUEST, [ unpack 'Nca32NNN*', $data ]; }
    sub parse_hashes      ($data) { $HASHES,      unpack 'x4xN', $data }
    sub parse_hash_reject ($data) { $HASH_REJECT, unpack 'x4xN', $data }
};
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP52 - Packet Utilities for BEP52: The BitTorrent Protocol Specification v2

=head1 Synopsis

    use Net::BitTorrent::Protocol::BEP52 qw[:build];

    # Tell them what we want...
    my $req = build_hash_request(
        pack('H*', 'b462d838e7846495bb64ff944aa44183218f4660ff5580ea39011269db87b218'),
        0, 0, 64, 5
    );

    # And the inverse...
    use Net::BitTorrent::Protocol::BEP52 qw[:parse];
    my ($packet) = parse_hash_request( $res );

=head1 Description

BEP52 describes the BitTorrent v2 protocol. Where v1 of the protocol as set out in BEP03 made use of SHA-1, v2 uses
SHA-256. Where v1 used a pieces field stored in the metadata to validate files, v2 mades use of Merkle trees.

=head1 Importing from Net::BitTorrent::Protocol::BEP52

There are three tags available for import. To get them all in one go, use the C<:all> tag.

=over

=item C<:types>

Packet types

For more on what these packets actually mean, see the BitTorrent Spec. This is a list of the currently supported packet
types:

=over

=item C<$HASH_REQUEST>

=item C<$HASHES>

=item C<$HASH_REJECT>

=back

=item C<:build>

These create packets ready-to-send to remote peers. See L<Building Functions|/"Building Functions">.

=item C<:parse>

These are used to parse unknown data into sensible packets. The same packet types we can build, we can also parse.  See
L<Parsing Functions|/"Parsing Functions">.

=back

=head2 Building Functions

=over

=item C<build_hash_request( ... )>

TODO

=item C<build_hashes( ... )>

TODO

=item C<build_hash_reject( )>

TODO

=back

=head2 Parsing Functions

These are the parsing counterparts for the C<build_> functions.

When the packet is invalid, a fatal error is thrown.

Return values for valid packets are explained below.

=over

=item C<parse_hash_request( $data )>

TODO

=item C<parse_hashes( $data )>

TODO

=item C<parse_hash_reject( $data )>

TODO

=back

=head1 See Also

http://bittorrent.org/beps/bep_0052.html - The BitTorrent Protocol Specification v2

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

=for stopwords bencoded bitfield metainfo

=cut
