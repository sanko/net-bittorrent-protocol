# Based on Module::Build::Tiny which is copyright (c) 2011 by Leon Timmermans, David Golden.
# Module::Build::Tiny is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
use v5.40;
use feature 'class';
no warnings 'experimental::class';
class    #
    Net::BitTorrent::Protocol::Builder {
    use Exporter 5.57 'import';
    use CPAN::Meta;
    use ExtUtils::Install qw/pm_to_blib install/;
    use ExtUtils::InstallPaths 0.002;
    use File::Basename        qw/basename dirname/;
    use File::Find            ();
    use File::Path            qw/mkpath rmtree/;
    use File::Spec::Functions qw/catfile catdir rel2abs abs2rel splitdir curdir/;
    use Getopt::Long 2.36     qw/GetOptionsFromArray/;
    use JSON::PP 2            qw[encode_json decode_json];

    # Not in CORE
    use Path::Tiny qw[path];
    use ExtUtils::Helpers 0.028 qw[make_executable split_like_shell detildefy];
    #
    field $action : param //= 'build';
    field $hey;
    field $install_base : param //= '';
    field $installdirs : param  //= '';
    field $destdir : param      //= '';
    field $prefix : param       //= '';
    field %config;
    field $uninst : param   //= 0;    # Make more sense to have a ./Build uninstall command but...
    field $verbose : param  //= 0;
    field $dry_run : param  //= 0;
    field $pureperl : param //= 0;
    field $jobs : param     //= 1;

    method write_file( $filename, $content ) {
        path($filename)->spew_utf8($content) or die "Could not open $filename: $!\n";
    }

    method read_file ($filename) {
        path($filename)->slurp_utf8 or die "Could not open $filename: $!\n";
    }

    method get_meta() {
        -e 'META.json' or die "No META information provided\n";
        CPAN::Meta->load_file('META.json');
    }

    sub find {
        my ( $pattern, $dir ) = @_;
        my @ret;
        File::Find::find( sub { push @ret, $File::Find::name if /$pattern/ && -f }, $dir ) if -d $dir;
        return @ret;
    }

    method step_build(%opt) {
        for my $pl_file ( find( qr/\.PL$/, 'lib' ) ) {
            ( my $pm = $pl_file ) =~ s/\.PL$//;
            system $^X, $pl_file, $pm and die "$pl_file returned $?\n";
        }
        my %modules       = map { $_ => catfile( 'blib', $_ ) } find( qr/\.pm$/,  'lib' );
        my %docs          = map { $_ => catfile( 'blib', $_ ) } find( qr/\.pod$/, 'lib' );
        my %scripts       = map { $_ => catfile( 'blib', $_ ) } find( qr/(?:)/,   'script' );
        my %sdocs         = map { $_ => delete $scripts{$_} } grep {/.pod$/} keys %scripts;
        my %dist_shared   = map { $_ => catfile( qw/blib lib auto share dist/, $opt{meta}->name, abs2rel( $_, 'share' ) ) } find( qr/(?:)/, 'share' );
        my %module_shared = map { $_ => catfile( qw/blib lib auto share module/, abs2rel( $_, 'module-share' ) ) } find( qr/(?:)/, 'module-share' );
        pm_to_blib( { %modules, %docs, %scripts, %dist_shared, %module_shared }, catdir(qw/blib lib auto/) );
        make_executable($_) for values %scripts;
        !mkpath( catdir(qw/blib arch/), $opt{verbose} );
    }

    method step_test(%opt) {
        $self->step_build(%opt) unless -d 'blib';
        require TAP::Harness::Env;
        my %test_args = (
            ( verbosity => $opt{verbose} ) x !!exists $opt{verbose},
            ( jobs  => $opt{jobs} ) x !!exists $opt{jobs},
            ( color => 1 ) x !!-t STDOUT,
            lib => [ map { rel2abs( catdir( qw/blib/, $_ ) ) } qw/arch lib/ ],
        );
        TAP::Harness::Env->create( \%test_args )->runtests( sort +find( qr/\.t$/, 't' ) )->has_errors;
    }

    method step_install(%opt) {
        $self->step_build(%opt) unless -d 'blib';
        install( $opt{install_paths}->install_map, @opt{qw/verbose dry_run uninst/} );
        return 0;
    }

    method step_clean(%opt) {
        rmtree( $_, $opt{verbose} ) for qw/blib temp/;
        return 0;
    }

    method step_realclean (%opt) {
        rmtree( $_, $opt{verbose} ) for qw/blib temp Build _build_params MYMETA.yml MYMETA.json/;
        return 0;
    }

    method get_arguments (@sources) {
        my %opt;
        $_ = detildefy($_) for grep {defined} @opt{qw/install_base destdir prefix/}, values %{ $opt{install_path} };

        #~ my $config             = ExtUtils::Config->new($config);
        $opt{meta}          = $self->get_meta();
        $opt{install_paths} = ExtUtils::InstallPaths->new( %opt, dist_name => $opt{meta}->name );
        return %opt;
    }

    method Build(@args) {
        my $method = $self->can( 'step_' . $action );
        $method // die "No such action '$action'\n";
        exit $method->($self);
    }

    method Build_PL() {
        my $meta = $self->get_meta();
        say sprintf 'Creating new Build script for %s %s', $meta->name, $meta->version;
        $self->write_file( 'Build', sprintf <<'', $^X, __PACKAGE__, __PACKAGE__ );
#!%s
use lib 'builder';
use %s;
%s->new( @ARGV && $ARGV[0] =~ /\A\w+\z/ ? ( action => shift @ARGV ) : (),
    map { /^--/ ? ( shift(@ARGV) =~ s[^--][]r => 1 ) : /^-/ ? ( shift(@ARGV) =~ s[^-][]r => shift @ARGV ) : () } @ARGV )->Build();

        make_executable('Build');
        my @env = defined $ENV{PERL_MB_OPT} ? split_like_shell( $ENV{PERL_MB_OPT} ) : ();
        $self->write_file( '_build_params', encode_json( [ \@env, \@ARGV ] ) );
        if ( my $dynamic = $meta->custom('x_dynamic_prereqs') ) {
            my %meta = ( %{ $meta->as_struct }, dynamic_config => 0 );
            my %opt  = get_arguments( \@env, \@ARGV );
            require CPAN::Requirements::Dynamic;
            my $dynamic_parser = CPAN::Requirements::Dynamic->new(%opt);
            my $prereq         = $dynamic_parser->evaluate($dynamic);
            $meta{prereqs} = $meta->effective_prereqs->with_merged_prereqs($prereq)->as_string_hash;
            $meta = CPAN::Meta->new( \%meta );
        }
        $meta->save(@$_) for ['MYMETA.json'];
    }
    };
1;
