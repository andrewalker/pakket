package Pakket::Role::Repository::Backend;
# ABSTRACT: A role for all repository backends

use Moose::Role;

# These are helper methods we want the backend to implement
# in order for the Repository to easily use across any backend
requires qw<
    all_object_ids has_object

    store_content  retrieve_content  remove_content
    store_location retrieve_location remove_location
>;

no Moose::Role;

1;

__END__

=pod
