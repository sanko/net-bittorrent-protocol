use v5.36;
use Test2::V0 '!subtest';
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use lib './lib', '../lib';
#
use Net::BitTorrent::Protocol        qw[parse_packet];
use Net::BitTorrent::Protocol::BEP03 qw[:all];
#
imported_ok

    # :build
    qw[
    build_handshake build_keepalive build_choke build_unchoke
    build_interested build_not_interested build_have
    build_bitfield build_request build_piece build_cancel
    ],

    # :parse
    qw[
    parse_handshake parse_keepalive
    parse_choke parse_unchoke parse_interested
    parse_not_interested parse_have parse_bitfield
    parse_request parse_piece parse_cancel ],

    # :types
    qw[
    $HANDSHAKE $KEEPALIVE $CHOKE $UNCHOKE $INTERESTED
    $NOT_INTERESTED $HAVE $BITFIELD $REQUEST $PIECE $CANCEL];
#
subtest 'packet types' => sub {
    is int $HANDSHAKE,      -1, '$HANDSHAKE (pseudo-type)';
    is int $KEEPALIVE,      -2, '$KEEPALIVE (pseudo-type)';
    is int $CHOKE,           0, '$CHOKE';
    is int $UNCHOKE,         1, '$UNCHOKE';
    is int $INTERESTED,      2, '$INTERESTED';
    is int $NOT_INTERESTED,  3, '$NOT_INTERESTED';
    is int $HAVE,            4, '$HAVE';
    is int $BITFIELD,        5, '$BITFIELD';
    is int $REQUEST,         6, '$REQUEST';
    is int $PIECE,           7, '$PIECE';
    is int $CANCEL,          8, '$CANCEL';
};
subtest packets => sub {
    my $packet = join '', Net::BitTorrent::Protocol::BEP03::build_handshake( 0 x 8, 1 x 20, 2 x 20 ),
        Net::BitTorrent::Protocol::BEP03::build_keepalive(),
        #
        Net::BitTorrent::Protocol::BEP03::build_choke(), Net::BitTorrent::Protocol::BEP03::build_unchoke(),
        #
        Net::BitTorrent::Protocol::BEP03::build_interested(), Net::BitTorrent::Protocol::BEP03::build_not_interested(),
        #
        Net::BitTorrent::Protocol::BEP03::build_have(100),
        #
        Net::BitTorrent::Protocol::BEP03::build_bitfield('test'),
        #
        Net::BitTorrent::Protocol::BEP03::build_request( 300, 0, 25 ),
        #
        Net::BitTorrent::Protocol::BEP03::build_piece( 10, 0, 'abcde' ),
        #
        Net::BitTorrent::Protocol::BEP03::build_cancel( 300, 0, 25 );
    is $packet,
        "\23BitTorrent protocol000000001111111111111111111122222222222222222222\0\0\0\0\0\0\0\1\0\0\0\0\1\1\0\0\0\1\2\0\0\0\1\3\0\0\0\5\4\0\0\0d\0\0\0\5\5test\0\0\0\r\6\0\0\1,\0\0\0\0\0\0\0\31\0\0\0\16\a\0\0\0\n\0\0\0\0abcde\0\0\0\r\b\0\0\1,\0\0\0\0\0\0\0\31",
        'stream';
    subtest 'pop packets from cache' => sub {
        is parse_packet( \$packet ), { type => $HANDSHAKE,      payload => [ '0' x 8, '1' x 20, '2' x 20, 'BitTorrent protocol' ] }, 'handshake';
        is parse_packet( \$packet ), { type => $KEEPALIVE,      payload => undef },                                                  'keepalive';
        is parse_packet( \$packet ), { type => $CHOKE,          payload => undef },                                                  'choke';
        is parse_packet( \$packet ), { type => $UNCHOKE,        payload => undef },                                                  'unchoke';
        is parse_packet( \$packet ), { type => $INTERESTED,     payload => undef },                                                  'interested';
        is parse_packet( \$packet ), { type => $NOT_INTERESTED, payload => undef },                                                  'not_interested';
        is parse_packet( \$packet ), { type => $HAVE,           payload => 100 },                                                    'have(100)';
        is parse_packet( \$packet ), { type => $BITFIELD,       payload => 'test', },                                                'bitfield';
        is parse_packet( \$packet ), { type => $REQUEST,        payload => [ 300, 0, 25 ] },                                         'request';
        is parse_packet( \$packet ), { type => $PIECE,          payload => [ 10, 0, 'abcde' ] },                                     'piece';
        is parse_packet( \$packet ), { type => $CANCEL,         payload => [ 300, 0, 25 ] },                                         'cancel';
    };
    is $packet, '', 'all data has been eaten';
};
#
done_testing;
