package Net::BitTorrent::Protocol::BEP03;
our $MAJOR = 0; our $MINOR = 1; our $PATCH = 0; our $DEV = 'rc5'; our $VERSION = sprintf('%0d.%0d.%0d' . ($DEV =~ m[S]? '-%s' : '') , $MAJOR, $MINOR, $PATCH, $DEV);

use Carp qw[carp];
use lib '../../../../lib';
 use vars qw[@EXPORT_OK %EXPORT_TAGS];
use Exporter qw[];
*import = *import = *Exporter::import;
%EXPORT_TAGS = (
    build => [
        qw[ build_handshake build_keepalive build_choke build_unchoke
            build_interested build_not_interested build_have
            build_bitfield build_request build_piece build_cancel
            build_port ]
    ],
    parse => [
        qw[ parse_handshake parse_keepalive
            parse_choke parse_unchoke parse_interested
            parse_not_interested parse_have parse_bitfield
            parse_request parse_piece parse_cancel parse_port ]
    ],
    types => [
        qw[ $HANDSHAKE $KEEPALIVE $CHOKE $UNCHOKE $INTERESTED
            $NOT_INTERESTED $HAVE $BITFIELD $REQUEST $PIECE $CANCEL $PORT ]
    ]
);
@EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;

#
our $HANDSHAKE      = -1;
our $KEEPALIVE      = '';
our $CHOKE          = 0;
our $UNCHOKE        = 1;
our $INTERESTED     = 2;
our $NOT_INTERESTED = 3;
our $HAVE           = 4;
our $BITFIELD       = 5;
our $REQUEST        = 6;
our $PIECE          = 7;
our $CANCEL         = 8;
our $PORT           = 9;

#
my $info_hash_constraint;

sub build_handshake ($$$) {
    my ($reserved, $infohash, $peerid) = @_;
    if ((!defined $reserved) || (length $reserved != 8)) {
        carp sprintf
            '%s::build_handshake() requires 8 bytes of reserved data',
            __PACKAGE__;
        return;
    }
    if ((!defined $infohash) || (length $infohash != 20)) {
        carp sprintf '%s::build_handshake() requires proper infohash',
            __PACKAGE__;
        return;
    }
    if ((!defined $peerid) || (length $peerid != 20)) {
        carp sprintf '%s::build_handshake() requires a well formed peer id',
            __PACKAGE__;
        return;
    }
    return pack 'c/a* a8 a20 a20', 'BitTorrent protocol',
        $reserved, $infohash,
        $peerid;
}
sub build_keepalive ()      { return pack('N',  0); }
sub build_choke ()          { return pack('Nc', 1, 0); }
sub build_unchoke ()        { return pack('Nc', 1, 1); }
sub build_interested ()     { return pack('Nc', 1, 2); }
sub build_not_interested () { return pack('Nc', 1, 3); }

sub build_have ($) {
    my ($index) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf
            '%s::build_have() requires an integer index parameter',
            __PACKAGE__;
        return;
    }
    return pack('NcN', 5, 4, $index);
}

sub build_bitfield ($) {
    my ($bitfield) = @_;
    if ((!$bitfield) || (unpack('B*', $bitfield) !~ m[^[01]+$])) {
        carp sprintf 'Malformed bitfield passed to %s::build_bitfield()',
            __PACKAGE__;
        return;
    }
    return pack('Nca*', (length($bitfield) + 1), 5, $bitfield);
}

sub build_request ($$$) {
    my ($index, $offset, $length) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf
            '%s::build_request() requires an integer index parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $offset) || ($offset !~ m[^\d+$])) {
        carp sprintf '%s::build_request() requires an offset parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $length) || ($length !~ m[^\d+$])) {
        carp sprintf '%s::build_request() requires an length parameter',
            __PACKAGE__;
        return;
    }
    my $packed = pack('NNN', $index, $offset, $length);
    return pack('Nca*', length($packed) + 1, 6, $packed);
}

sub build_piece ($$$) {
    my ($index, $offset, $data) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf '%s::build_piece() requires an index parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $offset) || ($offset !~ m[^\d+$])) {
        carp sprintf '%s::build_piece() requires an offset parameter',
            __PACKAGE__;
        return;
    }
    if (!$data or !$$data) {
        carp sprintf '%s::build_piece() requires data to work with',
            __PACKAGE__;
        return;
    }
    my $packed = pack('N2a*', $index, $offset, $$data);
    return pack('Nca*', length($packed) + 1, 7, $packed);
}

sub build_cancel ($$$) {
    my ($index, $offset, $length) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf
            '%s::build_cancel() requires an integer index parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $offset) || ($offset !~ m[^\d+$])) {
        carp sprintf '%s::build_cancel() requires an offset parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $length) || ($length !~ m[^\d+$])) {
        carp sprintf '%s::build_cancel() requires an length parameter',
            __PACKAGE__;
        return;
    }
    my $packed = pack('N3', $index, $offset, $length);
    return pack('Nca*', length($packed) + 1, 8, $packed);
}

sub build_port ($) {
    my ($port) = @_;
    if ((!defined $port) || ($port !~ m[^\d+$])) {
        carp sprintf '%s::build_port() requires an index parameter',
            __PACKAGE__;
        return;
    }
    return pack('NcN', length($port) + 1, 9, $port);
}

sub parse_handshake ($) {
    my ($packet) = @_;
    if (!$packet || (length($packet) < 68)) {
        carp 'Not enough data for handshake packet';
        return;
    }
    my ($protocol_name, $reserved, $infohash, $peerid)
        = unpack('c/a a8 a20 a20', $packet);
    if ($protocol_name ne 'BitTorrent protocol') {
        carp sprintf('Improper handshake; Bad protocol name (%s)',
                     $protocol_name);
        return;
    }
    return [$reserved, $infohash, $peerid];
}
sub parse_keepalive ($)      { return; }
sub parse_choke ($)          { return; }
sub parse_unchoke ($)        { return; }
sub parse_interested ($)     { return; }
sub parse_not_interested ($) { return; }

sub  parse_have ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 1)) {
        carp 'Incorrect packet length for HAVE';
        return;
    }
    return unpack('N', $packet);
}

sub  parse_bitfield ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 1)) {
        carp 'Incorrect packet length for BITFIELD';
        return;
    }
    return (pack 'b*', unpack 'B*', $packet);
}

sub  parse_request ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 9)) {
        carp sprintf('Incorrect packet length for REQUEST (%d requires >=9)',
                     length($packet || ''));
        return;
    }
    return ([unpack('N3', $packet)]);
}

sub  parse_piece ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 9)) {
        carp sprintf('Incorrect packet length for PIECE (%d requires >=9)',
                     length($packet || ''));
        return;
    }
    return ([unpack('N2a*', $packet)]);
}

sub  parse_cancel ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 9)) {
        carp sprintf('Incorrect packet length for CANCEL (%d requires >=9)',
                     length($packet || ''));
        return;
    }
    return ([unpack('N3', $packet)]);
}

sub  parse_port ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 1)) {
        carp 'Incorrect packet length for PORT';
        return;
    }
    return (unpack 'N', $packet);
}
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP03 - Packet Utilities for the Basic BitTorrent Wire Protocol

=head1 Synopsis

    use Net::BitTorrent::Protocol::BEP03 qw[:build];

    # Tell them what we want...
    my $handshake = build_handshake(
        pack('C*', split('', '00000000')),
        pack('H*', 'ddaa46b1ddbfd3564fca526d1b68420b6cd54201'),
        'your-peer-id-in-here'
    );

    # And the inverse...
    my ($reserved, $infohash, $peerid) = parse_handshake( $handshake );

=head1 Description

What would BitTorrent be without packets? TCP noise, mostly.

For similar work and the specifications behind these packets, move on down to
the L<See Also|/"See Also"> and
L<Specification|/"BEP03 - The BitTorrent Protocol Specification"> sections.

If you're looking for quick, pure Perl bencode/bdecode functions, you should
give L<Net::BitTorrent::Protocol::BEP03::Bencode> a shot.

=head1 Importing from Net::BitTorrent::Protocol::BEP03

There are three tags available for import. To get them all in one go, use the
C<:all> tag.

=over

=item C<:types>

Packet types

For more on what these packets actually mean, see the BitTorrent Spec. This is
a list of the currently supported packet types:

=over

=item C<$HANDSHAKE>

=item C<$KEEPALIVE>

=item C<$CHOKE>

=item C<$UNCHOKE>

=item C<$INTERESTED>

=item C<$NOT_INTERESTED>

=item C<$HAVE>

=item C<$BITFIELD>

=item C<$REQUEST>

=item C<$PIECE>

=item C<$CANCEL>

=item C<$PORT>

=back

=item C<:build>

These create packets ready-to-send to remote peers. See
L<Building Functions|/"Building Functions">.

=item C<:parse>

These are used to parse unknown data into sensible packets. The same packet
types we can build, we can also parse.  See
L<Parsing Functions|/"Parsing Functions">.

=back

=head2 Building Functions

=over

=item C<build_handshake ( $reserved, $infohash, $peerid )>

Creates an initial handshake packet. All parameters must conform to the
BitTorrent spec:

=over

=item C<$reserved>

...is the 8 byte string used to represent a client's capabilities for
extensions to the protocol.

=item C<$infohash>

...is the 20 byte SHA1 hash of the bencoded info from the metainfo file.

=item C<$peerid>

...is 20 bytes. Be creative.

=back

=item C<build_keepalive ( )>

Creates a keep-alive packet. The keep-alive packet is zero bytes, specified
with the length prefix set to zero. There is no message ID and no payload.
Peers may close a connection if they receive no packets (keep-alive or any
other packet) for a certain period of time, so a keep-alive packet must be
sent to maintain the connection alive if no command have been sent for a given
amount of time. This amount of time is generally two minutes.

=item C<build_choke ( )>

Creates a choke packet. The choke packet is fixed-length and has no payload.

See Also: http://tinyurl.com/NB-docs-choking - Choking and Optimistic
Unchoking

=item C<build_unchoke ( )>

Creates an unchoke packet. The unchoke packet is fixed-length and has no
payload.

See Also: http://tinyurl.com/NB-docs-choking - Choking and Optimistic
Unchoking

=item C<build_interested ( )>

Creates an interested packet. The interested packet is fixed-length and has
no payload.

=item C<build_not_interested ( )>

Creates a not interested packet. The not interested packet is fixed-length
and has no payload.

=item C<build_have ( $inded )>

Creates a have packet. The have packet is fixed length. The payload is the
zero-based INDEX of a piece that has just been successfully downloaded and
verified via the hash.

I<That is the strict definition, in reality some games may be played. In
particular because peers are extremely unlikely to download pieces that they
already have, a peer may choose not to advertise having a piece to a peer that
already has that piece. At a minimum "HAVE suppression" will result in a 50%
reduction in the number of HAVE packets, this translates to around a 25-35%
reduction in protocol overhead. At the same time, it may be worthwhile to send
a HAVE packet to a peer that has that piece already since it will be useful in
determining which piece is rare.>

I<A malicious peer might also choose to advertise having pieces that it knows
the peer will never download. Due to this, attempting to model peers using
this information is a bad idea.>

=item C<build_bitfield ( $bitfield )>

Creates a bitfield packet. The bitfield packet is variable length, where C<X>
is the length of the C<$bitfield>. The payload is a C<$bitfield> representing
the pieces that have been successfully downloaded. The high bit in the first
byte corresponds to piece index 0. Bits that are cleared indicated a missing
piece, and set bits indicate a valid and available piece. Spare bits at the
end are set to zero.

A bitfield packet may only be sent immediately after the
L<handshake|/"build_handshake ( $reserved, $infohash, $peerid )"> sequence is
completed, and before any other packets are sent. It is optional, and need not
be sent if a client has no pieces or uses one of the Fast Extension packets:
L<have all|/"build_have_all ( )"> or L<have none|/"build_have_none ( )">.

=begin :parser

I<A bitfield of the wrong length is considered an error. Clients should drop
the connection if they receive bitfields that are not of the correct size, or
if the bitfield has any of the spare bits set.>

=end :parser

=item C<build_request ( $index, $offset, $length )>

Creates a request packet. The request packet is fixed length, and is used to
request a block. The payload contains the following information:

=over

=item C<$index>

...is an integer specifying the zero-based piece index.

=item C<$offset>

...is an integer specifying the zero-based byte offset within the piece.

=item C<$length>

...is an integer specifying the requested length.

=back

See Also: L<build_cancel|/"build_cancel ( $index, $offset, $length )">

=item C<build_piece ( $index, $offset, $data )>

Creates a piece packet. The piece packet is variable length, where C<X> is
the length of the L<$data>. The payload contains the following information:

=over

=item C<$index>

...is an integer specifying the zero-based piece index.

=item C<$offset>

...is an integer specifying the zero-based byte offset within the piece.

=item C<$data>

...is the block of data, which is a subset of the piece specified by C<$index>.

=back

Before sending pieces to remote peers, the client should verify that the piece
matches the SHA1 hash related to it in the .torrent metainfo.

=item C<build_cancel ( $index, $offset, $length )>

Creates a cancel packet. The cancel packet is fixed length, and is used to
cancel L<block requests|/"build_request ( $index, $offset, $length )">. The
payload is identical to that of the
L<request|/"build_request ( $index, $offset, $length )"> packet. It is
typically used during 'End Game.'

See Also: http://tinyurl.com/NB-docs-EndGame - End Game

=item C<build_port ( PORT )>

Creates a port packet.

Please note that the port packet has been replaced by parts of the
L<extention protocol|Net::BitTorrent::Protocol::BEP10> and is no longer used
by a majority of modern clients. I have provided it here only for legacy
support; it will not be removed from this module unless it is removed from the
official specification.

=back

=head2 Parsing Functions

=over

=item TODO ...they're there I just don't have docs for them yet. :) They're
simply the opposite of the build functions. ...yeah.

=back

=head1 BEP03 - The BitTorrent Protocol Specification

The information in this section is taken from the official BitTorrent Protocol
Specification which has been placed in the public domain.

=head2 Descripton

BitTorrent is a protocol for distributing files. It identifies content by URL
and is designed to integrate seamlessly with the web. Its advantage over plain
HTTP is that when multiple downloads of the same file happen concurrently, the
downloaders upload to each other, making it possible for the file source to
support very large numbers of downloaders with only a modest increase in its
load.

=head2 A BitTorrent file distribution consists of these entities

=over

=item * An ordinary web server

=item * A static 'metainfo' file

=item * A BitTorrent tracker

=item * An 'original' downloader

=item * The end user web browsers

=item * The end user downloaders

=back

There are ideally many end users for a single file.

=head2 To start serving, a host goes through the following steps:

=over

=item 1.

Start running a tracker (or, more likely, have one running already).

=item 2.

Start running an ordinary web server, such as apache, or have one already.

=item 3.

Associate the extension C<.torrent> with mimetype C<application/x-bittorrent>
on their web server (or have done so already).

=item 4.

Generate a metainfo (C<.torrent>) file using the complete file to be served
and the URL of the tracker.

=item 5.

Put the metainfo file on the web server.

=item 6.

Link to the metainfo (C<.torrent>) file from some other web page.

=item 7.

Start a downloader which already has the complete file (the 'origin').

=back

=head2 To start downloading, a user does the following:

=over

=item 1.

Install BitTorrent (or have done so already).

=item 2.

Surf the web.

=item 3.

Click on a link to a C<.torrent> file.

=item 4.

Select where to save the file locally, or select a partial download to resume.

=item 5.

Wait for download to complete.

=item 6.

Tell downloader to exit (it keeps uploading until this happens).

=back

=head2 The connectivity is as follows

=over

=item *

Strings are length-prefixed base ten followed by a colon and the string. For
example C<4:spam> corresponds to C<spam>.

=item *

Integers are represented by an C<i> followed by the number in base 10 followed
by an C<e>. For example C<i3e> corresponds to 3 and C<i-3e> corresponds to
C<-3>. Integers have no size limitation. C<i-0e> is invalid. All encodings
with a leading zero, such as C<i03e>, are invalid, other than C<i0e>, which of
course corresponds to C<0>.

=item *

Lists are encoded as an C<l> followed by their elements (also bencoded)
followed by an C<e>. For example C<l4:spam4:eggse> corresponds to
C<['spam', 'eggs']>.

=item *

Dictionaries are encoded as a C<d> followed by a list of alternating keys and
their corresponding values followed by an C<e>. For example,
C<d3:cow3:moo4:spam4:eggse> corresponds to C<{'cow': 'moo', 'spam': 'eggs'}>
and C<d4:spaml1:a1:bee> corresponds to C<{'spam': ['a', 'b']}>. Keys must be
strings and appear in sorted order (sorted as raw strings, not alphanumerics).

=back

=head2 Metainfo files are bencoded dictionaries with the following keys:

=over

=item announce

The URL of the tracker.

=item info

This maps to a dictionary, with keys described below.

=over

=item

The C<name> key maps to a UTF-8 encoded string which is the suggested name to
save the file (or directory) as. It is purely advisory.

=item

C<piece length> maps to the number of bytes in each piece the file is split
into. For the purposes of transfer, files are split into fixed-size pieces
which are all the same length except for possibly the last one which may be
truncated. C<piece length> is almost always a power of two, most commonly
C<2^18 = 256K> (BitTorrent prior to version C<3.2> uses C<2^20 = 1M> as
default).

=item

C<pieces> maps to a string whose length is a multiple of C<20>. It is to be
subdivided into strings of length C<20>, each of which is the SHA1 hash of the
piece at the corresponding index.

=item

There is also a key C<length> or a key C<files>, but not both or neither. If
C<length> is present then the download represents a single file, otherwise it
represents a set of files which go in a directory structure.

=item

In the single file case, C<length> maps to the length of the file in bytes.

For the purposes of the other keys, the multi-file case is treated as only
having a single file by concatenating the files in the order they appear in
the files list. The files list is the value C<files> maps to, and is a list of
dictionaries containing the following keys:

=over

=item C<length>

The length of the file, in bytes.

=item C<path>

A list of UTF-8 encoded strings corresponding to subdirectory names, the last
of which is the actual file name (a zero length list is an error case).

=back

In the single file case, the name key is the name of a file, in the muliple
file case, it's the name of a directory.

=back

=back

All strings in a .torrent file that contains text must be UTF-8 encoded.

=head2 Tracker GET requests have the following keys:

=over

=item info_hash

The C<20> byte sha1 hash of the bencoded form of the info value from the
metainfo file. Note that this is a substring of the metainfo file. This value
will almost certainly have to be escaped.

=item peer_id

A string of length C<20> which this downloader uses as its id. Each downloader
generates its own id at random at the start of a new download. This value will
also almost certainly have to be escaped.

=item ip

An optional parameter giving the IP (or dns name) which this peer is at.
Generally used for the origin if it's on the same machine as the tracker.

=item port

The port number this peer is listening on. Common behavior is for a downloader
to try to listen on port C<6881> and if that port is taken try C<6882>, then
C<6883>, etc. and give up after C<6889>.

=item uploaded

The total amount uploaded so far, encoded in base ten ascii.

=item downloaded

The total amount downloaded so far, encoded in base ten ascii.

=item left

The number of bytes this peer still has to download, encoded in base ten
ascii. Note that this can't be computed from downloaded and the file length
since it might be a resume, and there's a chance that some of the downloaded
data failed an integrity check and had to be re-downloaded.

=item event

This is an optional key which maps to C<started>, C<completed>, or C<stopped>
(or C<empty>, which is the same as not being present). If not present, this is
one of the announcements done at regular intervals. An announcement using
C<started> is sent when a download first begins, and one using C<completed> is
sent when the download is complete. No C<completed> is sent if the file was
complete when started. Downloaders send an announcement using C<stopped> when
they cease downloading.

=back

Tracker responses are bencoded dictionaries. If a tracker response has a key
C<failure reason>, then that maps to a human readable string which explains
why the query failed, and no other keys are required. Otherwise, it must have
two keys: C<interval>, which maps to the number of seconds the downloader
should wait between regular rerequests, and C<peers>. C<peers> maps to a list
of dictionaries corresponding to C<peers>, each of which contains the keys
C<peer id>, C<ip>, and C<port>, which map to the peer's self-selected ID, IP
address or dns name as a string, and port number, respectively. Note that
downloaders may rerequest on nonscheduled times if an event happens or they
need more peers.

If you want to make any extensions to metainfo files or tracker queries,
please coordinate with Bram Cohen to make sure that all extensions are done
compatibly.

BitTorrent's peer protocol operates over TCP. It performs efficiently without
setting any socket options.

Peer connections are symmetrical. Messages sent in both directions look the
same, and data can flow in either direction.

The peer protocol refers to pieces of the file by index as described in the
metainfo file, starting at zero. When a peer finishes downloading a piece and
checks that the hash matches, it announces that it has that piece to all of
its peers.

Connections contain two bits of state on either end: choked or not, and
interested or not. Choking is a notification that no data will be sent until
unchoking happens. The reasoning and common techniques behind choking are
explained later in this document.

Data transfer takes place whenever one side is interested and the other side
is not choking. Interest state must be kept up to date at all times - whenever
a downloader doesn't have something they currently would ask a peer for in
unchoked, they must express lack of interest, despite being choked.
Implementing this properly is tricky, but makes it possible for downloaders to
know which peers will start downloading immediately if unchoked.

Connections start out choked and not interested.

When data is being transferred, downloaders should keep several piece requests
queued up at once in order to get good TCP performance (this is called
'pipelining'.) On the other side, requests which can't be written out to the
TCP buffer immediately should be queued up in memory rather than kept in an
application-level network buffer, so they can all be thrown out when a choke
happens.

=head2 The Peer Wire Protocol

The peer wire protocol consists of a handshake followed by a never-ending
stream of length-prefixed messages. The handshake starts with character
ninteen (decimal) followed by the string C<BitTorrent protocol>. The leading
character is a length prefix, put there in the hope that other new protocols
may do the same and thus be trivially distinguishable from each other.

All later integers sent in the protocol are encoded as four bytes big-endian.

After the fixed headers come eight reserved bytes, which are all zero in all
current implementations. If you wish to extend the protocol using these bytes,
please coordinate with Bram Cohen to make sure all extensions are done
compatibly.

Next comes the C<20> byte sha1 hash of the bencoded form of the info value
from the metainfo file. (This is the same value which is announced as
C<info_hash> to the tracker, only here it's raw instead of quoted here). If
both sides don't send the same value, they sever the connection. The one
possible exception is if a downloader wants to do multiple downloads over a
single port, they may wait for incoming connections to give a download hash
first, and respond with the same one if it's in their list.

After the download hash comes the 20-byte peer id which is reported in tracker
requests and contained in peer lists in tracker responses. If the receiving
side's peer id doesn't match the one the initiating side expects, it severs
the connection.

That's it for handshaking, next comes an alternating stream of length prefixes
and messages. Messages of length zero are keepalives, and ignored. Keepalives
are generally sent once every two minutes, but note that timeouts can be done
much more quickly when data is expected.

All non-keepalive messages start with a single byte which gives their type.

The possible values are:

=over

=item 0. choke

=item 1. unchoke

=item 2. interested

=item 3. not interested

=item 4. have

=item 5. bitfield

=item 6. request

=item 7. piece

=item 8. cancel

=back


'choke', 'unchoke', 'interested', and 'not interested' have no payload.

'bitfield' is only ever sent as the first message. Its payload is a bitfield
with each index that downloader has sent set to one and the rest set to zero.
Downloaders which don't have anything yet may skip the 'bitfield' message. The
first byte of the bitfield corresponds to indices C<0 - 7> from high bit to
low bit, respectively. The next one C<8 - 15>, etc. Spare bits at the end are
set to zero.

The 'have' message's payload is a single number, the index which that
downloader just completed and checked the hash of.

'request' messages contain an index, begin, and length. The last two are byte
offsets. Length is generally a power of two unless it gets truncated by the
end of the file. All current implementations use C<2^15>, and close
connections which request an amount greater than C<2^17>.

'cancel' messages have the same payload as request messages. They are
generally only sent towards the end of a download, during what's called
'endgame mode'. When a download is almost complete, there's a tendency for the
last few pieces to all be downloaded off a single hosed modem line, taking a
very long time. To make sure the last few pieces come in quickly, once
requests for all pieces a given downloader doesn't have yet are currently
pending, it sends requests for everything to everyone it's downloading from.
To keep this from becoming horribly inefficient, it sends cancels to everyone
else every time a piece arrives.

'piece' messages contain an index, begin, and piece. Note that they are
correlated with request messages implicitly. It's possible for an unexpected
piece to arrive if choke and unchoke messages are sent in quick succession
and/or transfer is going very slowly.

Downloaders generally download pieces in random order, which does a reasonably
good job of keeping them from having a strict subset or superset of the pieces
of any of their peers.

Choking is done for several reasons. TCP congestion control behaves very
poorly when sending over many connections at once. Also, choking lets each
peer use a tit-for-tat-ish algorithm to ensure that they get a consistent
download rate.

The choking algorithm described below is the currently deployed one. It is
very important that all new algorithms work well both in a network consisting
entirely of themselves and in a network consisting mostly of this one.

There are several criteria a good choking algorithm should meet. It should cap
the number of simultaneous uploads for good TCP performance. It should avoid
choking and unchoking quickly, known as 'fibrillation'. It should reciprocate
to peers who let it download. Finally, it should try out unused connections
once in a while to find out if they might be better than the currently used
ones, known as optimistic unchoking.

The currently deployed choking algorithm avoids fibrillation by only changing
who's choked once every ten seconds. It does reciprocation and number of
uploads capping by unchoking the four peers which it has the best download
rates from and are interested. Peers which have a better upload rate but
aren't interested get unchoked and if they become interested the worst
uploader gets choked. If a downloader has a complete file, it uses its upload
rate rather than its download rate to decide who to unchoke.

For optimistic unchoking, at any one time there is a single peer which is
unchoked regardless of it's upload rate (if interested, it counts as one of
the four allowed downloaders.) Which peer is optimistically unchoked rotates
every 30 seconds. To give them a decent chance of getting a complete piece to
upload, new connections are three times as likely to start as the current
optimistic unchoke as anywhere else in the rotation.


=head1 See Also

http://bittorrent.org/beps/bep_0003.html - The BitTorrent Protocol
Specification

http://wiki.theory.org/BitTorrentSpecification - An annotated guide to
the BitTorrent protocol

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2008-2012 by Sanko Robinson <sanko@cpan.org>

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
