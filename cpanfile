requires 'Digest::SHA';
requires 'Socket';
requires 'Type::Tiny';
requires 'perl', 'v5.38.0';
on configure => sub {
    requires 'CPAN::Meta';
    requires 'Exporter',          '5.57';
    requires 'ExtUtils::Helpers', '0.028';
    requires 'ExtUtils::Install';
    requires 'ExtUtils::InstallPaths', '0.002';
    requires 'File::Basename';
    requires 'File::Find';
    requires 'File::Path';
    requires 'File::Spec::Functions';
    requires 'Getopt::Long', '2.36';
    requires 'JSON::PP',     '2';
    requires 'Path::Tiny';
    requires 'perl', 'v5.40.0';
};
on test => sub {
    requires 'Test2::Plugin::UTF8';
    requires 'Test2::Tools::Compare';
    requires 'Test2::V0';
};
on develop => sub {
    requires 'CPAN::Uploader';
    requires 'Code::TidyAll';
    requires 'Code::TidyAll::Plugin::ClangFormat';
    requires 'Code::TidyAll::Plugin::PodTidy';
    requires 'Perl::Tidy';
    requires 'Pod::Tidy';
    requires 'Software::License::Artistic_2_0';
    requires 'Test::CPAN::Meta';
    requires 'Test::MinimumVersion::Fast';
    requires 'Test::PAUSE::Permissions';
};
