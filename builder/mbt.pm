package builder::mbt v0.0.1 {    # inspired by Module::Build::Tiny 0.047
    use v5.26;
    use CPAN::Meta;
    use ExtUtils::Config 0.003;
    use ExtUtils::Helpers 0.020 qw/make_executable split_like_shell detildefy/;
    use ExtUtils::Install qw/pm_to_blib install/;
    use ExtUtils::InstallPaths 0.002;
    use File::Spec::Functions qw/catfile catdir rel2abs abs2rel/;
    use Getopt::Long 2.36     qw/GetOptionsFromArray/;
    use JSON::Tiny            qw[encode_json decode_json];          # Not in CORE
    use Path::Tiny            qw[path];                             # Not in CORE
    my $cwd = path('.')->realpath;

    sub get_meta {
        state $metafile //= path('META.json');
        exit say "No META information provided\n" unless $metafile->is_file;
        return CPAN::Meta->load_file( $metafile->realpath );
    }

    sub find {
        my ( $pattern, $dir ) = @_;

        #~ $dir = path($dir) unless $dir->isa('Path::Tiny');
        sort values %{
            $dir->visit(
                sub {
                    my ( $path, $state ) = @_;
                    $state->{$path} = $path if $path->is_file && $path =~ $pattern;
                },
                { recurse => 1 }
            )
        };
    }
    my %actions;
    %actions = (
        build => sub {
            my %opt     = @_;
            my %modules = map { $_->relative => $cwd->child( 'blib', $_->relative )->relative } find( qr/\.pm$/,  $cwd->child('lib') );
            my %docs    = map { $_->relative => $cwd->child( 'blib', $_->relative )->relative } find( qr/\.pod$/, $cwd->child('lib') );
            my %scripts = map { $_->relative => $cwd->child( 'blib', $_->relative )->relative } find( qr/(?:)/,   $cwd->child('script') );
            my %sdocs   = map { $_           => delete $scripts{$_} } grep {/.pod$/} keys %scripts;
            my %shared  = map { $_->relative => $cwd->child( qw[blib lib auto share dist], $opt{meta}->name )->relative }
                find( qr/(?:)/, $cwd->child('share') );
            pm_to_blib( { %modules, %docs, %scripts, %shared }, $cwd->child(qw[blib lib auto]) );
            make_executable($_) for values %scripts;
            $cwd->child(qw[blib arch])->mkdir( { verbose => $opt{verbose} } );
            return 0;
        },
        test => sub {
            my %opt = @_;
            $actions{build}->(%opt) if not -d 'blib';
            require TAP::Harness::Env;
            TAP::Harness::Env->create(
                {   verbosity => $opt{verbose},
                    jobs      => $opt{jobs} // 1,
                    color     => !!-t STDOUT,
                    lib       => [ map { $cwd->child( 'blib', $_ )->canonpath } qw[arch lib] ]
                }
            )->runtests( map { $_->relative->stringify } find( qr/\.t$/, $cwd->child('t') ) )->has_errors;
        },
        install => sub {
            my %opt = @_;
            $actions{build}->(%opt) if not -d 'blib';
            install( $opt{install_paths}->install_map, @opt{qw[verbose dry_run uninst]} );
            return 0;
        },
        clean => sub {
            my %opt = @_;
            path($_)->remove_tree( { verbose => $opt{verbose} } ) for qw[blib temp Build _build_params MYMETA.json];
            return 0;
        },
    );

    sub Build {
        my $action = @ARGV && $ARGV[0] =~ /\A\w+\z/ ? shift @ARGV : 'build';
        $actions{$action} // exit say "No such action: $action";
        my $build_params = path('_build_params');
        my ( $env, $bargv ) = $build_params->is_file ? @{ decode_json( $build_params->slurp ) } : ();
        GetOptionsFromArray(
            $_,
            \my %opt,
            qw/install_base=s install_path=s% installdirs=s destdir=s prefix=s config=s% uninst:1 verbose:1 dry_run:1 pureperl-only:1 create_packlist=i jobs=i/
        ) for grep {defined} $env, $bargv, \@ARGV;
        $_ = detildefy($_) for grep {defined} @opt{qw[install_base destdir prefix]}, values %{ $opt{install_path} };
        @opt{qw[config meta]} = ( ExtUtils::Config->new( $opt{config} ), get_meta() );
        exit $actions{$action}->( %opt, install_paths => ExtUtils::InstallPaths->new( %opt, dist_name => $opt{meta}->name ) );
    }

    sub Build_PL {
        my $meta = get_meta();
        printf "Creating new 'Build' script for '%s' version '%s'\n", $meta->name, $meta->version;
        $cwd->child('Build')->spew( sprintf "#!%s\nuse lib '%s', '.';\nuse %s;\n%s::Build();\n", $^X, $cwd->canonpath, __PACKAGE__, __PACKAGE__ );
        make_executable('Build');
        my @env = defined $ENV{PERL_MB_OPT} ? split_like_shell( $ENV{PERL_MB_OPT} ) : ();
        $cwd->child('_build_params')->spew( encode_json( [ \@env, \@ARGV ] ) );
        $meta->save('MYMETA.json');
    }
}
1;
