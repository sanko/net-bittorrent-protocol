use Test2::V0;
use lib './lib', '../lib';
$|++;
#
use Net::BitTorrent::Protocol::BEP52 qw[:all];

# Make sure we import everything
imported_ok

    # BEP52 :build
    qw[build_hash_request build_hashes build_hash_reject],

    # BEP52 :parse
    qw[parse_hash_request parse_hashes parse_hash_reject],

    # BEP52 :types
    qw[$HASH_REQUEST $HASHES $HASH_REJECT];
#
done_testing;
