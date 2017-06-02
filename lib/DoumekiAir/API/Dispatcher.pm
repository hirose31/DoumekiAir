package DoumekiAir::API::Dispatcher;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use JSON 2 qw(encode_json decode_json);
use Try::Tiny;
use HTTP::Status;

use Amon2::Web::Dispatcher::RouterBoom;

use DoumekiAir;
use DoumekiAir::Util;

any '/' => sub {
    my ($c) = @_;
    my $counter = $c->session->get('counter') || 0;
    $counter++;
    $c->session->set('counter' => $counter);
    return $c->render('index.tx', {
        counter => $counter,
    });
};

{
    no warnings 'redefine';
    package
        HTTP::Status;
    *status_message_orig = \&status_message;
    *status_message = sub ($) {
        +{
            599 => 'Under Maintenance',
        }->{$_[0]} || status_message_orig($_[0]);
    }
}

get '/_chk' => sub {
    my $c = shift;

    my($status, $body);

    if ($c->config->{maintenance_file} && -e $c->config->{maintenance_file}) {
        $status = 599;
        $body   = 'MAINTAIN';
    } else {
        $status = 200;
        $body   = 'OK';
    }

    return $c->create_response(
        $status,
        [
            'Content-Type'   => 'text/plain',
            'Content-Length' => length($body)
        ],
        $body,
    );
};

get '/status' => sub {
    my $c = shift;

    my $body = "";

    $body .= sprintf "DoumekiAir-API/%s\n", $DoumekiAir::VERSION;

    return $c->create_response(
        200,
        [
            'Content-Type'   => 'text/plain',
            'Content-Length' => length($body)
        ],
        $body,
    );
};

############################################################################

# capability
get '/v1/capability' => sub {
    my($c, $args) = @_;

    # DoumekiAir::APIのBEFORE_DISPATCHでやった方がいいかなぁ
    # でも将来的に v1 は 1.0 以上、v2 は 2.0 以上、とか API version に
    # よって変えたくなるかもだしここでやる。

    my $require_version = '1.0';
    my $content = {
        message => 'OK',
    };

    my $ua = $c->req->user_agent;
    if ($ua =~ m{\ADoumekiAir/([0-9]+\.[0-9]+)\z}) {
        my $client_version = $1;
        debugf 'its DoumekiAir client v%s', $client_version;
        if ($client_version < $require_version) {
            $content->{message} = sprintf 'client version must be %s or later', $require_version;
        }
    } else {
        $content->{message} = 'not looks like DoumekiAir client program';
    }

    return $c->render_json($content);
};

### users ##################################################################
get '/wakeup/:flashair_id' => sub {
    my($c, $args) = @_;

    my $mres = $c->model('FlashAir', { id => $args->{flashair_id} })->wakeup;

    return $mres->has_errors
        ? $c->show_mres_error($mres)
        : $c->render_json($mres->content);
};

1;
