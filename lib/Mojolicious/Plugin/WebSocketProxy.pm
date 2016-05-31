package Mojolicious::Plugin::WebSocketProxy;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::WebSocketProxy::Dispatcher::Config;
use Mojo::WebSocketProxy::Dispatcher;

sub register {
    my ($self, $app, $config) = @_;

    my $url_getter;
    $url_getter = delete $config->{url} if $config->{url} and ref($config->{url}) eq 'CODE';
    $app->helper(
        call_rpc => sub {
            my ($c, $req_storage) = @_;
            $url_getter->($c, $req_storage) if $url_getter && !$req_storage->{url};
            return $c->forward($req_storage);
        });

    my $r = $app->routes;
    for ($r->under($config->{base_path})) {
        $_->to('Dispatcher#ok', namespace => 'Mojo::WebSocketProxy');
        $_->websocket('/')->to('Dispatcher#open_connection', namespace => 'Mojo::WebSocketProxy');
    }

    my $actions           = delete $config->{actions};
    my $dispatcher_config = Mojo::WebSocketProxy::Dispatcher::Config->new;
    $dispatcher_config->init($config);

    if (ref $actions eq 'ARRAY') {
        for (my $i = 0; $i < @$actions; $i++) {
            $dispatcher_config->add_action($actions->[$i], $i);
        }
    } else {
        Carp::confess 'No actions found!';
    }

    return;
}

1;

__END__

=head1 NAME

Mojo::WebSocketProxy::Dispatcher

=head1 SYNOPSYS
    
    # lib/your-application.pm
 
    use base 'Mojolicious';
 
    sub startup {
        my $self = shift;
        $self->plugin(
            'web_socket_proxy' => {
                actions => [
                    ['json_key', {some_param => 'some_value'}]
                ],
                base_path => '/api',
                url => 'http://rpc-host.com:8080/',
            }
        );
   }

Or to manually call RPC server:
    
    # lib/your-application.pm
 
    use base 'Mojolicious';
 
    sub startup {
        my $self = shift;
        $self->plugin(
            'web_socket_proxy' => {
                actions => [
                    [
                        'json_key', 
                        {
                            instead_of_forward => sub {
                                shift->call_rpc({  
                                    args => $args,
                                    method => $rpc_method, # it'll call 'http://rpc-host.com:8080/rpc_method'
                                    rpc_response_cb => sub {...}
                                });
                            }
                        }
                    ]
                ],
                base_path => '/api',
                url => 'http://rpc-host.com:8080/',
            }
        );
   }

=head1 DESCRIPTION

Using this module you can forward websocket JSON-RPC 2.0 requests to RPC server.

The plugin understands the following parameters.

=over

=item B<actions> (mandatory)

A pointer to array of action details, which contain stash_params, 
request-response callbacks, other call parameters.

    $self->plugin(
        'web_socket_proxy' => {
            actions => [ 
                ['action1_json_key', {details_key1 => details_value1}],
                ['action2_json_key']
            ]
        });
        
=item B<before_forward> (optional)

    before_forward => [sub { my ($c, $req_storage) = @_; ... }, sub {...}]

Global hooks which will run after request is dispatched and before to start preparing RPC call.
It'll run every hook or until any hook returns some non-empty result.
If returns any hash ref then that value will be JSON encoded and send to client,
without forward action to RPC. To call RPC every hook should return empty or undefined value.
It's good place to some validation or subscribe actions.
        
=item B<after_forward> (optional)
    
    after_forward => [sub { my ($c, $result, $req_storage) = @_; ... }, sub {...}]

Global hooks which will run after every forwarded RPC call done.
Or even forward action isn't running.
It can view or modify result value from 'before_forward' hook.
It'll run every hook or until any hook returns some non-empty result.
If returns any hash ref then that value will be JSON encoded and send to client.

=item B<after_dispatch> (optional)

    after_dispatch => [sub { my $c = shift; ... }, sub {...}]
    
Global hooks which will run at the end of request handling.

=item B<before_get_rpc_response> (optional)

    before_get_rpc_response => [sub { my ($c, $req_storage) = @_; ... }, sub {...}]

Global hooks which will run when asynchronous RPC call is answered.

=item B<after_got_rpc_response> (optional)

    after_got_rpc_response => [sub { my ($c, $req_storage) = @_; ... }, sub {...}]

Global hooks which will run after checked that response exists.

=item B<before_send_api_response> (optional)

    before_send_api_response => [sub { my ($c, $req_storage, $api_response) = @_; ... }, sub {...}]

Global hooks which will run immediately before send API response.

=item B<after_sent_api_response> (optional)

    before_send_api_response => [sub { my ($c, $req_storage) = @_; ... }, sub {...}]

Global hooks which will run immediately after sent API response.





=item B<success> (optional)

    success => sub { my ($c, $rpc_response) = @_; ... }
    
Hook which will run if RPC returns success value.

=item B<error> (optional)

    error => sub { my ($c, $rpc_response) = @_; ... }
    
Hook which will run if RPC returns value with error key, e.g. 
{ result => { error => { code => 'some_error' } } }

=item B<response> (optional)

    response => sub { my ($c, $rpc_response) = @_; ... }
    
Hook which will run every time when success or error callbacks is running.
It good place to modify API response format.






            # main config
            base_path         => '/websockets/v3',
            stream_timeout    => 120,
            max_connections   => 100000,
            opened_connection => \&BOM::WebSocketAPI::Hooks::init_redis_connections,
            finish_connection => \&BOM::WebSocketAPI::Hooks::forget_all,

            # helper config
            url =>

        
=back

=head1 METHODS

=head2 open_connection

Run while openning new wss connection.
Run hook when connection is opened.
Set finish connection callback.

=head2 on_message

Handle message - parse and dispatch request messages.
Dispatching action and forward to RPC server.

=head2 before_forward

Run hooks.

=head2 after_forward

Run hooks.

=head2 dispatch

Dispatch request using message json key.

=head2 forward

Forward call to RPC server using global and action hooks.
Don't forward call to RPC if any before_forward hook returns response.
Or if there is instead_of_forward action.

=head2 send_api_response

Send asynchronous response to client websocket, doing hooks.

=cut
