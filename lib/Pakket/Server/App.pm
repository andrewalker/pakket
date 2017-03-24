package Pakket::Server::App;
# ABSTRACT: Webapp endpoints to server Pakket information

use Dancer2;
use Dancer2::Plugin::Pakket::ParamTypes;

use Log::Any qw< $log >;
use Pakket::Config;
use Pakket::Repository::Spec;
use Pakket::Repository::Parcel;
use Pakket::Repository::Source;

## no critic qw(Modules::RequireExplicitInclusion)

sub setup {
    my $class = shift;
    my $config_reader = Pakket::Config->new();
    my %config        = (
        %{ $config_reader->read_config },
        %{ config() },
    );

    my %instance_map = (
        'spec'   => sub { return Pakket::Repository::Spec->new(@_);   },
        'source' => sub { return Pakket::Repository::Source->new(@_); },
        'parcel' => sub { return Pakket::Repository::Parcel->new(@_); },
    );

    my $repositories_data = $config{'repositories'};
    foreach my $repository_type ( keys %{$repositories_data} ) {
        my $repo = $instance_map{$repository_type}->(
            'backend' => $repositories_data->{$repository_type},
        );

        prefix "/$repository_type" => sub {
            get '/has_object' => with_types [
                [ 'query', 'id', 'Str', 'MissingID' ],
            ] => sub {
                my $id = query_parameters->get('id');

                return encode_json({
                    'has_object' => $repo->has_object($id),
                });
            };

            get '/all_object_ids' => sub {
                return encode_json({
                    'object_ids' => $repo->all_object_ids,
                });
            };

            prefix '/retrieve' => sub {
                get '/content' => with_types [
                    [ 'query', 'id', 'Str', 'MissingID' ],
                ] => sub {
                    my $id = query_parameters->get('id');

                    return encode_json( {
                        'id'      => $id,
                        'content' => $repo->retrieve_content($id),
                    } );
                };

                get '/location' => with_types [
                    [ 'query', 'id', 'Str', 'MissingID' ],
                ] => sub {
                    my $id   = query_parameters->get('id');
                    my $file = $repo->retrieve_location($id);

                    # This is already anchored to the repo
                    # (And no user input can change the path it will reach)
                    send_file( $file, 'system_path' => 1 );
                };
            };

            prefix '/store' => sub {
                # There is no body to check, because the body is JSON content
                # So we manually decode and check
                post '/content' => sub {
                    my $data    = decode_json( request->body );
                    my $id      = $data->{'id'};
                    my $content = $data->{'content'};

                    defined && length
                        or send_error( 'Bad input', 400 )
                        for $id, $content;

                    $repo->store_content( $id, $content );
                    return encode_json( { 'success' => 1 } );
                };

                post '/location' => with_types [
                    [ 'query', 'id', 'Str',  'MissingID' ],
                ] => sub {
                    my $id   = query_parameters->get('id');
                    my $file = Path::Tiny->tempfile;
                    $file->spew_raw( request->body );
                    $repo->store_location( $id, $file );
                    return encode_json( { 'success' => 1 } );
                };
            };

            prefix '/remove' => sub {
                get '/location' => with_types [
                    [ 'query', 'id', 'Str',  'MissingID' ],
                ] => sub {
                    my $id = query_parameters->get('id');
                    $repo->remove_location( $id );
                    return encode_json( { 'success' => 1 } );
                };
            };
        };
    }
}

1;

__END__
