package Pakket::Builder::Native::Makefile;
# ABSTRACT: Build Native Pakket packages that use Makefile

use Moose;
use MooseX::StrictConstructor;
use Log::Any   qw< $log >;
use Path::Tiny qw< path >;
use Pakket::Log;
use Pakket::Utils qw< generate_env_vars >;

with qw<Pakket::Role::Builder>;

sub build_package {
    my ( $self, $package, $build_dir, $prefix, $flags ) = @_;

    $log->info("Building Native library: $package");

    my $opts = {
        'env' => {
            generate_env_vars($build_dir, $prefix),
        },
    };

    my $configurator;
    if ( -f $build_dir->child('configure') ) {
        $configurator = './configure';
    } elsif ( -f $build_dir->child('config') ) {
        $configurator = './config';
    } elsif ( -f $build_dir->child('Configure') ) {
        $configurator = './Configure';
    } else {
        die $log->critical( "Don't know how to configure $package"
                . " (Cannot find executale 'configure' or 'config')" );
    }

    my @seq = (

        # configure
        [
            $build_dir,
            [
                $configurator, '--prefix=' . $prefix->absolute,
                @{$flags},
            ],
            $opts,
        ],

        # build
        [ $build_dir, ['make'], $opts, ],

        # install
        [ $build_dir, [ 'make', 'install' ], $opts, ],
    );

    my $success = $self->run_command_sequence(@seq);

    if ( !$success ) {
        die $log->critical("Failed to build $package");
    }

    $log->info("Done preparing $package");

    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=pod
