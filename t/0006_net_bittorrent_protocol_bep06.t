use Test2::V0;
use lib './lib', '../lib';

# Does it return 1?
use Net::BitTorrent::Protocol::BEP06 qw[:all];
#
subtest types => sub {
    is int $SUGGEST_PIECE,  13,               '$SUGGEST_PIECE == 13';
    is $SUGGEST_PIECE,      'suggest piece',  '$SUGGEST_PIECE eq "suggest piece"';
    is int $HAVE_ALL,       14,               '$HAVE_ALL == 14';
    is $HAVE_ALL,           'have all',       '$HAVE_ALL == "have all"';
    is int $HAVE_NONE,      15,               '$HAVE_NONE == 15';
    is $HAVE_NONE,          'have none',      '$HAVE_NONE eq "have none"';
    is int $REJECT_REQUEST, 16,               '$REJECT_REQUEST == 16';
    is $REJECT_REQUEST,     'reject request', '$REJECT_REQUEST eq "reject request"';
    is int $ALLOWED_FAST,   17,               '$ALLOWED_FAST == 17';
    is $ALLOWED_FAST,       'allowed fast',   '$ALLOWED_FAST == "allowed fast"';
};
subtest build => sub {
    is build_have_all(),  "\0\0\0\1\16", 'build_have_all()';
    is build_have_none(), "\0\0\0\1\17", 'build_have_none()';
    #
    is build_suggest_piece(100),       "\0\0\0\5\r\0\0\0d",  'build_suggest_piece(100)';
    is build_suggest_piece(202116108), "\0\0\0\5\r\f\f\f\f", 'build_suggest_piece(202116108)';
    #
    is build_reject_request( 0, 0, 2**17 ), "\0\0\0\r\20\0\0\0\0\0\0\0\0\0\2\0\0", 'build_reject_request(0, 0, 2**17)';
    #
    is build_allowed_fast(0),    "\0\0\0\5\21\0\0\0\0", 'build_allowed_fast(0)';
    is build_allowed_fast(1024), "\0\0\0\5\21\0\0\4\0", 'build_allowed_fast(1024)';
};
subtest parse => sub {
    is [ parse_have_all(undef) ],  [$HAVE_ALL],  'parse_have_all()';
    is [ parse_have_none(undef) ], [$HAVE_NONE], 'parse_have_none()';
    #
    is [ parse_suggest_piece("\0\0\0\5\r\0\0\0d") ],          [ $SUGGEST_PIECE, 100 ],        'parse_suggest_piece("\0\0\0\5\r\0\0\0d")';
    is [ parse_suggest_piece("\0\0\0\5\r\0\0\0\0") ],         [ $SUGGEST_PIECE, 0 ],          'parse_suggest_piece("\0\0\0\5\r\0\0\0\0")';
    is [ parse_suggest_piece("\0\0\0\5\r\0\0\4\0") ],         [ $SUGGEST_PIECE, 1024 ],       'parse_suggest_piece("\0\0\0\5\r\0\0\4\0")';
    is [ parse_suggest_piece("\0\0\0\5\r\f\f\f\f") ],         [ $SUGGEST_PIECE, 202116108 ],  'parse_suggest_piece("\0\0\0\5\r\f\f\f\f")';
    is [ parse_suggest_piece("\0\0\0\5\r\x0f\x0f\x0f\x0f") ], [ $SUGGEST_PIECE, 252645135 ],  'parse_suggest_piece("0\0\0\5\r\x0f\x0f\x0f\x0f")';
    is [ parse_suggest_piece("\0\0\0\5\r\xf0\xf0\xf0\xf0") ], [ $SUGGEST_PIECE, 4042322160 ], 'parse_suggest_piece("0\0\0\5\r\xf0\xf0\xf0\xf0")';
    is [ parse_suggest_piece("\0\0\0\5\r\xff\xff\xff\xff") ], [ $SUGGEST_PIECE, 4294967295 ], 'parse_suggest_piece("0\0\0\5\r\xff\xff\xff\xff")';
    #
    is [ parse_reject_request("\0\0\0\r\20\0\0\0\0\0\0\0\0\0\0\0\0") ], [ $REJECT_REQUEST, [ 0, 0, 0 ] ],
        'parse_reject_request("\0\0\0\r\20\0\0\0\0\0\0\0\0\0\0\0\0")';
    is [ parse_reject_request("\0\0\0\r\20\0\0\0\0\0\0\0\0\0\2\0\0") ], [ $REJECT_REQUEST, [ 0, 0, 2**17 ] ],
        'parse_reject_request("\0\0\0\r\20\0\0\0\0\0\0\0\0\0\2\0\0")';
    is [ parse_reject_request("\0\0\0\r\20\0\0\0d\0\0\@\0\0\2\0\0") ], [ $REJECT_REQUEST, [ 100, 2**14, 2**17 ] ],
        'parse_reject_request("\0\0\0\r\20\0\0\0d\0\0\@\0\0\2\0\0")';
    is [ parse_reject_request("\0\0\0\r\20\0\20\0\0\0\0\@\0\0\2\0\0") ], [ $REJECT_REQUEST, [ 2**20, 2**14, 2**17 ] ],
        'parse_reject_request("\0\0\0\r\20\0\20\0\0\0\0\@\0\0\2\0\0")';
    #
    is parse_allowed_fast("\0\0\0\5\21\0\0\0d"),          100,        'parse_allowed_fast("\0\0\0\5\21\0\0\0d")';
    is parse_allowed_fast("\0\0\0\5\21\0\0\0\0"),         0,          'parse_allowed_fast("\0\0\0\5\21\0\0\0\0")';
    is parse_allowed_fast("\0\0\0\5\21\0\0\4\0"),         1024,       'parse_allowed_fast("\0\0\0\5\21\0\0\4\0")';
    is parse_allowed_fast("\0\0\0\5\21\f\f\f\f"),         202116108,  'parse_allowed_fast("\0\0\0\5\21\f\f\f\f")';
    is parse_allowed_fast("\0\0\0\5\21\17\17\17\17"),     252645135,  'parse_allowed_fast("\0\0\0\5\21\17\17\17\17")';
    is parse_allowed_fast("\0\0\0\5\21\xF0\xF0\xF0\xF0"), 4042322160, 'parse_allowed_fast("\0\0\0\5\21\xF0\xF0\xF0\xF0")';
    is parse_allowed_fast("\0\0\0\5\21\xFF\xFF\xFF\xFF"), 4294967295, 'parse_allowed_fast("\0\0\0\5\21\xFF\xFF\xFF\xFF")';
};
subtest 'fast set generation' => sub {
    is [ generate_fast_set( 7, 1313, "\xAA" x 20, '80.4.4.200' ) ], [ 1059, 431, 808, 1217, 287, 376, 1188 ],
        'generate_fast_set( ... ) Spec vector A';
    is [ generate_fast_set( 9, 1313, "\xAA" x 20, '80.4.4.200' ) ], [ 1059, 431, 808, 1217, 287, 376, 1188, 353, 508 ],
        'generate_fast_set( ... ) Spec vector B';
};
#
done_testing;
