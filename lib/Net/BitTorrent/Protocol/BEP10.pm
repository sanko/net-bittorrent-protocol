package Net::BitTorrent::Protocol::BEP10;
our $MAJOR = 0; our $MINOR = 1; our $PATCH = 0; our $DEV = 'rc5'; our $VERSION = sprintf('%0d.%0d.%0d' . ($DEV =~ m[S]? '-%s' : '') , $MAJOR, $MINOR, $PATCH, $DEV);
use Carp qw[carp];
use lib '../../../../lib';
use Net::BitTorrent::Protocol::BEP03::Bencode qw[:all];
use vars qw[@EXPORT_OK %EXPORT_TAGS];
use Exporter qw[];
*import = *import = *Exporter::import;
%EXPORT_TAGS = (build => [qw[ build_extended ]],
                parse => [qw[ parse_extended ]],
                types => [qw[ $EXTENDED ]]
);
@EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;

# Type
our $EXTENDED = 20;

# Build function
sub build_extended ($$) {
    my ($msgID, $data) = @_;
    if ((!defined $msgID) || ($msgID !~ m[^\d+$])) {
        carp sprintf
            '%s::build_extended() requires a message id parameter',
            __PACKAGE__;
        return;
    }
    if ((!$data) || (ref($data) ne 'HASH')) {
        carp sprintf '%s::build_extended() requires a payload', __PACKAGE__;
        return;
    }
    my $packet = pack('ca*', $msgID, bencode($data));
    return pack('Nca*', length($packet) + 1, 20, $packet);
}

# Parsing function
sub parse_extended ($) {
    my ($packet) = @_;
    if ((!$packet) || (!length($packet))) { return; }
    my ($id, $payload) = unpack('ca*', $packet);
    return ([$id, scalar bdecode($payload)]);
}
1;

=item C<build_extended ( $msgID, $data )>

Creates an extended protocol packet.

=cut
