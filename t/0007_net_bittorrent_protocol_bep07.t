use Test2::V0;
use lib './lib', '../lib';
$|++;

# Does it return 1?
use Net::BitTorrent::Protocol::BEP07 qw[:all];
#
subtest compact => sub {
    is compact_ipv6( [ '2001:0db8:85a3:0000:0000:8a2e:0370:7334', 2223 ] ), pack( 'H*', '20010db885a3000000008a2e0370733408af' ),
        q[[ '2001:0db8:85a3:0000:0000:8a2e:0370:7334', 2223 ]];
    is compact_ipv6('[2001:0db8:85a3:0000:0000:8a2e:0370:7334]2223'), pack( 'H*', '20010db885a3000000008a2e0370733408af' ),
        '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]2223';
    is compact_ipv6(
        [ '2001:0db8:85a3::8a2e:0370:7334', 2223 ], [ '3ffe:1900:4545:3:200:f8ff:fe21:67cf', 911 ],
        [ '2001:0db8:85a3::8a2e:0370:7334', 2223 ]    # Already seen!
        ),
        pack( 'H*', '20010db885a3000000008a2e0370733408af' . '3ffe1900454500030200f8fffe2167cf038f' ), 'repeated address';
};
subtest uncompact => sub {
    is [ uncompact_ipv6( pack( 'H*', '20010db885a3000000008a2e0370733408af' ) ) ], [ [ '2001:db8:85a3::8a2e:370:7334', 2223 ] ], 'one';
    is [ uncompact_ipv6( pack( 'H*', '20010db885a3000000008a2e0370733408af' . '3ffe1900454500030200f8fffe2167cf038f' ) ) ],
        [ [ '2001:db8:85a3::8a2e:370:7334', 2223 ], [ '3ffe:1900:4545:3:200:f8ff:fe21:67cf', 911 ] ], 'two';
};
#
done_testing;
