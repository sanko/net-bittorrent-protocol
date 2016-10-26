package Net::BitTorrent::Protocol::BEP44;
use strict;
use warnings;
our $VERSION = "1.5.0";
use Net::BitTorrent::Protocol::BEP03::Bencode qw[bencode];
use Net::BitTorrent::Protocol::BEP05;
use vars qw[@EXPORT_OK %EXPORT_TAGS];
use Exporter qw[];
*import = *import = *Exporter::import;
%EXPORT_TAGS = (
    build => [
        qw[build_put_data_query build_put_data_reply
            build_get_data_query build_get_data_reply]
    ],
    parse => [qw[ ]],                                         # XXX - None yet
    query => [qw[build_put_data_query build_get_data_query]],
    reply => [qw[build_put_data_reply build_get_data_reply]]
);
@EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;
#
sub build_put_data_query ($$$$;$$$$$) {
    my ($tid, $nid, $token, $data, $sig, $seq, $k, $salt, $cas) = @_;
    return bencode(
        {t => $tid,
         y => 'q',
         q => 'put',
         a => {

             # Required
             id    => $nid,
             token => $token,
             v     => $data,

             # Mutable
             sig  => $sig,     # signature; 64 bytes
             seq  => $seq,     # seq++
             k    => $k,       # pub key; 32 bytes
             salt => $salt,    # to append to k when hashing
             cas  => $cas      # expected seq-nr (int)
         },
         v => $Net::BitTorrent::Protocol::BEP05::v
        }
    );
}

sub build_put_data_reply ($$) {
    my ($tid, $nid) = @_;
    return
        bencode({t => $tid,
                 y => 'r',
                 r => {id => $nid},
                 v => $Net::BitTorrent::Protocol::BEP05::v
                }
        );
}

sub build_get_data_query ($$$) {
    my ($tid, $nid, $target) = @_;
    return
        bencode({t => $tid,
                 y => 'q',
                 q => 'get',
                 a => {id     => $nid,
                       target => $target
                 },
                 v => $Net::BitTorrent::Protocol::BEP05::v
                }
        );
}

sub build_get_data_reply ($$$$$$;$$$) {
    my ($tid, $nid, $values, $token, $nodes, $nodes6, $k, $seq, $sig) = @_;
    return bencode(
        {t => $tid,
         y => 'r',
         r => {
             id    => $nid,
             token => $token,
             ($values ? (v      => $values) : ()),
             ($nodes  ? (nodes  => $nodes)  : ()),
             ($nodes6 ? (nodes6 => $nodes6) : ()),

             # Mutable
             ($k   ? (k   => $k)   : ()),
             ($seq ? (seq => $seq) : ()),
             ($sig ? (sig => $sig) : ())
         },
         v => $Net::BitTorrent::Protocol::BEP05::v
        }
    );
}
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP44 - Packet Utilities for BEP44: Storing arbitrary data in the DHT

=head1 Description

BitTorrent uses a "distributed sloppy hash table" (DHT) for storing peer
contact information for "trackerless" torrents. In effect, each peer becomes a
tracker. The protocol is based on Kademila and is implemented over UDP. This
module provides packet building functions for this protocol.

This extension enables storing and retrieving of arbitrary data in the
BitTorrent DHT. It supports both storing immutable items, where the key is the
SHA-1 hash of the data itself, and mutable items, where the key is the public
 key of the key pair used to sign the data.

=head1 Importing From Net::BitTorrent::Protocol::BEP44

By default, nothing is exported.

You may import any of the following or use one or more of these tag:

=over

=item C<:all>

Imports everything. If you're importing anything, this is probably what you
want.

=item C<:query>

Imports the functions which generate query messages.

=item C<:reply>

Imports the functions which generate proper responses to query messages.

=back

=head1 Functions

Note that all functions require a transaction ID. Please see the
L<related section|/"Transaction IDs"> below. Queries also require a user
generated L<node ID|/"Node IDs">.

=over

=item C<build_put_data_query(...)>

	my $packet = build_put_data_query($tid, $nid, $token, $data);
	   $packet = build_put_data_query($tid, $nid, $token, $data,
								      $sig, $seq, $k,     $salt,  $cas);

Depending on whether the data is mutable or immutable, this function expects the
following params:

=over

=item C<$tid> - Transaction ID (See BEP05)

=item C<$nid> - Note ID (See BEP05)

=item C<$token> - Write token (See BEP05)

=item C<$data> - Any bencoded data (See BEP05)

Remember that the protocol expects this to be less than or equal to 1000
bytes.

=back

The following alues are optional unless the data being set is mutable:

=over

=item C<$sig> - ed25519 signature; 64-byte string

=item C<$seq> - monotonically increasing sequence number

=item C<$k> - ed25519 public key; 32 bytes string

=item C<$salt> - optional salt to be appended to C<$k> when hashing

=item C<$cas> - optional expected compare-and-swap value

=back

=item C<build_get_data_reply($tid, $nid)>

Builds a proper reply to a request to store mutable or immutable data. This is
nearly the same as the standard reply in BEP05.

=item C<build_get_data_query(...)>

This packet requests the target's data from the remote node.

Both immutable and mutable items require the following:

=over

=item C<$tid> - transaction id

=item C<$nid> - id of the sending node

=item C<$target> - the SHA-1 hash of the item being requested

=back

=item C<build_get_data_reply($$$$$$;$$$)>

Immutable data will return the following values:

=over

=item C<$tid> - transaction id

=item C<$nid> - id of the sending node

=item C<$value> - bencoded data whose SHA-1 hash matches incoming target

=item C<$token> - write token

=item C<$nodes> - compact list of IPv4 nodes near to target

=item C<$nodes6> - compact list of IPv6 nodes near to target

=back

Mutable data also requires the following:

=over

=item C<$k> - ed25519 public key (32 bytes)

=item C<$seq> - monotonically increasing sequence number

=item C<$sig> - ed25519 signature (64 bytes)

=back

=back

=head1 Error Reporting

Please use the C<build_error_reply( $tid, $error )> function of
Net::BitTorrent::Protocol::BEP05.

The following describes the expanded list ofpossible error codes:

    Code    Description
    ----------------------------------------------
    205     Message too big (>1000 bytes)
    206     Invalid signature
    207     Optional salt is too large
    301     CAS (compare and swap) hash mismatch
    302     Sequence number less than current

=head1 See Also

=over

=item Net::BitTorrent::Protocol::BEP05

=item BEP 05: DHT Protocol

http://bittorrent.org/beps/bep_0005.html

=back

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2010-2016 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under
the terms of
L<The Artistic License 2.0|http://www.perlfoundation.org/artistic_license_2_0>.
See the F<LICENSE> file included with this distribution or
L<notes on the Artistic License 2.0|http://www.perlfoundation.org/artistic_2_0_notes>
for clarification.

When separated from the distribution, all original POD documentation is
covered by the
L<Creative Commons Attribution-Share Alike 3.0 License|http://creativecommons.org/licenses/by-sa/3.0/us/legalcode>.
See the
L<clarification of the CCA-SA3.0|http://creativecommons.org/licenses/by-sa/3.0/us/>.

Neither this module nor the L<Author|/Author> is affiliated with BitTorrent,
Inc.

=cut
