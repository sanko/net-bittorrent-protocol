package Net::BitTorrent::Protocol;
use strict;
use warnings;
our $MAJOR = 0; our $MINOR = 9; our $PATCH = 0; our $DEV = 'rc5'; our $VERSION = sprintf('%0d.%0d.%0d' . ($DEV =~ m[\S] ? '-%s' : ''), $MAJOR, $MINOR, $PATCH, $DEV);
use lib '../../../lib';
use Net::BitTorrent::Protocol::BEP03 qw[:all];
use Net::BitTorrent::Protocol::BEP03::Bencode qw[:all];
use Net::BitTorrent::Protocol::BEP05 qw[:all];
use Net::BitTorrent::Protocol::BEP06 qw[:all];
use Net::BitTorrent::Protocol::BEP07 qw[:all];
use Net::BitTorrent::Protocol::BEP10 qw[:all];
use Net::BitTorrent::Protocol::BEP23 qw[:all];
use Carp qw[carp];
use vars qw[@EXPORT_OK %EXPORT_TAGS];
use Exporter qw[];
*import = *import = *Exporter::import;
%EXPORT_TAGS = (
    build => [@{$Net::BitTorrent::Protocol::BEP03::EXPORT_TAGS{build}},
              @{$Net::BitTorrent::Protocol::BEP05::EXPORT_TAGS{build}},
              @{$Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{build}},
              @{$Net::BitTorrent::Protocol::BEP10::EXPORT_TAGS{build}}
    ],
    bencode => [@{  $Net::BitTorrent::Protocol::BEP03::Bencode::EXPORT_TAGS{all}
                    },
    ],
    compact => [@{$Net::BitTorrent::Protocol::BEP07::EXPORT_TAGS{all}},
                @{$Net::BitTorrent::Protocol::BEP23::EXPORT_TAGS{all}}
    ],
    dht   => [@{$Net::BitTorrent::Protocol::BEP05::EXPORT_TAGS{all}}],
    parse => [@{$Net::BitTorrent::Protocol::BEP03::EXPORT_TAGS{parse}},
              @{$Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{parse}},
              @{$Net::BitTorrent::Protocol::BEP10::EXPORT_TAGS{parse}},
              qw[parse_packet]
    ],
    types => [@{$Net::BitTorrent::Protocol::BEP03::EXPORT_TAGS{types}},
              @{$Net::BitTorrent::Protocol::BEP06::EXPORT_TAGS{types}},
              @{$Net::BitTorrent::Protocol::BEP10::EXPORT_TAGS{types}}
    ]
);
@EXPORT_OK = sort map { @$_ = sort @$_; @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;
my $parse_packet_dispatch;

#
sub parse_packet (\$) {
    $parse_packet_dispatch ||= {$KEEPALIVE      => \&parse_keepalive,
                                $CHOKE          => \&parse_choke,
                                $UNCHOKE        => \&parse_unchoke,
                                $INTERESTED     => \&parse_interested,
                                $NOT_INTERESTED => \&parse_not_interested,
                                $HAVE           => \&parse_have,
                                $BITFIELD       => \&parse_bitfield,
                                $REQUEST        => \&parse_request,
                                $PIECE          => \&parse_piece,
                                $CANCEL         => \&parse_cancel,
                                $PORT           => \&parse_port,
                                $SUGGEST        => \&parse_suggest,
                                $HAVE_ALL       => \&parse_have_all,
                                $HAVE_NONE      => \&parse_have_none,
                                $REJECT         => \&parse_reject,
                                $ALLOWED_FAST   => \&parse_allowed_fast,
                                $EXTENDED       => \&parse_extended
    };
    my ($data) = @_;
    if ((!$data) || (ref($data) ne 'SCALAR') || (!$$data)) {
        carp sprintf '%s::parse_packet() needs data to parse', __PACKAGE__;
        return;
    }
    my ($packet);
    if (unpack('c', $$data) == 0x13) {
        my @payload = parse_handshake(substr($$data, 0, 68, ''));
        $packet = {type           => $HANDSHAKE,
                   packet_length  => 68,
                   payload_length => 48,
                   payload        => @payload
            }
            if @payload;
    }
    elsif (    (defined unpack('N', $$data))
           and (unpack('N', $$data) =~ m[\d]))
    {   if ((unpack('N', $$data) <= length($$data))) {
            (my ($packet_data), $$data) = unpack('N/aa*', $$data);
            my $packet_length = 4 + length $packet_data;
            (my ($type), $packet_data) = unpack('ca*', $packet_data);
            if (defined $parse_packet_dispatch->{$type}) {
                my $payload = $parse_packet_dispatch->{$type}($packet_data);
                $packet = {type          => $type,
                           packet_length => $packet_length,
                           (defined $payload ?
                                (payload        => $payload,
                                 payload_length => length $packet_data
                                )
                            : (payload_length => 0)
                           ),
                };
            }
            elsif (eval 'require Data::Dump') {
                carp
                    sprintf
                    <<'END', Data::Dump::pp($type), Data::Dump::pp($packet);
Unhandled/Unknown packet where:
Type   = %s
Packet = %s
END
            }
        }
    }
    return $packet;
}
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol - Basic, Protocol-level BitTorrent Utilities

=head1 Synopsis

    use Net::BitTorrent::Protocol;
    # TODO

=head1 Functions

In addition to the functions found in L<Net::BitTorrent::Protocol::BEP03>,
L<Net::BitTorrent::Protocol::BEP03::Bencode>,
L<Net::BitTorrent::Protocol::BEP06>, L<Net::BitTorrent::Protocol::BEP07>,
L<Net::BitTorrent::Protocol::BEP10>, L<Net::BitTorrent::Protocol::BEP23>,
TODO..., a function which wraps all the packet parsing functions is provided:

=over

=item C<parse_packet( \$data )>

Attempts to parse any known packet from the data (a scalar ref) passed to it.
On success, the payload and type are returned and the packet is removed from
the incoming data reference. C<undef> is returned on failure and the data
in the reference is unchanged.

=back

=head1 Importing from Net::BitTorrent::Protocol

You may import from this module manually...

    use Net::BitTorrent::Protocol 'build_handshake';

...or by using one or more of the provided tags:

    use Net::BitTorrent::Protocol ':all';

Supported tags include...

=over

=item C<all>

Imports everything.

=item C<build>

Imports all packet building functions from
L<BEP03|Net::BitTorrent::Protocol::BEP03>,
L<BEP03|Net::BitTorrent::Protocol::BEP05>,
L<BEP06|Net::BitTorrent::Protocol::BEP06>, and
L<BEP10|Net::BitTorrent::Protocol::BEP10>.

=item C<bencode>

Imports the bencode and bdecode functions found in
L<BEP03|Net::BitTorrent::Protocol::BEP03::Bencode>.

=item C<compact>

Imports the compact and inflation functions for IPv4
(L<BEP23|Net::BitTorrent::Protocol::BEP23>) and IPv6
(L<BEP07|Net::BitTorrent::Protocol::BEP07>) peer lists.

=item C<dht>

Imports all functions related to L<BEP05|Net::BitTorrent::Protocol::BEP05>.

=item C<parse>

Imports all packet parsing functions from
L<BEP03|Net::BitTorrent::Protocol::BEP03>,
L<BEP06|Net::BitTorrent::Protocol::BEP06>, and
L<BEP10|Net::BitTorrent::Protocol::BEP10> as well as the locally defined
L<C<parse_packet( ... )>|/parse_packet( \$data )> function.

=item C<types>

Imports the packet type values from L<BEP03|Net::BitTorrent::Protocol::BEP03>,
L<BEP06|Net::BitTorrent::Protocol::BEP06>, and
L<BEP10|Net::BitTorrent::Protocol::BEP10>.

=back

=head1 See Also

http://bittorrent.org/beps/bep_0003.html - The BitTorrent Protocol
Specification

http://bittorrent.org/beps/bep_0006.html - Fast Extension

http://bittorrent.org/beps/bep_0010.html - Extension Protocol

http://wiki.theory.org/BitTorrentSpecification - An annotated guide to
the BitTorrent protocol

L<Net::BitTorrent::PeerPacket|Net::BitTorrent::PeerPacket> - by Joshua
McAdams

L<Protocol::BitTorrent|Protocol::BitTorrent> - by Tom Molesworth

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2008-2012 by Sanko Robinson <sanko@cpan.org>

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
