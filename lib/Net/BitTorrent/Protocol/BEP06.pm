package Net::BitTorrent::Protocol::BEP06;
our $MAJOR = 0; our $MINOR = 1; our $PATCH = 0; our $DEV = 'rc5'; our $VERSION = sprintf('%0d.%0d.%0d' . ($DEV =~ m[S]? '-%s' : '') , $MAJOR, $MINOR, $PATCH, $DEV);

use Carp qw[carp];
use vars qw[@EXPORT_OK %EXPORT_TAGS];
use Exporter qw[];
*import = *import = *Exporter::import;
%EXPORT_TAGS = (
    build => [
        qw[
            build_suggest build_allowed_fast build_reject
            build_have_all build_have_none ]
    ],
    parse => [
        qw[
            parse_suggest parse_have_all parse_have_none
            parse_reject parse_allowed_fast ]
    ],
    types => [
        qw[
            $SUGGEST $HAVE_ALL $HAVE_NONE $REJECT $ALLOWED_FAST
            ]
    ]
);
@EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;
our $SUGGEST      = 13;
our $HAVE_ALL     = 14;
our $HAVE_NONE    = 15;
our $REJECT       = 16;
our $ALLOWED_FAST = 17;
our $EXTPROTOCOL  = 20;

sub build_suggest ($) {
    my ($index) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf '%s::build_suggest() requires an index parameter',
            __PACKAGE__;
        return;
    }
    return pack('NcN', 5, 13, $index);
}
sub build_have_all ()  { return pack('Nc', 1, 14); }
sub build_have_none () { return pack('Nc', 1, 15); }

sub build_reject ($$$) {
    my ($index, $offset, $length) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf '%s::build_reject() requires an index parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $offset) || ($offset !~ m[^\d+$])) {
        carp sprintf '%s::build_reject() requires an offset parameter',
            __PACKAGE__;
        return;
    }
    if ((!defined $length) || ($length !~ m[^\d+$])) {
        carp sprintf '%s::build_reject() requires an length parameter',
            __PACKAGE__;
        return;
    }
    my $packed = pack('N3', $index, $offset, $length);
    return pack('Nca*', length($packed) + 1, 16, $packed);
}

sub build_allowed_fast ($) {
    my ($index) = @_;
    if ((!defined $index) || ($index !~ m[^\d+$])) {
        carp sprintf
            '%s::build_allowed_fast() requires an index parameter',
            __PACKAGE__;
        return;
    }
    return pack('NcN', 5, 17, $index);
}

# Parsing functions
sub parse_suggest ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 1)) {
        carp 'Incorrect packet length for SUGGEST';
        return;
    }
    return unpack('N', $packet);
}
sub parse_have_all ($)  { return; }
sub parse_have_none ($) { return; }

sub parse_reject ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 9)) {
        carp sprintf('Incorrect packet length for REJECT (%d requires >=9)',
                     length($packet || ''));
        return;
    }
    return ([unpack('N3', $packet)]);
}

sub parse_allowed_fast ($) {
    my ($packet) = @_;
    if ((!$packet) || (length($packet) < 1)) {
        carp 'Incorrect packet length for FASTSET';
        return;
    }
    return unpack('N', $packet);
}
1;

=pod

=item C<build_allowed_fast ( INDEX )>

Creates an Allowed Fast packet.

uTorrent never advertises a fast set... why should we?

See also: http://bittorrent.org/beps/bep_0006.html - Fast Extension

=item C<build_suggest ( INDEX )>

Creates a Suggest Piece packet.

Super seeding is not supported by Net::BitTorrent.  Yet.

See also: http://bittorrent.org/beps/bep_0006.html - Fast Extension

=item C<build_reject ( INDEX, OFFSET, LENGTH )>

Creates a Reject Request packet.

See also: http://bittorrent.org/beps/bep_0006.html - Fast Extension

=item C<build_have_all ( )>

Creates a Have All packet.

See also: http://bittorrent.org/beps/bep_0006.html - Fast Extension

=item C<build_have_none ( )>

Creates a Have None packet.

See also: http://bittorrent.org/beps/bep_0006.html - Fast Extension
