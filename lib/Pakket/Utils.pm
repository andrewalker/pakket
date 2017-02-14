package Pakket::Utils;
# ABSTRACT: Utilities for Pakket

use strict;
use warnings;
use version 0.77;

use Exporter qw< import >;
use JSON::MaybeXS;

our @EXPORT_OK = qw<
    is_writeable
    generate_env_vars
    canonical_package_name
    encode_json_pretty
>;

sub is_writeable {
    my $path = shift; # Path::Tiny objects

    while ( !$path->is_rootdir ) {
        $path->exists and return -w $path;
        $path = $path->parent;
    }

    return -w $path;
}

sub generate_env_vars {
    my ( $build_dir, $prefix ) = @_;
    my $lib_path = generate_lib_path($prefix);
    my $bin_path = generate_bin_path($prefix);

    my @perl5lib = (
        $build_dir,
        $prefix->child( qw<lib perl5> )->absolute->stringify,
    );

    my %perl_opts = (
        'PERL5LIB'                  => join( ':', @perl5lib ),
        'PERL_LOCAL_LIB_ROOT'       => '',
        'PERL5_CPAN_IS_RUNNING'     => 1,
        'PERL5_CPANM_IS_RUNNING'    => 1,
        'PERL5_CPANPLUS_IS_RUNNING' => 1,
        'PERL_MM_USE_DEFAULT'       => 1,
        'PERL_MB_OPT'               => '',
        'PERL_MM_OPT'               => '',
    );

    return (
        'CPATH'           => $prefix->child('include')->stringify,
        'LD_LIBRARY_PATH' => $lib_path,
        'LIBRARY_PATH'    => $lib_path,
        'PATH'            => $bin_path,
        %perl_opts,
    );
}

sub generate_lib_path {
    my $prefix = shift;

    my $lib_path = $prefix->child('lib')->absolute->stringify;
    if ( defined( my $env_library_path = $ENV{'LD_LIBRARY_PATH'} ) ) {
        $lib_path .= ":$env_library_path";
    }

    return $lib_path;
}

sub generate_bin_path {
    my $prefix = shift;

    my $bin_path = $prefix->child('bin')->absolute->stringify;
    if ( defined( my $env_bin_path = $ENV{'PATH'} ) ) {
        $bin_path .= ":$env_bin_path";
    }

    return $bin_path;
}

sub canonical_package_name {
    my ( $category, $package, $version ) = @_;

    $version
        and return sprintf( '%s/%s=%s', $category, $package, $version );

    return sprintf( '%s/%s', $category, $package );
}

sub encode_json_pretty {
    my $content = shift;
    return JSON::MaybeXS->new->pretty->canonical->encode($content);
}

1;

__END__
