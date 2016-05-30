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
