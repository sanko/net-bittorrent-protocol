use Test2::V0;
use lib './lib', '../lib';
$|++;

# Does it return 1?
use Net::BitTorrent::Protocol::BEP23 qw[:all];
#
subtest compact => sub {
    is compact_ipv4( [ '127.0.0.1', 2223 ] ), "\x7F\0\0\1\b\xAF", q[[ '127.0.0.1', 2223 ]];
    is compact_ipv4('127.0.0.1:2223'),        "\x7F\0\0\1\b\xAF", q['127.0.0.1:2223'];
    is compact_ipv4( [ '127.0.0.1', 2223 ], [ '8.8.8.8', 56 ], [ '127.0.0.1', 2223 ] ), pack( 'H*', '7f00000108af' . '080808080038' ),
        'repeated address';
};
subtest uncompact => sub {
    is( [ uncompact_ipv4("\x7F\0\0\1\b\xAF") ], [ [ '127.0.0.1', 2223 ] ], '\x7F\0\0\1\b\xAF' );
    is [ uncompact_ipv4( pack( 'H*', '7f00000108af080808080038' ) ) ], [ [ '127.0.0.1', 2223 ], [ '8.8.8.8', 56 ] ], '\x7F\0\0\1\b\xAF\b\b\b\b\x008';
};
#
done_testing;
