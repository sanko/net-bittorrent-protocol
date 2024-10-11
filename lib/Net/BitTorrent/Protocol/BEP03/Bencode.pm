package Net::BitTorrent::Protocol::BEP03::Bencode v2.0.0 {
    use v5.38;
    use parent 'Exporter';
    our %EXPORT_TAGS = ( all => [ our @EXPORT_OK = qw[bencode bdecode] ], bencode => [] );

    sub bencode ( $ref //= return ) {
        return ( ( ( length $ref ) && $ref =~ m[^([-\+][1-9])?\d*$] ) ? ( 'i' . $ref . 'e' ) : ( length($ref) . ':' . $ref ) ) if !ref $ref;
        return join( '', 'l', ( map { bencode($_) } @{$ref} ),                                                           'e' ) if ref $ref eq 'ARRAY';
        return join( '', 'd', ( map { length($_) . ':' . $_ . bencode( $ref->{$_} ) } sort { $a cmp $b } keys %{$ref} ), 'e' ) if ref $ref eq 'HASH';
        return '';
    }

    sub bdecode( $string //= return, $k //= 0 ) {
        my ( $return, $leftover );
        if ( $string =~ s[^(0+|[1-9]\d*):][] ) {
            my $size = $1;
            $return = '' if $size =~ m[^0+$];
            $return .= substr( $string, 0, $size, '' );
            return if length $return < $size;
            return $k ? ( $return, $string ) : $return;    # byte string
        }
        elsif ( $string =~ s[^i([-\+]?\d+)e][] ) {         # integer
            my $int = $1;
            $int = () if $int =~ m[^-0] || $int =~ m[^0\d+];
            return $k ? ( $int, $string ) : $int;
        }
        elsif ( $string =~ s[^l(.*)][]s ) {                # list
            $leftover = $1;
            while ( $leftover and $leftover !~ s[^e][]s ) {
                ( my ($piece), $leftover ) = bdecode( $leftover, 1 );
                push @$return, $piece;
            }
            return $k ? ( \@$return, $leftover ) : \@$return;
        }
        elsif ( $string =~ s[^d(.*)][]s ) {                # dictionary
            $leftover = $1;
            my $pkey;
            while ( $leftover and $leftover !~ s[^e][]s ) {
                my ( $key, $value );
                ( $key, $leftover ) = bdecode( $leftover, 1 );
                ( $value, $leftover ) = bdecode( $leftover, 1 ) if $leftover;
                die 'malformed dictionary' if defined $pkey && defined $key && $pkey gt $key;    # BEP52
                $return->{$key} = $value if defined $key;
                $pkey           = $key   if defined $key;
            }
            return $k ? ( \%$return, $leftover ) : \%$return;
        }
        return;
    }
}
1;

=pod

=head1 NAME

Net::BitTorrent::Protocol::BEP03::Bencode - Utility functions for BEP03: The BitTorrent Protocol Specification

=head1 SYNOPSIS

    my $data = bencode( ... );
    my $ref = bdecode( $data );

=head1 Description

Bencoding is the BitTorrent protocol's basic serialization and data organization format. The specification supports
integers, lists (arrays), dictionaries (hashes), and byte strings.

=head1 Functions

By default, nothing is exported.

You may import any of the following functions by name or with the C<:all> tag.

=head2 C<bencode( ... )>

    $data = bencode( 100 );
    $data = bencode( { balance => '100.3', first => 'John', last => 'Smith' } );
    $data = bencode( [ { count => 1, product => 'apple' }, 30] );

Expects a single value (basic scalar, array reference, or hash reference) and returns a single string.

=head2 C<bdecode( ... )>

    $data = bdecode( 'i100e' );
    $data = bdecode( 'd7:balance5:100.35:first4:John4:last5:Smithe' );
    $data = bdecode( 'ld5:counti1e7:product5:appleei30ee' );

Expects a bencoded string.  The return value depends on the type of data contained in the string.

This function will C<die> on malformed data.

=head1 See Also

=over

=item The BitTorrent Protocol Specification

http://bittorrent.org/beps/bep_0003.html#the-connectivity-is-as-follows

=item Other Bencode related modules:

=over

=item L<Convert::Bencode|Convert::Bencode>

=item L<Bencode|Bencode>

=item L<Convert::Bencode_XS|Convert::Bencode_XS>

=back

=back

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2008-2024 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under the terms of L<The Artistic License
2.0|http://www.perlfoundation.org/artistic_license_2_0>. See the F<LICENSE> file included with this distribution or
L<notes on the Artistic License 2.0|http://www.perlfoundation.org/artistic_2_0_notes> for clarification.

When separated from the distribution, all original POD documentation is covered by the L<Creative Commons
Attribution-Share Alike 3.0 License|http://creativecommons.org/licenses/by-sa/3.0/us/legalcode>. See the
L<clarification of the CCA-SA3.0|http://creativecommons.org/licenses/by-sa/3.0/us/>.

Neither this module nor the L<Author|/Author> is affiliated with BitTorrent, Inc.

=cut
