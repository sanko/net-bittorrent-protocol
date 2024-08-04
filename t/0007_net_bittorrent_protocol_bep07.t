use Test2::V0;
use lib './lib', '../lib';
$|++;

# Does it return 1?
use Net::BitTorrent::Protocol::BEP07 qw[:all];
TODO: {
    my $todo = todo 'IPv6 is just plain broken';
    #
    is compact_ipv6( [ '2001:0db8:85a3:0000:0000:8a2e:0370:7334', 2223 ] ), pack( 'H*', '20010db885a3000000008a2e03707334000008af' ),
        'compact_ipv6( [...] )';
    is compact_ipv6(
        [ '2001:0db8:85a3:::8a2e:0370:7334',     2223 ],
        [ '3ffe:1900:4545:3:200:f8ff:fe21:67cf', 911 ],
        [ '2001:0db8:85a3:::8a2e:0370:7334',     2223 ]
        ),
        pack( "H*", "20010db885a3000000008a2e03707334000008af3ffe190045453200f8fffe2167cf00000000038f" ), 'compact_ipv6( [...], [...], [...] )';
    #
    is uncompact_ipv6( pack( 'H*', '20010db885a3000000008a2e03707334000008af' ) ), [ '2001:DB8:85A3:0:0:8A2E:370:7334', 2223 ],
        'uncompact_ipv6( ... )';
    is [ uncompact_ipv6( pack( "H*", "20010db885a3000000008a2e03707334000008af3ffe1900454500030200f8fffe2167cf0000038f" ) ) ],
        [ [ '2001:DB8:85A3:0:0:8A2E:370:7334', 2223 ], [ '3FFE:1900:4545:3:200:F8FF:FE21:67CF', 911 ] ], 'uncompact_ipv6( ... )';
}
#
done_testing;
