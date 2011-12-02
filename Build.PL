#!/usr/bin/perl -w
use strict;
use warnings;
use File::Find;
use Module::Build;
my $automated_testing = $ENV{'AUTOMATED_TESTING'}
    || $ENV{'PERL_MM_USE_DEFAULT'};
my $is_developer = ((-d '.git') ? 1 : 0) or ($ENV{'RELEASE_TESTING'} ? 1 : 0);
my @tests;
find \&find_cb, qw[t/];
my $mb = Module::Build->new(
      module_name   => 'Net::BitTorrent::Protocol',
      license       => 'artistic_2',
      dist_author   => 'Sanko Robinson <sanko@cpan.org>',
      dist_abstract => 'Basic, Protocol-level BitTorrent Utilities',
      requires      => {
                   Carp            => 0,
                   Exporter        => 0,
                   'Module::Build' => 0.38,
                   perl            => '5.10.0'
      },
      build_requires => {Carp            => 0,
                         Exporter        => 0,
                         'Module::Build' => 0.38,
                         perl            => '5.10.0',
                         'Test::More'    => 0
      },
      configure_requires => {'File::Find'    => 0,
                             'Module::Build' => 0.38
      },
      auto_features => {
          packet_dump_support => {
              description => 'Dumps unhanded packets for easy bug reporting',
              requires    => {'Data::Dump' => 0}
          }
      },
      test_files     => \@tests,
      test_file_exts => ['.t'],
      meta_merge     => {
           keywords =>
               [qw[BitTorrent Protocol Packet Utility Bencode Compact Peers]],
           resources => {
               bugtracker => 'http://github.com/sanko/net-bittorrent/issues',
               repository =>
                   'git://github.com/sanko/net-bittorrent-protocol.git',
               ChangeLog =>
                   'http://github.com/sanko/net-bittorrent-protocol/commits/',
               homepage => 'http://sankorobinson.com/net-bittorrent/'
           }
      },
      create_readme => 1
);
$mb->notes(automated_testing => $automated_testing ? 1 : 0);
$mb->notes(release_testing   => $is_developer);
$mb->notes(test_suite        => \@tests);
$mb->notes(gmtime            => gmtime);
$mb->notes(verbose => scalar grep {m[^v$]} keys %{$mb->args()});
$mb->create_build_script;
exit 0;

sub find_cb {
    return if -d $_ or -l $_;
    return unless -T $_;
    return unless $_ =~ m[.+\.t$];
    return push @tests, $File::Find::name;
}

=pod

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
