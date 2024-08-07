use Test2::V0;
use lib './lib', '../lib';

# Does it return 1?
use Net::BitTorrent::Protocol::BEP06 qw[:all];

# Tests!
is $SUGGEST,      13, '$SUGGEST        == 13';
is $HAVE_ALL,     14, '$HAVE_ALL       == 14';
is $HAVE_NONE,    15, '$HAVE_NONE      == 15';
is $REJECT,       16, '$REJECT         == 16';
is $ALLOWED_FAST, 17, '$ALLOWED_FAST   == 17';
#
is parse_suggest(),   { error => 'Incorrect packet length for SUGGEST' }, 'parse_suggest() is a fatal error';
is parse_suggest(''), { error => 'Incorrect packet length for SUGGEST' }, 'parse_suggest(\'\') is a fatal error';
is parse_suggest("\0\0\0d"),          100,        'parse_suggest("\0\0\0d")  == 100';
is parse_suggest("\0\0\0\0"),         0,          'parse_suggest("\0\0\0\0") == 0';
is parse_suggest("\0\0\4\0"),         1024,       'parse_suggest("\0\0\4\0") == 1024';
is parse_suggest("\f\f\f\f"),         202116108,  'parse_suggest("\f\f\f\f") == 202116108';
is parse_suggest("\x0f\x0f\x0f\x0f"), 252645135,  'parse_suggest("\x0f\x0f\x0f\x0f") == 252645135';
is parse_suggest("\xf0\xf0\xf0\xf0"), 4042322160, 'parse_suggest("\xf0\xf0\xf0\xf0") == 4042322160';
is parse_suggest("\xff\xff\xff\xff"), 4294967295, 'parse_suggest("\xff\xff\xff\xff") == 4294967295';
#
is parse_have_all(), undef, 'parse_have_all() is a fatal error';
#
is parse_have_none(), undef, 'parse_have_none() is a fatal error';
#
is parse_reject(),   { error => 'Incorrect packet length for REJECT (0 requires >=9)' }, 'parse_reject() is a fatal error';
is parse_reject(''), { error => 'Incorrect packet length for REJECT (0 requires >=9)' }, 'parse_reject(\'\') is a fatal error';
is parse_reject("\0\0\0\0\0\0\0\0\0\0\0\0"),  [ 0,   0, 0 ],     'parse_reject("\0\0\0\0\0\0\0\0\0\0\0\0")  == [0, 0, 0]';
is parse_reject("\0\0\0\0\0\0\0\0\0\2\0\0"),  [ 0,   0, 2**17 ], 'parse_reject("\0\0\0\0\0\0\0\0\0\2\0\0")  == [0, 0, 2**17]';
is parse_reject("\0\0\0d\0\0\@\0\0\2\0\0"),   [ 100, 2**14, 2**17 ], 'parse_reject("\0\0\0d\0\0\@\0\0\2\0\0")   == [100, 2**14, 2**17]';
is parse_reject("\0\20\0\0\0\0\@\0\0\2\0\0"), [ 2**20, 2**14, 2**17 ], 'parse_reject("\0\20\0\0\0\0\@\0\0\2\0\0") == [2**20, 2**14, 2**17]';
#
is parse_allowed_fast(),   { error => 'Incorrect packet length for FASTSET' }, 'parse_allowed_fast() is a fatal error';
is parse_allowed_fast(''), { error => 'Incorrect packet length for FASTSET' }, 'parse_allowed_fast(\'\') is a fatal error';
is parse_allowed_fast("\0\0\0d"),          100,        'parse_allowed_fast("\0\0\0d")  == 100';
is parse_allowed_fast("\0\0\0\0"),         0,          'parse_allowed_fast("\0\0\0\0") == 0';
is parse_allowed_fast("\0\0\4\0"),         1024,       'parse_allowed_fast("\0\0\4\0") == 1024';
is parse_allowed_fast("\f\f\f\f"),         202116108,  'parse_allowed_fast("\f\f\f\f") == 202116108';
is parse_allowed_fast("\x0f\x0f\x0f\x0f"), 252645135,  'parse_allowed_fast("\x0f\x0f\x0f\x0f") == 252645135';
is parse_allowed_fast("\xf0\xf0\xf0\xf0"), 4042322160, 'parse_allowed_fast("\xf0\xf0\xf0\xf0") == 4042322160';
is parse_allowed_fast("\xff\xff\xff\xff"), 4294967295, 'parse_allowed_fast("\xff\xff\xff\xff") == 4294967295';
#
is [ generate_fast_set( 7, 1313, "\xAA" x 20, '80.4.4.200' ) ], [ 1059, 431, 808, 1217, 287, 376, 1188 ], 'generate_fast_set( ... ) Spec vector A';
is [ generate_fast_set( 9, 1313, "\xAA" x 20, '80.4.4.200' ) ], [ 1059, 431, 808, 1217, 287, 376, 1188, 353, 508 ],
    'generate_fast_set( ... ) Spec vector B';
#
done_testing;
