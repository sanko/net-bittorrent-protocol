use Test2::V0;
use lib './lib', '../lib';

# Does it return 1?
use Net::BitTorrent::Protocol::BEP03 qw[:all];

# Packet types
is $HANDSHAKE,      -1, '$HANDSHAKE      == -1 (pseudo-type)';
is $KEEPALIVE,      '', q[$KEEPALIVE      == '' (pseudo-type)];
is $CHOKE,          0,  '$CHOKE          == 0';
is $UNCHOKE,        1,  '$UNCHOKE        == 1';
is $INTERESTED,     2,  '$INTERESTED     == 2';
is $NOT_INTERESTED, 3,  '$NOT_INTERESTED == 3';
is $HAVE,           4,  '$HAVE           == 4';
is $BITFIELD,       5,  '$BITFIELD       == 5';
is $REQUEST,        6,  '$REQUEST        == 6';
is $PIECE,          7,  '$PIECE          == 7';
is $CANCEL,         8,  '$CANCEL         == 8';
is $PORT,           9,  '$PORT           == 9';

# Building functions
like warning {
    build_handshake( undef, undef, undef )
},
    qr[requires 8 bytes of reserved data],
    'build_handshake(undef, undef, undef) == undef';
like warning {
    build_handshake( 'junk', 'junk', 'junk' )
}, qr[requires 8 bytes of reserved data], q[build_handshake('junk',     'junk',     'junk') == undef];
like warning {
    build_handshake( 'junk9565', 'junk', 'junk' )
}, qr[infohash], q[build_handshake('junk9565', 'junk',     'junk') == undef];
like warning { build_handshake( 'junk9565', 'junk' x 5, 'junk' ) }, qr[peer id],  q[build_handshake('junk9565', 'junk' x 5, 'junk') == undef];
like warning { build_handshake( "\000" x 8, 'junk',     'junk' ) }, qr[infohash], q[build_handshake("\\0" x 8,   'junk',     'junk') == undef];
like warning { build_handshake( "\000" x 8, '01234567890123456789', 'junk' ) }, qr[peer id],
    q[build_handshake("\\0" x 8,   '01234567890123456789', 'junk') == undef];
is build_handshake( "\000" x 8, 'A' x 20, 'B' x 20 ),
    "\cSBitTorrent protocol\000\000\000\000\000\000\000\000AAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBB",
    'build_handshake(chr(0) x 8, q[A] x 20, q[B] x 20) == okay';
is build_handshake( pack( 'C*', split( //, '00000000', 0 ) ), pack( 'H*', '0123456789' x 4 ), 'random peer id here!' ),
    "\cSBitTorrent protocol\000\000\000\000\000\000\000\000\cA#Eg\211\cA#Eg\211\cA#Eg\211\cA#Eg\211random peer id here!",
    'build_handshake( [...])                           == okay';
is build_keepalive(),      "\000\000\000\000",    'build_keepalive() == "\\0\\0\\0\\0" (has no payload)';
is build_choke(),          "\000\000\000\cA\000", 'build_choke() == "\\0\\0\\0\\1\\0" (has no payload)';
is build_unchoke(),        "\000\000\000\cA\cA",  'build_unchoke() == "\\0\\0\\0\\1\\1" (has no payload)';
is build_interested(),     "\000\000\000\cA\cB",  'build_interested() == "\\0\\0\\0\\1\\2" (has no payload)';
is build_not_interested(), "\000\000\000\cA\cC",  'build_not_interested() == "\\0\\0\\0\\1\\3" (has no payload)';
like warning { build_have('1desfdds') }, qr[index], q[build_have('1desfdds') == undef];
is build_have(9),          "\000\000\000\cE\cD\000\000\000\t",   'build_have(9)          == "\\0\\0\\0\\5\\4\\0\\0\\0\\t"';
is build_have(0),          "\000\000\000\cE\cD\000\000\000\000", 'build_have(0)          == "\\0\\0\\0\\5\\4\\0\\0\\0\\0"';
is build_have(4294967295), "\000\000\000\cE\cD\377\377\377\377", 'build_have(4294967295) == "\\0\\0\\0\\5\\4\\xFF\\xFF\\xFF\\xFF" (32bit math limit)';
like warning { build_have(-5) },     qr[index],    'build_have(-5)         == undef (negative index == bad index)';
like warning { build_bitfield('') }, qr[bitfield], q[build_bitfield('')         == undef];
like warning { build_request( undef, 2,     3 ) },     qr[index],  'build_request(undef, 2, 3) == undef';
like warning { build_request( 1,     undef, 3 ) },     qr[offset], 'build_request(1, undef, 3) == undef';
like warning { build_request( 1,     2,     undef ) }, qr[length], 'build_request(1, 2, undef) == undef';
like warning { build_request( '',    '',    '' ) },    qr[index],  q[build_request('', '', '')  == undef];
like warning { build_request( -1,    '',    '' ) },    qr[index],  q[build_request(-1, '', '')  == undef];
like warning { build_request( 1,     '',    '' ) },    qr[offset], q[build_request(1, '', '')   == undef];
like warning { build_request( 1,     -2,    '' ) },    qr[offset], q[build_request(1, -2, '')   == undef];
like warning { build_request( 1,      2,    '' ) },    qr[length], q[build_request(1, 2, '')    == undef];
like warning { build_request( 1,      2,    -3 ) },    qr[length], 'build_request(1, 2, -3)    == undef';
is build_request( 1, 2, 3 ), "\000\000\000\r\cF\000\000\000\cA\000\000\000\cB\000\000\000\cC",
    'build_request(1, 2, 3)     == "\\0\\0\\0\\r\\6\\0\\0\\0\\1\\0\\0\\0\\2\\0\\0\\0\\3"';
is build_request( 4294967295, 4294967295, 4294967295 ), pack( 'H*', '0000000d06ffffffffffffffffffffffff' ),
    q[build_request(4294967295, 4294967295, 4294967295) == pack('H*', '0000000d06ffffffffffffffffffffffff')];
like warning { build_piece( undef, 2,     3 ) },      qr[index],  'build_piece(undef, 2, 3)      == undef (requires an index)';
like warning { build_piece( 1,     undef, 'test' ) }, qr[offset], q[build_piece(1, undef, 'test') == undef (requires an offset)];
like warning { build_piece( 1,     2,     undef ) },  qr[data],   'build_piece(1, 2,     undef)  == undef (requires a block of data)';
like warning { build_piece( '',    '',    '' ) },     qr[index],  q[build_piece('', '', '')   == undef];
like warning { build_piece( -1,    '',    '' ) },     qr[index],  q[build_piece(-1, '', '')   == undef];
like warning { build_piece( 1,     '',    '' ) },     qr[offset], q[build_piece( 1, '', '')   == undef];
like warning { build_piece( 1,     -2,    '' ) },     qr[offset], q[build_piece( 1, -2, '')   == undef];
is build_piece( 1, 2, 'XXX' ), "\000\000\000\f\a\000\000\000\cA\000\000\000\cBXXX",
    q[build_piece(1, 2, \\'XXX') == "\\0\\0\\0\\f\\a\\0\\0\\0\\1\\0\\0\\0\\2XXX"];
like warning { build_cancel( undef, 2,     3 ) },     qr[index],  'build_cancel(undef, 2, 3) == undef';
like warning { build_cancel( 1,     undef, 3 ) },     qr[offset], 'build_cancel(1, undef, 3) == undef';
like warning { build_cancel( 1,     2,     undef ) }, qr[length], 'build_cancel(1, 2, undef) == undef';
like warning { build_cancel( '',    '',    '' ) },    qr[index],  q[build_cancel('', '', '')  == undef];
like warning { build_cancel( -1,    '',    '' ) },    qr[index],  q[build_cancel(-1, '', '')  == undef];
like warning { build_cancel( 1,     '',    '' ) },    qr[offset], q[build_cancel(1, '', '')   == undef];
like warning { build_cancel( 1,     -2,    '' ) },    qr[offset], q[build_cancel(1, -2, '')   == undef];
like warning { build_cancel( 1,      2,    '' ) },    qr[length], q[build_cancel(1, 2, '')    == undef];
like warning { build_cancel( 1,      2,    -3 ) },    qr[length], 'build_cancel(1, 2, -3)    == undef';
is build_cancel( 1, 2, 3 ), "\000\000\000\r\cH\000\000\000\cA\000\000\000\cB\000\000\000\cC",
    'build_cancel(1, 2, 3)     == "\\0\\0\\0\\r\\b\\0\\0\\0\\1\\0\\0\\0\\2\\0\\0\\0\\3"';
is build_cancel( 4294967295, 4294967295, 4294967295 ), pack( 'H*', '0000000d08ffffffffffffffffffffffff' ),
    q[build_cancel(4294967295, 4294967295, 4294967295) == pack('H*', '0000000d08ffffffffffffffffffffffff')];
like warning { build_port(-5) },     qr[index], 'build_port(-5)     == undef';
like warning { build_port(3.3) },    qr[index], 'build_port(3.3)    == undef';
like warning { build_port('test') }, qr[index], q[build_port('test') == undef];
is build_port(8555), "\0\0\0\5\t!k\0\0", 'build_port(8555)   == "\\0\\0\\0\\5\\t!k\\0\\0"';

# Parsing functions
is parse_handshake(''),       { error => 'Not enough data for HANDSHAKE', fatal => 1 }, q[parse_handshake('') == undef (no/not enough data)];
is parse_handshake('Hahaha'), { error => 'Not enough data for HANDSHAKE', fatal => 1 }, q[parse_handshake('Hahaha') == undef (Not enough data)];
is parse_handshake("\cSNotTorrent protocol\000\000\000\000\000\000\000\000AAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBB"),
    { error => 'Improper HANDSHAKE; Bad protocol name (NotTorrent protocol)', fatal => 1 },
    'parse_handshake("\\23NotTorrent protocol[...]") == undef (Bad protocol name)';
is(
    parse_handshake("\cSBitTorrent protocol\000\000\000\000\000\000\000\000AAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBB"),
    [ "\000" x 8, 'A' x 20, 'B' x 20 ],
    'parse_handshake([...]) == [packet] (Correct handshake)'
);
is parse_have(''), { error => 'Incorrect packet length for HAVE', fatal => 1 }, q[parse_have('') == undef (no packed index)];
is parse_have("\000\000\000d"),    100,        'parse_have("\\0\\0\\0d") == 100';
is parse_have("\000\000\000\000"), 0,          'parse_have("\\0\\0\\0\\0") == 0';
is parse_have("\000\000\cD\000"),  1024,       'parse_have("\\0\\0\\4\\0") == 1024';
is parse_have("\f\f\f\f"),         202116108,  'parse_have("\\f\\f\\f\\f") == 202116108';
is parse_have("\cO\cO\cO\cO"),     252645135,  'parse_have("\\x0f\\x0f\\x0f\\x0f") == 252645135';
is parse_have("\377\377\377\377"), 4294967295, 'parse_have("\\xff\\xff\\xff\\xff") == 4294967295 (upper limit for 32-bit math)';
is parse_bitfield(''), { error => 'Incorrect packet length for BITFIELD', fatal => 1 }, q[parse_bitfield('') == undef (no data)];
is parse_bitfield( pack( 'B*', '1110010100010' ) ), "\247\cH",  q[parse_bitfield([...], '1110010100010') == "\\xA7\\b"];
is parse_bitfield( pack( 'B*', '00' ) ),            "\000",     q[parse_bitfield([...], '00') == "\\0"];
is parse_bitfield( pack( 'B*', '00001' ) ),         "\cP",      q[parse_bitfield([...], '00001') == "\\20"];
is parse_bitfield( pack( 'B*', '1111111111111' ) ), "\377\037", q[parse_bitfield([...], '1111111111111') == "\\xFF\\37"];
is parse_request(''), { error => 'Incorrect packet length for REQUEST (0 requires >=9)', fatal => 1 }, q[parse_request('') == undef];
is parse_request("\000\000\000\000\000\000\000\000\000\000\000\000"), [ 0, 0, 0 ],
    'parse_request("\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0")  == [0, 0, 0]';
is parse_request("\000\000\000\000\000\000\000\000\000\cB\000\000"), [ 0, 0, 131072 ],
    'parse_request("\\0\\0\\0\\0\\0\\0\\0\\0\\0\\2\\0\\0")  == [0, 0, 2**17]';
is parse_request("\000\000\000d\000\000\@\000\000\cB\000\000"), [ 100, 16384, 131072 ],
    'parse_request("\\0\\0\\0d\\0\\0\\@\\0\\0\\2\\0\\0")   == [100, 2**14, 2**17]';
is parse_request("\000\cP\000\000\000\000\@\000\000\cB\000\000"), [ 1048576, 16384, 131072 ],
    'parse_request("\\0\\20\\0\\0\\0\\0\\@\\0\\0\\2\\0\\0") == [2**20, 2**14, 2**17]';
is parse_piece(''), { error => 'Incorrect packet length for PIECE (0 requires >=9)', fatal => 1 }, q[parse_piece('') == undef];
is parse_piece("\000\000\000\000\000\000\000\000TEST"), [ 0, 0, 'TEST' ],  q[parse_piece("\\0\\0\\0\\0\\0\\0\\0\\0TEST")  == [0, 0, 'TEST']];
is parse_piece("\000\000\000d\000\000\@\000TEST"), [ 100, 16384, 'TEST' ], q[parse_piece("\\0\\0\\0d\\0\\0\\@\\0TEST")   == [100, 2**14, 'TEST']];
is parse_piece("\000\cP\000\000\000\000\@\000TEST"), [ 1048576, 16384, 'TEST' ],
    q[parse_piece("\\0\\20\\0\\0\\0\\0\\@\\0TEST") == [2**20, 2**14, 'TEST']];
is [ parse_piece("\000\cP\000\000\000\000\@\000") ], [ { error => 'Incorrect packet length for PIECE (8 requires >=9)', fatal => 1 } ],
    'parse_piece("\\0\\20\\0\\0\\0\\0\\@\\0")     == [ ] (empty pieces should be considered bad packets)';
is parse_cancel(''), { error => 'Incorrect packet length for CANCEL (0 requires >=9)', fatal => 1 }, q[parse_cancel('') == undef];
is parse_cancel("\000\000\000\000\000\000\000\000\000\000\000\000"), [ 0, 0, 0 ],
    'parse_cancel("\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0")  == [0, 0, 0]';
is parse_cancel("\000\000\000\000\000\000\000\000\000\cB\000\000"), [ 0, 0, 131072 ],
    'parse_cancel("\\0\\0\\0\\0\\0\\0\\0\\0\\0\\2\\0\\0")  == [0, 0, 2**17]';
is parse_cancel("\000\000\000d\000\000\@\000\000\cB\000\000"), [ 100, 16384, 131072 ],
    'parse_cancel("\\0\\0\\0d\\0\\0\\@\\0\\0\\2\\0\\0")   == [100, 2**14, 2**17]';
is parse_cancel("\000\cP\000\000\000\000\@\000\000\cB\000\000"), [ 1048576, 16384, 131072 ],
    'parse_cancel("\\0\\20\\0\\0\\0\\0\\@\\0\\0\\2\\0\\0") == [2**20, 2**14, 2**17]';
#
done_testing;
