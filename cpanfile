requires 'perl', '5.036';    # I do not care about issues from ancient perls
on 'test' => sub {
    requires 'Test2::V0';
};
requires 'Digest::SHA';
requires 'Type::Tiny';
on test => sub {
    requires 'Test2::V0';
    requires 'Test2::Tools::Compare';
    requires 'Test2::Plugin::UTF8';

    # requires 'Capture::Tiny';
    # requires 'Data::Dump';
};
on configure => sub {
    requires 'JSON::Tiny';
    requires 'Path::Tiny';
    requires 'ExtUtils::Helpers', 0.020;
    requires 'ExtUtils::Install';
    requires 'ExtUtils::InstallPaths', 0.002;
    requires 'File::Spec::Functions';
    requires 'Getopt::Long', 2.36;
    requires 'Config';
    requires 'Module::Build::Tiny';
};
on develop => sub {

    # requires 'https://github.com/sanko/mii.git'
    requires 'CPAN::Uploader';
    requires 'Code::TidyAll';
    requires 'Code::TidyAll::Plugin::ClangFormat';
    requires 'Code::TidyAll::Plugin::PodTidy';
    requires 'Perl::Tidy';
    requires 'Pod::Tidy';
    requires 'Test::CPAN::Meta';
    requires 'Test::MinimumVersion::Fast';
    requires 'Test::PAUSE::Permissions';
    requires 'Software::License::Artistic_2_0';
};
