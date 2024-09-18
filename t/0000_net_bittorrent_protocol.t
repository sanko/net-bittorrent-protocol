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
    build_port ],

    # BEP03 :parse
    qw[
    parse_handshake parse_keepalive
    parse_choke parse_unchoke parse_interested
    parse_not_interested parse_have parse_bitfield
    parse_request parse_piece parse_cancel parse_port ],

    # BEP03 :types
    qw[
    $HANDSHAKE $KEEPALIVE $CHOKE $UNCHOKE $INTERESTED
    $NOT_INTERESTED $HAVE $BITFIELD $REQUEST $PIECE $CANCEL $PORT ],

    # BEP03::Bencode
    qw[bencode bdecode],

    # BEP06
    qw[build_suggest build_allowed_fast build_reject build_have_all
    build_have_none parse_suggest parse_have_all parse_have_none parse_reject
    parse_allowed_fast generate_fast_set],

    # BEP06 :types
    qw[$SUGGEST
    $HAVE_ALL
    $HAVE_NONE
    $REJECT
    $ALLOWED_FAST
    ],

    # BEP07
    qw[compact_ipv6 uncompact_ipv6],

    # BEP10
    qw[build_extended parse_extended],

    # BEP10 :types
    qw[$EXTENDED],

    # BEP23
    qw[compact_ipv4 uncompact_ipv4];

# Local
subtest 'hand rolled malformed packets' => sub {
    like warning { parse_packet('') },    qr[needs data to parse], q[parse_packet('') == undef];
    like warning { parse_packet( \{} ) }, qr[needs data to parse], 'parse_packet(\\{ }) == undef (requires SCALAR ref)';
    my $packet = 'Testing';
    like dies { parse_packet( \$packet ) }, qr[Not enough data yet! We need 1415934836 bytes but have 7], 'not enough data for packet';
    $packet = "\000\000\000\cE \000\000\000F";
    like warning { parse_packet( \$packet ) }, qr[Unhandled], '$packet == "\000\000\000\cE \000\000\000F"';
    $packet = undef;
    like warning { parse_packet( \$packet ) }, qr[needs data to parse], '$packet == undef';
    $packet = '';
    like warning { parse_packet( \$packet ) }, qr[needs data to parse], '$packet == ""';
    $packet = "\000\000\000\r\cU\000\000\cD\000\000\cD\000\000\000\cA\000\000";
    like warning { parse_packet( \$packet ) }, qr[Unhandled], '$packet == "\000\000\000\r\cU\000\000\cD\000\000\cD\000\000\000\cA\000\000"';
};
subtest simulation => sub {

    # Simulate a 'real' P2P session to check packet parsing across the board
    my (@original_data) = (
        build_handshake( pack( 'C*', split( //, '00000000', 0 ) ), pack( 'H*', '0123456789' x 4 ), 'random peer id here!' ),
        build_bitfield('11100010'),
        build_extended(
            0,
            {   'm',
                { 'ut_pex', 1, "\303\202\302\265T_PEX", 2 },
                ( 'p', 30 ),
                'v',      'Net::BitTorrent r0.30',
                'yourip', pack( 'C4', '127.0.0.1' =~ /(\d+)/g ),
                'reqq',   30
            }
        ),
        build_port(1337),
        build_keepalive(),
        build_keepalive(),
        build_keepalive(),
        build_keepalive(),
        build_keepalive(),
        build_interested(),
        build_keepalive(),
        build_not_interested(),
        build_unchoke(),
        build_choke(),
        build_keepalive(),
        build_interested(),
        build_unchoke(),
        build_keepalive(),
        build_have(75),
        build_have(0),
        build_keepalive(),
        build_port(1024),
        build_request( 0,     0,      32768 ),
        build_request( 99999, 131072, 32768 ),
        build_cancel( 99999, 131072, 32768 ),
        build_piece( 1,     2,  'XXX' ),
        build_piece( 0,     6,  'XXX' ),
        build_piece( 99999, 12, 'XXX' ),
        build_suggest(0),
        build_suggest(16384),
        build_have_all(),
        build_have_none(),
        build_allowed_fast(0),
        build_allowed_fast(1024),
        build_reject( 0,    0,      1024 ),
        build_reject( 1024, 262144, 65536 )
    );

    # Now that it's build, let's get to work
    my $data = join( '', @original_data );
    is(
        parse_packet( \$data ),
        {   packet_length  => 68,
            payload        => [ "\0\0\0\0\0\0\0\0", "\1#Eg\x89\1#Eg\x89\1#Eg\x89\1#Eg\x89", "random peer id here!" ],
            payload_length => 48,
            type           => $HANDSHAKE,
        },
        'Handshake...'
    );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 13, payload => '11100010', payload_length => 8, type => $BITFIELD, }, 'Bitfield...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is(
        parse_packet( \$data ),
        {   packet_length => 96,
            payload       => [
                0,
                { m => { "ut_pex" => 1, "\xC3\x82\xC2\xB5T_PEX" => 2 }, p => 30, reqq => 30, v => "Net::BitTorrent r0.30", yourip => "\x7F\0\0\1", },
            ],
            payload_length => 91,
            type           => $EXTENDED
        },
        'Extended Protocol...'
    );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 9, payload => 1337, payload_length => 4, type => $PORT }, 'Port...' );
    shift @original_data;
    subtest keepalives => sub {
        for ( 1 .. 5 ) {
            is $data, join( '', @original_data ), '   ...was shifted from data.';
            is( parse_packet( \$data ), { packet_length => 4, payload => undef, payload_length => 0, type => $KEEPALIVE }, 'Keepalive...' );
            shift @original_data;
        }
    };
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload => undef, payload_length => 0, type => $INTERESTED }, 'Interested...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 4, payload_length => 0, payload => undef, type => $KEEPALIVE }, 'Keepalive...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload_length => 0, payload => undef, type => $NOT_INTERESTED }, 'Not interested...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload_length => 0, payload => undef, type => $UNCHOKE }, 'Unchoke...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload_length => 0, payload => undef, type => $CHOKE }, 'Choke...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 4, payload_length => 0, payload => undef, type => $KEEPALIVE }, 'Keepalive...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload_length => 0, payload => undef, type => $INTERESTED }, 'Interested...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload_length => 0, payload => undef, type => $UNCHOKE }, 'Unchoke...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 4, payload_length => 0, payload => undef, type => $KEEPALIVE }, 'Keepalive...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 9, payload => 75, payload_length => 4, type => $HAVE }, 'Have...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 9, payload => 0, payload_length => 4, type => $HAVE }, 'Have...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 4, payload_length => 0, payload => undef, type => $KEEPALIVE }, 'Keepalive...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 9, payload => 1024, payload_length => 4, type => $PORT }, 'Port...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 17, payload => [ 0, 0, 32768 ], payload_length => 12, type => $REQUEST }, 'Request...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 17, payload => [ 99999, 131072, 32768 ], payload_length => 12, type => $REQUEST }, 'Request...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 17, payload => [ 99999, 131072, 32768 ], payload_length => 12, type => $CANCEL }, 'Cancel...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 16, payload => [ 1, 2, "XXX" ], payload_length => 11, type => $PIECE }, 'Piece...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 16, payload => [ 0, 6, "XXX" ], payload_length => 11, type => $PIECE }, 'Piece...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 16, payload => [ 99999, 12, 'XXX' ], payload_length => 11, type => $PIECE }, 'Piece...' );

    for my $i ( 0, 16384 ) {
        shift @original_data;
        is $data, join( '', @original_data ), '   ...was shifted from data.';
        is( parse_packet( \$data ), { packet_length => 9, payload => $i, payload_length => 4, type => $SUGGEST }, 'Suggestion...' );
    }
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload => undef, payload_length => 0, type => $HAVE_ALL }, 'Have All...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 5, payload => undef, payload_length => 0, type => $HAVE_NONE }, 'Have None...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';

    for my $i ( 0, 1024 ) {
        is( parse_packet( \$data ), { packet_length => 9, payload => $i, payload_length => 4, type => $ALLOWED_FAST }, 'Allowed Fast...' );
        shift @original_data;
        is $data, join( '', @original_data ), '   ...was shifted from data.';
    }
    is( parse_packet( \$data ), { packet_length => 17, payload => [ 0, 0, 1024 ], payload_length => 12, type => $REJECT }, 'Reject...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( parse_packet( \$data ), { packet_length => 17, payload => [ 1024, 262144, 65536 ], payload_length => 12, type => $REJECT }, 'Reject...' );
    shift @original_data;
    is $data, join( '', @original_data ), '   ...was shifted from data.';
    is( \@original_data, [], q[Looks like we're done.] );
    is $data, '', 'Yep, all finished';
};
#
done_testing;
