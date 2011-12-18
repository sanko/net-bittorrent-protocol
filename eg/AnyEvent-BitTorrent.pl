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
use AnyEvent::Socket;
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
has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
    writer  => '_set_port',

    #trigger => sub {
    #    my ($s, $p) = @_;
    #    return if !$s->_has_socket;
    #    use Data::Dump;
    #    ddx \@_;
    #    die;
    #}
);
has socket => (is        => 'ro',
               isa       => 'Ref',
               init_arg  => undef,
               required  => 1,
               predicate => '_has_socket',
               builder   => '_build_socket'
);

sub _build_socket {
    my $s = shift;
    tcp_server undef, $s->port, sub {
        my ($fh, $host, $port) = @_;
        warn sprintf 'New Peer!!!! %s:%d', $host, $port;
        my $handle = AnyEvent::Handle->new(
            fh       => $fh,
            on_error => sub {
                my ($hdl, $fatal, $msg) = @_;
                AE::log error => "got error $msg\n";
                $s->_del_peer($hdl);
            },
            on_eof => sub {
                warn;
                my $h = shift;
                $s->_del_peer($h);
            },
            on_read => sub { $s->_on_read_incoming(@_) }
        );
        $s->_add_peer($handle);
        }, sub {
        my ($fh, $thishost, $thisport) = @_;
        $s->_set_port($thisport);
        AE::log info => "bound to $thishost, port $thisport";
        };
}
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
                 '-AB%02d%02d-%7s%-5s',
                 ($AnyEvent::BitTorrent::VERSION =~ m[^v(\d+)\.(\d+)]),
                 (  join '',
                    map {
                        ['A' .. 'Z', 'a' .. 'z', 0 .. 9, qw[- . _ ~]]
                        ->[rand(66)]
                        } 1 .. 7
                 ),
                 [qw[KaiLi April]]->[rand 2]
             )
            )
        );
    }
);
has bitfield => (is         => 'ro',
                 isa        => 'Str',
                 init_arg   => undef,
                 lazy_build => 1
);
sub _build_bitfield { my $s = shift; pack 'b*', "\0" x $s->piece_count }
sub wanted { ~shift->bitfield }

sub _left {
    my $s = shift;
    $s->piece_length * scalar grep {$_} split '',
        substr unpack('b*', $s->wanted), 0, $s->piece_count + 1;
}
has $_ => (is      => 'ro',
           isa     => 'Num',
           default => 0,
           writer  => '_set_' . $_
) for qw[uploaded downloaded];
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
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub { File::Spec->rel2abs(File::Spec->curdir) },
    trigger  => sub {
        my ($s, $n, $o) = @_;
        $o // return;
        $s->_clear_files;    # So they can be rebuilt with the new basedir
    }
);
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
                    File::Spec->catfile($s->basedir, $s->name, @{$_->{path}}))
            }
            } @{$s->metadata->{info}{files}}
        ]
        : [
          {length => $s->metadata->{info}{length},
           path =>
               File::Spec->rel2abs(File::Spec->catfile($s->basedir, $s->name))
          }
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

sub hashcheck (;$) {
    my $s       = shift;
    my $indexes = [0 .. $s->piece_count];
    $indexes = [shift] if @_;
    $s->bitfield;    # Makes sure it's built
    for my $index (@$indexes) {
        my $piece = $s->_read($index,
                              0,
                              $index == $s->piece_count
                              ?
                                  $s->size % $s->piece_length
                              : $s->piece_length
        );
        my $ok = defined($piece)
            && (substr($s->pieces, $index * 20, 20) eq sha1($piece));
        $ok ?
            $s->_trigger_hash_pass($index)
            : $s->_trigger_hash_fail($index);
        vec($s->{bitfield}, $index, 1) = $ok;
    }
}
has peers => (
    is      => 'ro',
    isa     => 'HashRef[HashRef]',
    default => sub { {} }

        # { handle            => AnyEvent::Handle
        #   peerid            => 'Str'
        #   reserved          => 'Str'
        #   bitfield          => 'Str'
        #   remote_choked     => 1
        #   remote_interested => 0
        #   remote_requests   => ArrayRef[ArrayRef] # List of [i, o, l]
        #   local_choked      => 1
        #   local_interested  => 0
        #   local_requests    => ArrayRef[ArrayRef] # List of [i, o, l]
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
    for my $req (@{$s->peers->{$h}{local_requests}}) {
        my ($i, $o, $l) = @$req;
        $s->working_pieces->{$i}{$o}[3] = ();
    }
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
        [defined $s->metadata->{announce} ?
             [$s->metadata->{announce}]
         : ()
        ];
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
                    . ('&peer_id=' . $s->peerid)
                    . ('&uploaded=' . $s->uploaded)
                    . ('&downloaded=' . $s->downloaded)
                    . ('&left=' . $s->_left)
                    . ('&port=' . $s->port)
                    . '&compact=1', sub {
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
has _choke_timer => (
    is       => 'bare',
    isa      => 'Ref',
    init_arg => undef,
    required => 1,
    default  => sub {
        my $s = shift;
        AE::timer(
            10, 40,
            sub {
                my @interested
                    = grep { $_->{remote_interested} && $_->{remote_choked} }
                    values %{$s->peers};

                # XXX - Limit the number of upload slots
                for my $p (@interested) {
                    $p->{remote_choked} = 0;
                    $p->{handle}->push_write(build_unchoke());
                }

                # XXX - Send choke to random peer
            }
        );
    }
);
has _fill_requests_timer => (
    is       => 'bare',
    isa      => 'Ref',
    init_arg => undef,
    required => 1,
    default  => sub {
        my $s = shift;
        AE::timer(
            15, 1,
            sub {    # XXX - Limit by time/bandwidth
                my @waiting = grep { scalar @{$_->{remote_requests}} }
                    values %{$s->peers};
                return if !@waiting;
                my $p          = $waiting[rand $#waiting];
                my $total_sent = 0;
                while ($total_sent < 2**20 && @{$p->{remote_requests}}) {
                    my $req = shift @{$p->{remote_requests}};

                    # XXX - If piece is bad locally
                    #          if remote supports fast ext
                    #             send reject
                    #          else
                    #             simply return
                    #       else...
                    $p->{handle}->push_write(
                               build_piece($req->[0],
                                           $req->[1],
                                           $s->_read(
                                               $req->[0], $req->[1], $req->[2]
                                           )
                               )
                    );
                    $total_sent += $req->[2];
                }
                $s->_set_uploaded($s->uploaded + $total_sent);
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
                return if !$s->_left;

                # XXX - Initiate connections when we are in Super seed mode?
                my @cache = uncompact_ipv4($s->peer_cache);
                return if !@cache;
                for my $i (1 .. @cache) {
                    last if $i == 10;    # XXX - Max half open
                    last
                        if scalar(keys %{$s->peers}) > 100;  # XXX - Max peers
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
                        on_read => sub { $s->_on_read(@_) }
                    );
                }
            }
        );
    }
);

sub _on_read_incoming {
    my ($s, $h) = @_;
    ddx $h->rbuf;
    warn $h->rbuf;
    $h->rbuf // return;
    my $packet = parse_packet(\$h->rbuf);
    return if !$packet;
    ddx $packet;
    if (defined $packet->{error}) {
        return $s->_del_peer($h);
    }
    elsif ($packet->{type} == $HANDSHAKE) {
        $s->peers->{$h}{reserved} = $packet->{payload}[0];
        return $s->_del_peer($h)
            if $packet->{payload}[1] ne $s->infohash;
        $s->peers->{$h}{peerid} = $packet->{payload}[2];
        $h->push_write(
               build_handshake("\0\0\0\0\0\0\0\0", $s->infohash, $s->peerid));
        $h->push_write(build_bitfield($s->bitfield));
        $s->peers->{$h}{timeout}
            = AE::timer(60, 0, sub { $s->_del_peer($h) });
        $s->peers->{$h}{bitfield} = pack 'b*', "\0" x $s->piece_count;
        $h->on_read(sub { $s->_on_read(@_) });
    }
    else {
        ...;

        # Assume encrypted
    }
    1;
}

sub _on_read {
    my ($s, $h) = @_;
    while (my $packet = parse_packet(\$h->rbuf)) {
        if (defined $packet->{error}) {
            $s->_del_peer($h);
            return;
        }
        elsif ($packet->{type} eq $KEEPALIVE) {

            # Do nothing!
        }
        elsif ($packet->{type} == $HANDSHAKE) {
            ref $packet->{payload} // ddx $packet;
            $s->peers->{$h}{reserved} = $packet->{payload}[0];
            return $s->_del_peer($h)
                if $packet->{payload}[1] ne $s->infohash;
            $s->peers->{$h}{peerid} = $packet->{payload}[2];
            $h->push_write(build_bitfield($s->bitfield));
            $s->peers->{$h}{timeout}
                = AE::timer(60, 0, sub { $s->_del_peer($h) });
            $s->peers->{$h}{bitfield} = pack 'b*', "\0" x $s->piece_count;
        }
        elsif ($packet->{type} == $INTERESTED) {
            $s->peers->{$h}{remote_interested} = 1;
        }
        elsif ($packet->{type} == $CHOKE) {
            $s->peers->{$h}{local_choked} = 1;
            for my $req (@{$s->peers->{$h}{local_requests}}) {
                $s->working_pieces->{$req->[0]}{$req->[1]}[3] = ()
                    unless
                    defined $s->working_pieces->{$req->[0]}{$req->[1]}[4];
            }
            $s->_consider_peer($s->peers->{$h});
        }
        elsif ($packet->{type} == $UNCHOKE) {
            $s->peers->{$h}{local_choked} = 0;
            $s->peers->{$h}{timeout}
                = AE::timer(120, 0, sub { $s->_del_peer($h) });
            $s->_request_pieces($s->peers->{$h});
        }
        elsif ($packet->{type} == $HAVE) {
            vec($s->peers->{$h}{bitfield}, $packet->{payload}, 1) = 1;
            $s->_consider_peer($s->peers->{$h});
            $s->peers->{$h}{timeout}
                = AE::timer(60, 0, sub { $s->_del_peer($h) });
        }
        elsif ($packet->{type} == $BITFIELD) {
            $s->peers->{$h}{bitfield} = $packet->{payload};
            $s->_consider_peer($s->peers->{$h});
        }
        elsif ($packet->{type} == $REQUEST) {
            $s->peers->{$h}{timeout}
                = AE::timer(120, 0, sub { $s->_del_peer($h) });

            # XXX - Make sure (index + offset + length) < $s->size
            #       if not, send reject if remote supports fast ext
            #       either way, ignore the request
            push @{$s->peers->{$h}{remote_requests}}, $packet->{payload};
        }
        elsif ($packet->{type} == $PIECE) {
            $s->peers->{$h}{timeout}
                = AE::timer(120, 0, sub { $s->_del_peer($h) });
            my ($index, $offset, $data) = @{$packet->{payload}};

            # Make sure $index is a working piece
            $s->working_pieces->{$index} // return;

            # Make sure we req from this peer
            return
                if !grep {
                       $_->[0] == $index
                    && $_->[1] == $offset
                    && $_->[2] == length $data
                } @{$s->peers->{$h}{local_requests}};
            $s->peers->{$h}{local_requests} = [
                grep {
                           ($_->[0] != $index)
                        || ($_->[1] != $offset)
                        || ($_->[2] != length($data))
                    } @{$s->peers->{$h}{local_requests}}
            ];
            $s->working_pieces->{$index}{$offset}[4] = $data;
            $s->working_pieces->{$index}{$offset}[5] = ();
            $s->_set_downloaded($s->downloaded + length $data);
            if (0 == scalar grep { !defined $_->[4] }
                values %{$s->working_pieces->{$index}})
            {   my $piece = join '',
                    map  { $s->working_pieces->{$index}{$_}[4] }
                    sort { $a <=> $b }
                    keys %{$s->working_pieces->{$index}};
                if ((substr($s->pieces, $index * 20, 20) eq sha1($piece))) {
                    $s->_write($index, 0, $piece);
                    $s->hashcheck($index);    # XXX - Verify write
                    $s->_broadcast(build_have($index))
                        ;    # XXX - only broadcast to non-seeds
                    $s->_consider_peer($_)
                        for grep { $_->{local_interested} }
                        values %{$s->peers};
                }
                else {
                    $s->_trigger_hash_fail($index);

                    # XXX - Not sure what to do... I'd
                    #       ban the peers involved and
                    #       try the same piece again.
                }
                delete $s->working_pieces->{$index};
            }
            $s->_request_pieces($s->peers->{$h});
        }
        elsif ($packet->{type} == $CANCEL) {
            my ($index, $offset, $length) = @{$packet->{payload}};
            return    # XXX - error callback if this block is not in the queue
                if !grep {
                       $_->[0] == $index
                    && $_->[1] == $offset
                    && $_->[2] == $length
                } @{$s->peers->{$h}{remote_requests}};
            $s->peers->{$h}{remote_requests} = [
                grep {
                           ($_->[0] != $index)
                        || ($_->[1] != $offset)
                        || ($_->[2] != $length)
                    } @{$s->peers->{$h}{remote_requests}}
            ];
        }
        else {
            warn 'Unhandled packet: ' . dd $packet;
        }
        last
            if 5 > length($h->rbuf // '');    # Min size for protocol
    }
}

sub _broadcast {
    my ($s, $data) = @_;
    $_->{handle}->push_write($data) for values %{$s->peers};
}

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
        if ($p->{local_interested}) {
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
    return if !@indexes;
    my $index = $indexes[rand @indexes];  # XXX - Weighted random/Rarest first
    my $piece_size
        = $index == $s->piece_count ?
        $s->size % $s->piece_length
        : $s->piece_length;
    my $block_count = $piece_size / $block_size;
    my @offsets = map { $_ * $block_size }
        0 .. $block_count - ((int($block_count) == $block_count) ? 1 : 0);
    $s->working_pieces->{$index} //= {map { $_ => undef } @offsets};
    my @unrequested = sort { $a <=> $b }
        grep {    # XXX - If there are no unrequested blocks, pick a new index
        (!ref $s->working_pieces->{$index}{$_})
            || (   (!defined $s->working_pieces->{$index}{$_}[4])
                && (!defined $s->working_pieces->{$index}{$_}[3]))
        } @offsets;
    for (scalar @{$p->{local_requests}} .. 12) {
        my $offset = shift @unrequested;
        $offset // return;    # XXX - Start working on another piece
        my $_block_size
            = ($index == $s->piece_count && ($offset == $offsets[-1]))
            ?
            $piece_size % $block_size
            : $block_size;

        # XXX - Limit to x req per peer (future: based on bandwidth)
        #warn sprintf 'Requesting %d, %d, %d', $index, $offset, $_block_size;
        $p->{handle}->push_write(build_request($index, $offset, $_block_size))
            ;                 # XXX - len for last piece
        $s->working_pieces->{$index}{$offset} = [
            $index, $offset,
            $_block_size,
            $p,     undef,
            AE::timer(
                60, 0,
                sub {
                    $p // return;
                    $p->{handle} // return;
                    $p->{handle}->push_write(
                                 build_cancel($index, $offset, $_block_size));
                    $s->working_pieces->{$index}{$offset}[3] = ();
                    $p->{local_requests} = [
                        grep {
                                   $_->[0] != $index
                                || $_->[1] != $offset
                                || $_->[2] != $_block_size
                            } @{$p->{local_requests}}
                    ];
                    $p->{timeout} = AE::timer(45, 0,
                                         sub { $s->_del_peer($p->{handle}) });

                    #$s->_request_pieces( $p) #  XXX - Ask a different peer
                }
            )
        ];
        weaken($s->working_pieces->{$index}{$offset}[3]);
        push @{$p->{local_requests}}, [$index, $offset, $_block_size];
    }
}

# Cheap callback system
has on_hash_pass => (
    isa     => 'CodeRef',
    is      => 'rw',
    default => sub {
        sub { !!1 }
    },
    clearer => '_no_hash_pass'
);
sub _trigger_hash_pass { shift->on_hash_pass()->(@_) }
has on_hash_fail => (
    isa     => 'CodeRef',
    is      => 'rw',
    default => sub {
        sub { !!1 }
    },
    clearer => '_no_hash_fail'
);
sub _trigger_hash_fail { shift->on_hash_fail()->(@_) }

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
    port => 1338,

    #basedir => 'D:\Downloads\Incomplete',
    path =>
        'enough records - no loli-gagging - the floor is now lava.torrent',

    #path         => 'ubuntu-11.10-desktop-i386.iso.torrent',
    on_hash_pass => sub { warn 'PASS: ' . pop },
    on_hash_fail => sub { warn 'FAIL: ' . pop }
);
use Data::Dump;

#
ddx $client;
ddx $client->trackers;
ddx $client;
warn $client->peerid;
ddx $client->infohash;
ddx $client->files;
warn $client->size;
warn $client->name;

=begin comment my $index = 196;
  my $piece = $client->_read($index, 0, $client->piece_length);
  warn $client->_write($index, 0, 'break');
  warn $client->hashcheck($index);
  ##warn $client->_write($index, 0, $piece);
warn $client->hashcheck($index);
=cut
warn $client->hashcheck();
warn $client->bitfield;
AE::cv->recv;
