use Test2::V0;
use lib './lib', '../lib';

# Does it return 1?
use Net::BitTorrent::Protocol::BEP10 qw[:all];

# Tests!
is $EXTENDED, 20, '$EXTENDED        == 20';
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
is(
    parse_extended("\000d1:md6:ut_pexi1e7:\302\265T_PEXi2ee1:pi30e4:reqqi30e1:v21:Net::BitTorrent r0.306:yourip4:\177\000\000\cAe"),
    [ 0, { m => { "ut_pex" => 1, "\xC2\xB5T_PEX" => 2 }, p => 30, reqq => 30, v => "Net::BitTorrent r0.30", yourip => "\x7F\0\0\1", } ],
    'parse_extended([...]) == [0, { ... }] (packet ID and content)'
);
#
done_testing;
