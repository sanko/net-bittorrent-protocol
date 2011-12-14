#!perl
package AnyEvent::BitTorrent::MultiTracker;
use Mouse::Role;
requires qw[metadata];
sub trackers {...}

package AnyEvent::BitTorrent;
{ $AnyEvent::BitTorrent::VERSION = 'v0.9.0' }
use autodie;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::HTTP;
use Mouse;
use Mouse::Util::TypeConstraints;
use Fcntl qw[SEEK_SET /O_/ :flock];
use Digest::SHA qw[sha1];
use File::Spec;
use File::Path;
use lib '../lib';
use Net::BitTorrent::Protocol qw[:all];

#
# XXX - These should be attributes:
my $block_size = 2**14;

#
has path => (
            is  => 'ro',
            isa => subtype(
                as 'Str' => where { -f $_ } => message { 'Cannot find ' . $_ }
            ),
            required => 1
);
has peerid => (
    is  => 'ro',
    isa => subtype(
        as 'Str' => where { length $_ == 20 } => message {
            'Peer ID must be 20 chars in length';
        }
    ),
    required => 1,
    default  => sub {
        pack(
            'a20',
            (sprintf(
                 'AEB%0d%02d-%8s%-5s',
                 ($AnyEvent::BitTorrent::VERSION =~ m[^v(\d+)\.(\d+)]),
                 (  join '',
                    map {
                        ['A' .. 'Z', 'a' .. 'z', 0 .. 9, qw[- . _ ~]]
                        ->[rand(66)]
                        } 1 .. 8
                 ),
                 [qw[KaiLi April]]->[rand 2]
             )
            )
        );
    }
);
has bitfield => (is       => 'ro',
                 isa      => 'Str',
                 init_arg => undef,
                 builder  => '_build_bitfield'
);
sub _build_bitfield { my $s = shift; pack 'b*', "\0" x $s->piece_count }

sub wanted {
    pack 'b*', ~unpack('b*', shift->bitfield);
}
has infohash => (
    is  => 'ro',
    isa => subtype(
        as 'Str' => where { length $_ == 20 } => message {
            'Infohashes are 20 bytes in length';
        }
    ),
    init_arg => undef,
    lazy     => 1,
    default  => sub { sha1(bencode(shift->metadata->{info})) }
);
has metadata => (is         => 'ro',
                 isa        => 'HashRef',
                 init_arg   => undef,
                 lazy_build => 1
);

sub _build_metadata {
    my $s = shift;
    return if ref $s ne __PACKAGE__;    # Applying roles makes deep rec
    open my $fh, '<', $s->path;
    sysread $fh, my $raw, -s $fh;
    my $metadata = bdecode $raw;

# XXX - Mouse::Util::apply_all_roles($s, 'AnyEvent::BitTorrent::MultiTracker');
    $metadata;
}
sub name         { shift->metadata->{info}{name} }
sub pieces       { shift->metadata->{info}{pieces} }
sub piece_length { shift->metadata->{info}{'piece length'} }

sub piece_count {
    my $s     = shift;
    my $count = $s->size / $s->piece_length;
    int($count) + (($count == int $count) ? 1 : 0);
}
has basedir => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
    trigger    => sub {
        my ($s, $n, $o) = @_;
        $o // return;
        $s->_clear_files;    # So they can be rebuilt with the new basedir
    }
);
sub _build_basedir { File::Spec->rel2abs(File::Spec->curdir) }
has files => (is         => 'ro',
              isa        => 'ArrayRef[HashRef]',
              lazy_build => 1,
              init_arg   => undef,
              clearer    => '_clear_files'
);

sub _build_files {
    my $s = shift;
    defined $s->metadata->{info}{files} ?
        [
        map {
            {
                length   => $_->{length},
                    path => File::Spec->rel2abs(
                              File::Spec->catfile($s->basedir, @{$_->{path}}))
            }
            } @{$s->metadata->{info}{files}}
        ]
        : [{length => $s->metadata->{info}{length}},
           path =>
               File::Spec->rel2abs(File::Spec->catfile($s->basedir, $s->name))
        ];
}

sub size {
    my $s   = shift;
    my $ret = 0;
    $ret += $_->{length} for @{$s->files};
    $ret;
}

sub _read {
    my ($s, $index, $offset, $length) = @_;
    my $data         = '';
    my $file_index   = 0;
    my $total_offset = int(($index * $s->piece_length) + ($offset || 0));
SEARCH:
    while ($total_offset > $s->files->[$file_index]->{length}) {
        $total_offset -= $s->files->[$file_index]->{length};
        $file_index++;
        last SEARCH    # XXX - return?
            if not defined $s->files->[$file_index]->{length};
    }
READ: while ((defined $length) && ($length > 0)) {
        my $this_read
            = (
              ($total_offset + $length) >= $s->files->[$file_index]->{length})
            ?
            ($s->files->[$file_index]->{length} - $total_offset)
            : $length;

        # XXX - Keep file open for a while
        if ((!-f $s->files->[$file_index]->{path})
            || (!sysopen(my ($fh), $s->files->[$file_index]->{path}, O_RDONLY)
            )
            )
        {   $data .= "\0" x $this_read;
        }
        else {
            flock $fh, LOCK_SH;
            sysseek $fh, $total_offset, SEEK_SET;
            sysread $fh, my ($_data), $this_read;
            flock $fh, LOCK_UN;
            close $fh;
            $data .= $_data if $_data;
        }
        $file_index++;
        $length -= $this_read;
        last READ if not defined $s->files->[$file_index];
        $total_offset = 0;
    }
    return $data;
}

sub _write {
    my ($s, $index, $offset, $data) = @_;
    my $file_index = 0;
    my $total_offset = int(($index * $s->piece_length) + ($offset || 0));
SEARCH:
    while ($total_offset > $s->files->[$file_index]->{length}) {
        $total_offset -= $s->files->[$file_index]->{length};
        $file_index++;
        last SEARCH    # XXX - return?
            if not defined $s->files->[$file_index]->{length};
    }
WRITE: while ((defined $data) && (length $data > 0)) {
        my $this_write
            = (($total_offset + length $data)
               >= $s->files->[$file_index]->{length})
            ?
            ($s->files->[$file_index]->{length} - $total_offset)
            : length $data;
        my @split = File::Spec->splitdir($s->files->[$file_index]->{path});
        pop @split;    # File name itself
        my $dir = File::Spec->catdir(@split);
        File::Path::mkpath($dir) if !-d $dir;
        sysopen(my ($fh),
                $s->files->[$file_index]->{path},
                O_WRONLY | O_CREAT)
            or return;
        flock $fh, LOCK_EX;
        truncate $fh, $s->files->[$file_index]->{length}
            if -s $fh != $s->files->[$file_index]
                ->{length};    # XXX - pre-allocate files
        sysseek $fh, $total_offset, SEEK_SET;
        my $w = syswrite $fh, substr $data, 0, $this_write, '';
        flock $fh, LOCK_UN;
        close $fh;
        $file_index++;
        last WRITE if not defined $s->files->[$file_index];
        $total_offset = 0;
    }
    return 1;
}

sub hashcheck {
    my $s = shift;
    for my $i (0 .. $s->piece_count) {
        my $data = $s->_read($i, 0, $s->piece_length);
        vec($s->{bitfield}, $i, 1) = defined($data)
            && (substr($s->pieces, $i * 20, 20) eq sha1($data));
    }
}
has peers => (
    is      => 'ro',
    isa     => 'HashRef[HashRef]',
    default => sub { {} }

# { handle            => AnyEvent::Handle
#   peerid            => 'Str'
#   bitfield          => 'Str'
#   remote_choked     => 1
#   remote_interested => 0
#   remote_requests   => ArrayRef[ArrayRef] # List of [i, o, l, weak(p), d='', timeout]
#   local_choked      => 1
#   local_interested  => 0
#   local_requests    => ArrayRef[ArrayRef] # List of [i, o, l, weak(p), d='', timeout]
#   timeout           => AnyEvent::timer
#   keepalive         => AnyEvent::timer
# }
);

sub _add_peer {
    my ($s, $h) = @_;
    $s->{peers}{+$h} = {
        handle            => $h,
        peerid            => '',
        bitfield          => (pack 'b*', "\0" x $s->piece_count),
        remote_choked     => 1,
        remote_interested => 0,
        remote_requests   => [],
        local_choked      => 1,
        local_interested  => 0,
        local_requests    => [],
        timeout           => AE::timer(20, 0, sub { $s->_del_peer($h) }),
        keepalive         => AE::timer(
            30, 120,
            sub {
                $h->push_write(build_keepalive());
            }
        )
    };
}

sub _del_peer {
    my ($s, $h) = @_;
    $s->peers->{$h} // return;
    delete $s->peers->{$h};
    $h->destroy;
}
has peer_cache => (is      => 'ro',
                   isa     => 'Str',
                   writer  => '_set_peer_cache',
                   default => '',
                   lazy    => 1
);
has trackers => (
    is       => 'ro',
    isa      => 'ArrayRef[ArrayRef[Str]]',
    lazy     => 1,
    required => 1,
    init_arg => undef,
    default  => sub {
        my $s = shift;
        [defined $s->metadata->{announce} ? [$s->metadata->{announce}] : ()];
    }
);

# Timers
has _tracker_timer => (
    is       => 'bare',
    isa      => 'Ref',
    init_arg => undef,
    required => 1,
    default  => sub {
        my $s = shift;
        AE::timer(
            1,
            15 * 60,
            sub {
                http_get $s->trackers->[0][0] . '?info_hash=' . sub {
                    local $_ = shift;
                    s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
                    $_;
                    }
                    ->($s->infohash)
                    . '&peer_id='
                    . $s->peerid
                    . '&uploaded='
                    . 0
                    .                        # XXX - $s->uploaded.
                    '&downloaded=' . 0 .     # XXX - $s->downloaded.
                    '&left=' . $s->size .    # XXX - $s->left.
                    '&port=' . 4567 .        # XXX - $s->port
                    '&compact=1', sub {
                    use Data::Dump;
                    ddx \@_;
                    my ($body, $hdr) = @_;
                    if ($hdr->{Status} =~ /^2/) {
                        my $reply = bdecode($body);
                        $s->_set_peer_cache(
                                      compact_ipv4(
                                          uncompact_ipv4(
                                              $s->peer_cache . $reply->{peers}
                                          )
                                      )
                        );
                    }
                    else {
                        print "error, $hdr->{Status} $hdr->{Reason}\n";
                    }
                    }
            }
        );
    }
);
has _peer_timer => (
    is       => 'bare',
    isa      => 'Ref',
    init_arg => undef,
    required => 1,
    default  => sub {
        my $s = shift;
        AE::timer(
            1, 15,
            sub {
                my @cache = uncompact_ipv4($s->peer_cache);
                return if !@cache;
                for my $i (1 .. @cache) {
                    last if $i == 10;    # XXX - Max half open
                    last if scalar(keys %{$s->peers}) > 100; # XXX - Max peers
                    my $addr = splice @cache, rand $#cache, 1;
                    my $handle;
                    $handle = AnyEvent::Handle->new(
                        connect  => $addr,
                        on_error => sub {
                            my ($hdl, $fatal, $msg) = @_;

                            #AE::log error => "got error $msg\n";
                            $s->_del_peer($hdl);
                        },
                        on_connect_error => sub {
                            my ($hdl, $fatal, $msg) = @_;
                            $s->_del_peer($hdl);

                            #AE::log
                            #    error => sprintf "%sfatal error (%s)\n",
                            #    $fatal ? '' : 'non-',
                            #    $msg // 'Connection timed out';
                            return if !$fatal;
                        },
                        on_connect => sub {
                            my ($h, $host, $port, $retry) = @_;
                            $s->_add_peer($handle);
                            $handle->push_write(
                                         build_handshake(
                                             "\0\0\0\0\0\0\0\0", $s->infohash,
                                             $s->peerid
                                         )
                            );
                        },
                        on_eof => sub {
                            my $h = shift;
                            $s->_del_peer($h);
                        },
                        on_read => sub {
                            my $h = shift;
                            use Data::Dump;
                            while (my $packet = parse_packet(\$h->rbuf)) {

                                #ddx $packet;
                                if ($packet->{type} eq $KEEPALIVE) {

                                    # Do nothing!
                                }
                                elsif ($packet->{type} == $HANDSHAKE) {
                                    $s->peers->{$h}{peerid}
                                        = $packet->{payload}[1];
                                    $h->push_write(
                                                build_bitfield($s->bitfield));
                                    $s->peers->{$h}{timeout}
                                        = AE::timer(60, 0,
                                                   sub { $s->_del_peer($h) });
                                    $s->peers->{$h}{bitfield} = pack 'b*',
                                        "\0" x $s->piece_count;
                                }
                                elsif ($packet->{type} == $CHOKE) {
                                    $s->peers->{$h}{local_choked}   = 1;
                                    $s->peers->{$h}{local_requests} = [];
                                    $s->_consider_peer($s->peers->{$h});
                                }
                                elsif ($packet->{type} == $UNCHOKE) {
                                    $s->peers->{$h}{local_choked} = 0;
                                    $s->peers->{$h}{timeout}
                                        = AE::timer(120, 0,
                                                   sub { $s->_del_peer($h) });
                                    $s->_request_pieces($s->peers->{$h});
                                }
                                elsif ($packet->{type} == $HAVE) {
                                    vec($s->peers->{$h}{bitfield},
                                        $packet->{payload}, 1)
                                        = 1;
                                    $s->_consider_peer($s->peers->{$h});
                                    $s->peers->{$h}{timeout}
                                        = AE::timer(60, 0,
                                                   sub { $s->_del_peer($h) });
                                }
                                elsif ($packet->{type} == $BITFIELD) {
                                    $s->peers->{$h}{bitfield}
                                        = $packet->{payload};
                                    $s->_consider_peer($s->peers->{$h});
                                }
                                elsif ($packet->{type} == $PIECE) {
                                    $s->peers->{$h}{timeout}
                                        = AE::timer(120, 0,
                                                   sub { $s->_del_peer($h) });
                                    my ($index, $offset, $data)
                                        = @{$packet->{payload}};

                                    # XXX - Make sure $index is working piece
                                    # XXX - Make sure we req from this peer
                                    $s->working_pieces->{$index}{$offset}[4]
                                        = $data;
                                    $s->working_pieces->{$index}{$offset}[5]
                                        = ();
                                    if (0 == scalar grep { !defined $_->[4] }
                                        values %{$s->working_pieces->{$index}}
                                        )
                                    {   my $piece = join '', map {
                                            $s->working_pieces->{$index}{$_}
                                                [4]
                                            }
                                            sort { $a <=> $b }
                                            keys
                                            %{$s->working_pieces->{$index}};
                                        if (substr($s->pieces, $index * 20,
                                                   20
                                            ) eq sha1($piece)
                                            )
                                        {   $s->_write($index, $offset,
                                                       $data);
                                            vec($s->{bitfield}, $i, 1) = 1

                                                # XXX - Broadcast HAVE
                                        }
                                        else {

                                            # XXX - Not sure what to do... I'd
                                            #       ban the peers involved and
                                            #       try the same piece again.
                                        }
                                        delete $s->working_pieces->{$index};
                                    }
                                    $s->_request_pieces($s->peers->{$h});
                                }
                                else {
                                    ...;
                                }
                                last if !$h->rbuf;
                            }
                        }
                    );
                }
            }
        );
    }
);

sub _consider_peer {    # Figure out whether or not we find a peer interesting
    my ($s, $p) = @_;
    my $relevence
        = unpack('b*', $p->{bitfield}) & ~unpack('b*', $s->bitfield);
    my $interesting = (index(unpack('b*', $relevence), 1, 0) != -1) ? 1 : 0;
    if ($interesting) {
        if (!$p->{local_interested}) {
            $p->{local_interested} = 1;
            $p->{handle}->push_write(build_interested());
        }
    }
    else {
        if ($p->local_interested) {
            $p->{local_interested} = 0;
            $p->{handle}->push_write(build_not_interested());
        }
    }
}
has working_pieces =>
    (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });

sub _request_pieces {
    my ($s, $p) = @_;
    use Scalar::Util qw[weaken];
    weaken $p;
    my $relevence = unpack('b*', $p->{bitfield}) & unpack('b*', $s->wanted);
    use Data::Dump;
    my @indexes;
    if (scalar keys $s->working_pieces < 10) {    # XXX - Max working pieces
        my $x = -1;
        @indexes = map { $x++; $_ ? $x : () } split '', $relevence;
    }
    else {
        @indexes = keys %{$s->working_pieces};
    }
    my $index = $indexes[rand @indexes];  # XXX - Weighted random/Rarest first
    my $block_count
        = $s->piece_length / $block_size;    # XXX - Len for last piece
    $s->working_pieces->{$index}
        ||= {map { $_ * $block_size, undef } 0 .. $block_count - 1};
    my @unrequested = sort { $a <=> $b }
        grep {    # XXX - If there are no unrequested blocks, pick a new index
        (!ref $s->working_pieces->{$index}{$_})
            || (   (!defined $s->working_pieces->{$index}{$_}[4])
                && (!defined $s->working_pieces->{$index}{$_}[3]))
        } keys %{$s->working_pieces->{$index}};
    for (scalar @{$p->{local_requests}} .. 3) {

        # XXX - Limit to x req per peer (future: based on bandwidth)
        last if !@unrequested;    # XXX - Start working on another piece
        my $offset = shift @unrequested;

        # warn sprintf 'Requesting %d, %d, %d', $index, $offset, $block_size;
        $p->{handle}->push_write(build_request($index, $offset, $block_size))
            ;                     # XXX - len for last piece
        push @{$p->{local_requests}}, [
            $index, $offset,
            $block_size,
            $p,     undef,
            AE::timer(
                60, 0,
                sub {
                    warn sprintf 'TIMEOUT!!! %d, %d, %d', $index, $offset,
                        $block_size;
                    $p->{handle}->push_write(
                                   build_cancel($index, $offset, $block_size))
                        if defined $p;
                    $s->working_pieces->{$index}{$offset} = ();
                    $p->{timeout} = AE::timer(45, 0,
                                         sub { $s->_del_peer($p->{handle}) });

                    #$s->_request_pieces( $p)
                }
            )
        ];
        $s->working_pieces->{$index}{$offset} = $p->{local_requests}[-1];
        weaken($s->working_pieces->{$index}{$offset});
    }
}

#
__PACKAGE__->meta->make_immutable();
no Mouse;
no Mouse::Util::TypeConstraints;
1;

package main;
use AnyEvent;
$|++;

#
my $client = AnyEvent::BitTorrent->new(
                     basedir => 'D:\Downloads\Incomplete',
                     path => 'Sick of Sarah - 2205 BitTorrent Edition.torrent'
);
use Data::Dump;
ddx $client;
ddx $client->trackers;
ddx $client;
warn $client->peerid;
ddx $client->infohash;
ddx $client->files;
warn $client->size;
warn $client->name;

#warn $client->_write(1, 56, 'quick test');
#warn $client->_read(1, 56, 33);
warn $client->hashcheck;
warn $client->bitfield;
AE::cv->recv;