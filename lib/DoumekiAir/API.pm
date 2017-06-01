package DoumekiAir::API;

use strict;
use warnings;
use 5.010_000;
use utf8;

use parent qw/DoumekiAir Amon2::Web/;

use File::Spec;
use Log::Minimal;
use JSON 2 qw(encode_json decode_json);
use Try::Tiny;
use Encode;

# dispatcher
use DoumekiAir::API::Dispatcher;
sub dispatch {
    return (DoumekiAir::API::Dispatcher->dispatch($_[0]) or die "response is not generated");
}

# load plugins
__PACKAGE__->load_plugins(
    '+DoumekiAir::Plugin::Web::Session',
    '+DoumekiAir::Plugin::Web::JSON',
);

# setup view
use DoumekiAir::API::View;
{
    sub create_view {
        my $view = DoumekiAir::API::View->make_instance(__PACKAGE__);
        no warnings 'redefine';
        *DoumekiAir::API::create_view = sub { $view }; # Class cache.
        $view
    }
}

# for your security
__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my($c) = @_;

        my $ua = $c->req->user_agent;
        debugf 'ua: %s', $ua // '';

        ### 特定の UA の場合はここで処理できる。
        ### 古いバージョンのだったらエラーを返すとか。
        # if ($ua =~ /^Furl/) {
        #     my $res = $c->render_json({message => 'yyyyyyyyay!'});
        #     return $res;
        # }
    },
    AFTER_DISPATCH  => sub {
        my($c, $res) = @_;

        # http://blogs.msdn.com/b/ie/archive/2008/07/02/ie8-security-part-v-comprehensive-protection.aspx
        $res->header( 'X-Content-Type-Options' => 'nosniff' );

        # http://blog.mozilla.com/security/2010/09/08/x-frame-options/
        $res->header( 'X-Frame-Options' => 'DENY' );

        # Cache control.
        $res->header( 'Cache-Control' => 'private' );
    },
);

sub parse_json_qs_request {
    my $c = shift;

    my $req = $c->req;

    my $param = {};

    if ($req->content_type and lc($req->content_type) eq 'application/json') {
        my $content = $req->content || '{}';
        $param = try {
            decode_json($content);
        } catch {
            warnf("%s: %s", $_, $content);
            return;
        };
        return unless $param;
    } else {
        my @keys = $req->param;
        for my $key (@keys) {
            next if $key eq 'pretty';
            my $val = $req->param($key);
            if ($val =~ /^[[{]/) {
                $val = try {
                    decode_json($val);
                } catch {
                    warnf("%s: %s", $_, $val);
                    return;
                };
                return unless $val;
            }
            my $pkey = $key;
            $pkey =~ s/\[[0-9]+\]$//;
            if ($param->{$pkey}) {
                if (ref($param->{$pkey}) ne 'ARRAY') {
                    $param->{$pkey} = [$param->{$pkey}];
                }
                push @{ $param->{$pkey} }, $val;
            } else {
                $param->{$pkey} = $val;
            }
        }
    }

    $ENV{JSON_PRETTY} = defined $req->param('pretty') ? 1 : 0;

    return $param;
}

sub parse_json_request {
    my $c = shift;

    my $req = $c->req;

    my $content = $req->content || '{}';
    my $param = try {
        decode_json($content);
    } catch {
        warnf("%s: %s", $_, $content);
        return;
    };

    return $param || ();
}

sub show_mres_error {
    my($c, $mres) = @_;

    my $message = $mres->content // 'internal server error';

    if ($message eq 'validation failed') {
        return $c->show_bad_request($message, $mres->errors);
    } else {
        return $c->show_internal_server_error($message, $mres->errors);
    }
}

sub show_internal_server_error {
    my($c, $message, $errors) = @_;
    return $c->show_error(500, $message, $errors);
}

sub show_bad_request {
    my($c, $message, $errors) = @_;
    return $c->show_error(400, $message, $errors);
}

sub show_missing_mandatory_parameter {
    my($c, undef, $errors) = @_;
    return $c->show_error(400, 'missing mandatory parameter', $errors);
}

sub show_not_found {
    my($c, undef, $errors) = @_;
    return $c->show_error(404, 'not found', $errors);
}

sub show_error {
    my($c, $code, $message, $errors) = @_;

    $code //= 500;

    if ($code =~ /^5/) {
        critf '%s %s', $message, ddf($errors);
    } else {
        warnf '%s %s', $message, ddf($errors);
    }

    my $res = $c->render_json({message => $message, errors => $errors // []});
    $res->code($code);
    return $res;
}

1;
