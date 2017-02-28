package Pakket::Repository::Parcel;
# ABSTRACT: A parcel repository

use Moose;
use MooseX::StrictConstructor;

use Log::Any qw< $log >;
use Path::Tiny;
use Archive::Tar::Wrapper;

extends qw< Pakket::Repository >;

sub retrieve_package_parcel {
    my ( $self, $package ) = @_;
    return $self->retrieve_package_file( 'parcel', $package );
}

sub store_package_parcel {
    my ( $self, $package, $parcel_path ) = @_;

    my $file;
    if ( $parcel_path->is_file ) {
        # We were given a file, which we assume is a valid tar file.
        $file = $parcel_path;
    } elsif ( $parcel_path->is_dir ) {
        # We were given a directory, so we pack it up into a tar file.
        my $arch = Archive::Tar::Wrapper->new();
        $log->debug("Adding $parcel_path to file");

        $parcel_path->visit(
            sub {
                my ( $path, $stash ) = @_;

                $path->is_file
                    or return;

                $arch->add(
                    $path->relative($parcel_path)->stringify,
                    $path->stringify,
                );
            },
            { 'recurse' => 1 },
        );

        $file = Path::Tiny->tempfile();

        # Write and compress
        $log->debug("Writing archive as $file");
        $arch->write( $file->stringify, 1 );
    } else {
        die $log->criticalf( "Don't know how to deal with '%s', not file or directory",
                         $parcel_path->stringify );
    }

    $log->debug("Storing $file");
    $self->store_location( $package->id, $file );
}

sub remove_package_parcel {
    my ( $self, $package ) = @_;
    return $self->remove_package_file( 'parcel', $package );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
