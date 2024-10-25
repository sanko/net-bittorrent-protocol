use Test2::V0;
use lib './lib', '../lib';

# Does it return 1?
use Net::BitTorrent::Protocol qw[:all];

# Make sure we import everything
imported_ok

    # local
    qw[parse_packet],

    # BEP03 :build
    qw[
    build_handshake build_keepalive build_choke build_unchoke
    build_interested build_not_interested build_have
    build_bitfield build_request build_piece build_cancel
    ],

    # BEP03 :parse
    qw[
    parse_handshake parse_keepalive
    parse_choke parse_unchoke parse_interested
    parse_not_interested parse_have parse_bitfield
    parse_request parse_piece parse_cancel ],

    # BEP03 :types
    qw[
    $HANDSHAKE $KEEPALIVE $CHOKE $UNCHOKE $INTERESTED
    $NOT_INTERESTED $HAVE $BITFIELD $REQUEST $PIECE $CANCEL],

    # BEP03::Bencode
    qw[bencode bdecode],

    # BEP06
    qw[build_suggest_piece build_allowed_fast build_reject_request build_have_all
    build_have_none parse_suggest_piece parse_have_all parse_have_none parse_reject_request
    parse_allowed_fast generate_fast_set],

    # BEP06 :types
    qw[$SUGGEST_PIECE
    $HAVE_ALL
    $HAVE_NONE
    $REJECT_REQUEST
    $ALLOWED_FAST
    ],

    # BEP07
    qw[compact_ipv6 uncompact_ipv6],

    # BEP10
    qw[build_extended parse_extended],

    # BEP10 :types
    qw[$EXTENDED],

    # BEP23
    qw[compact_ipv4 uncompact_ipv4],

    # BEP52 :build
    qw[build_hash_request build_hashes build_hash_reject],

    # BEP52 :parse
    qw[parse_hash_request parse_hashes parse_hash_reject],

    # BEP52 :types
    qw[$HASH_REQUEST $HASHES $HASH_REJECT];
#
done_testing;
