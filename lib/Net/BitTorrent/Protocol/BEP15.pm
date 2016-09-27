package Net::BitTorrent::Protocol::BEP15;
our $VERSION = "1.5.0";
use Carp qw[carp];
use vars qw[@EXPORT_OK %EXPORT_TAGS];
use Exporter qw[];
*import = *import = *Exporter::import;
%EXPORT_TAGS = (
    build => [
        qw[ build_connect_request ]
    ],
    parse => [
        qw[ parse_connect_request ]
    ],
    types => [
        qw[ ]
    ]
);
@EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;
#

our $CONNECTION_ID = 4497486125440; # 0x41727101980

sub build_connect_request {
    my ($transaction_id) = @_;
        if ((!defined $transaction_id) || ($transaction_id !~ m[^\d+$])) {
        carp sprintf
            '%s::build_connect_request requires a random transaction_id',
            __PACKAGE__;
        return;
    }
    return pack 'Q>NN', $CONNECTION_ID, 0, $transaction_id;
}

sub parse_connect_request {
    my ($data) = @_;
    if (length $data < 16) {
        return {fatal => 0, error => 'Not enough data'};
    }
    my ($cid, $action, $tid) = unpack 'Q>NN', $data;

    if ($cid != $CONNECTION_ID) {
        return {fatal => 1, error => 'Incorrect connection id'};
    }
    if ($action != 0) {
        return {fatal => 1,
                error => 'Incorrect action for connect request'
        };
    }
    return $tid;
}
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP15 - Packet Utilities for BEP15, the UDP Tracker Protocol

=head1 Synopsis

    use Net::BitTorrent::Protocol::BEP15 qw[:build];

    # Tell them we want to connect...
    my $handshake = build_connect_request(255);

    # And the inverse...
    use Net::BitTorrent::Protocol::BEP15 qw[:parse];
    my ($transaction_id) = parse_connect_request( $handshake );

=head1 Description

What would BitTorrent be without packets? TCP noise, mostly.

For similar work and the specifications behind these packets, move on down to
the L<See Also|/"See Also"> section.

=head1 Importing from Net::BitTorrent::Protocol::BEP15

There are two tags available for import. To get them both in one go, use the
C<:all> tag.

=over

=item C<:build>

These create packets ready-to-send to trackers. See
L<Building Functions|/"Building Functions">.

=item C<:parse>

These are used to parse unknown data into sensible packets. The same packet
types we can build, we can also parse. You may want to use this to write your
own UDP tracker. See L<Parsing Functions|/"Parsing Functions">.

=back

=head2 Building Functions

=over

=item C<build_connect_request ( $transaction_id )>

Creates a request for a connection id. The provided transaction should be a
32-bit integer.

=back

=head2 Parsing Functions

These are the parsing counterparts for the C<build_> functions.

When the packet is invalid, a hash reference is returned with C<error> and
C<fatal> keys. The value in C<error> is a string describing what went wrong.

Return values for valid packets are explained below.

=over

=item C<parse_connect_request( $data )>

Returns the parsed transaction id.

=back

=head1 See Also

http://bittorrent.org/beps/bep_0015.html - UDP Tracker Protocol for BitTorrent

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2016 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under
the terms of
L<The Artistic License 2.0|http://www.perlfoundation.org/artistic_license_2_0>.
See the F<LICENSE> file included with this distribution or
L<notes on the Artistic License 2.0|http://www.perlfoundation.org/artistic_2_0_notes>
for clarification.

When separated from the distribution, all original POD documentation is
covered by the
L<Creative Commons Attribution-Share Alike 3.0 License|http://creativecommons.org/licenses/by-sa/3.0/us/legalcode>.
See the
L<clarification of the CCA-SA3.0|http://creativecommons.org/licenses/by-sa/3.0/us/>.

Neither this module nor the L<Author|/Author> is affiliated with BitTorrent,
Inc.

=cut
