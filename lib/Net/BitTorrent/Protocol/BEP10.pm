package Net::BitTorrent::Protocol::BEP10 v2.0.0 {
    use v5.38;
    use Carp                                      qw[carp];
    use Net::BitTorrent::Protocol::BEP03::Bencode qw[:all];
    use Scalar::Util                              qw[dualvar];
    use parent 'Exporter';
    our %EXPORT_TAGS = ( build => [qw[ build_extended ]], parse => [qw[ parse_extended ]], types => [qw[ $EXTENDED ]] );
    $EXPORT_TAGS{'all'} = [ our @EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS ];

    # Packet types
    our $EXTENDED = dualvar 20, 'extended';

    # Build function
    sub build_extended ( $msgID, $data ) {
        if ( ( !defined $msgID ) || ( $msgID !~ m[^\d+$] ) ) {
            die sprintf '%s::build_extended() requires a message id parameter', __PACKAGE__;
        }
        if ( ( !$data ) || ( ref($data) ne 'HASH' ) ) {
            die sprintf '%s::build_extended() requires a payload', __PACKAGE__;
        }
        my $packet = pack( 'ca*', $msgID, bencode($data) );
        pack 'Nca*', length($packet) + 1, 20, $packet;
    }

    # Parsing function
    sub parse_extended ($packet) {
        if ( ( !$packet ) || ( !length($packet) ) ) { return; }
        my ( $id, $payload ) = unpack( 'x[Nc]ca*', $packet );
        $EXTENDED, [ $id, scalar bdecode($payload) ];
    }
};
1;

=encoding utf8

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP10 - Packet Utilities for BEP10: Extension Protocol

=head1 Synopsis

    use Net::BitTorrent::Protocol::BEP10 qw[all];
    my $packet = build_extended( 0,
        { m      => { 'LT_metadata' => 1, "µT_PEX" => 2 },
          p      => 6969,
          reqq   => 300,
          v      => "Net::BitTorrent r0.30",
          yourip => "\x7F\0\0\1"
        } );
    my ( $type, $packet ) = parse_extended($packet);

=head1 Description

The intention of this protocol is to provide a simple and thin transport for extensions to the BitTorrent protocol.
Supporting this protocol makes it easy to add new extensions without interfering with the standard BitTorrent protocol
or clients that don't support this extension or the one you want to add.

=head1 Importing from Net::BitTorrent::Protocol::BEP10

There are three tags available for import. To get them all in one go, use the C<:all> tag.

=over

=item C<:types>

Packet types

For more on what these packets actually mean, see the Extension Protocol spec. This is a list of the currently
supported packet types.

=over

=item C<$EXTENDED>

=back

=item C<:build>

These create packets ready-to-send to remote peers. See L<Building Functions|/"Building Functions">.

=item C<:parse>

These are used to parse unknown data into sensible packets. The same packet types we can build, we can also parse. See
L<Parsing Functions|/"Parsing Functions">.

=back

=head1 Building Functions

=over

=item C<build_extended( ... )>

Creates an extended protocol packet.

Expected parameters include:

=over

=item C<msgID> - required

Should be C<0> if you are creating a handshake packet, C<< >0 >> if an extended message as specified by the handshake
is being created.

=item C<data> - required

Should be a hashref of appropriate data.

=back

=back

=head1 Parsing Functions

These are the parsing counterparts for the C<build_> functions.

Return values for valid packets are explained below.

=over

=item C<parse_extended( ... )>

Returns the packet's type, and an array containing the packet's ID and payload.

=back

=head1 See Also

http://bittorrent.org/beps/bep_0010.html - Extension Protocol

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

=for stopwords

=cut
