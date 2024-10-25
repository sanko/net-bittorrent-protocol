use Test2::V0;
use lib './lib', '../lib';

# Does it return 1?
use Net::BitTorrent::Protocol::BEP10 qw[:all];

# Tests!
is int $EXTENDED, 20,         '$EXTENDED == 20';
is $EXTENDED,     'extended', '$EXTENDED eq "extended"';
#
like warning { build_extended( undef, {} ) },    qr[message id], 'build_extended(undef, { }) == undef';
like warning { build_extended( -1,    {} ) },    qr[message id], 'build_extended(-1, { })    == undef';
like warning { build_extended( '',    {} ) },    qr[message id], q[build_extended('', { })    == undef];
like warning { build_extended( 0,     undef ) }, qr[payload],    'build_extended(0, undef)   == undef';
like warning { build_extended( 0,      2 ) },    qr[payload],    'build_extended(0, 2)       == undef';
like warning { build_extended( 0,     -2 ) },    qr[payload],    'build_extended(0, -2)      == undef';
like warning { build_extended( 0,     '' ) },    qr[payload],    q[build_extended(0, '')      == undef];
is build_extended( 0, {} ), "\000\000\000\cD\cT\000de", 'build_extended(0, { })     == "\\0\\0\\0\\4\\24\\0de"';
is build_extended( 0, { m => { "ut_pex" => 1, "\xC2\xB5T_PEX" => 2 }, p => 30, reqq => 30, v => "Net::BitTorrent r0.30", yourip => "\x7F\0\0\1", } ),
    "\000\000\000Z\cT\000d1:md6:ut_pexi1e7:\302\265T_PEXi2ee1:pi30e4:reqqi30e1:v21:Net::BitTorrent r0.306:yourip4:\177\000\000\cAe",
    'build_extended(0, { .. }   == "\\0\\0\\0Z\\24\\0d[...]e" (id == 0 | initial ext handshake is bencoded dict)';
is parse_extended(''), undef, q[parse_extended('') == undef];
my $wire
    = "\0\0\0\xD3\24\0d12:complete_agoi-1e1:md11:lt_donthavei7e10:share_modei8e11:upload_onlyi3e12:ut_holepunchi4e11:ut_metadatai2e6:ut_pexi1ee13:metadata_sizei194e4:reqqi2000e11:upload_onlyi1e1:v17:qBittorrent/5.0.06:yourip4:\x7F\0\0\1e";
my $perl = (
    0,
    {   complete_ago  => -1,
        m             => { lt_donthave => 7, share_mode => 8, upload_only => 3, ut_holepunch => 4, ut_metadata => 2, ut_pex => 1, },
        metadata_size => 194,
        reqq          => 2000,
        upload_only   => 1,
        v             => 'qBittorrent/5.0.0',
        yourip        => "\x7F\0\0\1"
    }
);
is build_extended( 0, $perl ), $wire,                           'build typical packet and id';
is [ parse_extended($wire) ],  [ ( $EXTENDED, [ 0, $perl ] ) ], 'parse typical packet and id';
#
done_testing;
