package DoumekiAir::Model::Store::GooglePhotos;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use Path::Class;
use File::Basename;
use XML::LibXML;
use Net::Google::DataAPI::Auth::OAuth2;
use Furl;
use Sub::Retry;
use JSON qw(encode_json decode_json);

use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c ua client_id client_secret refresh_token album_list album_access)],
    rw  => [qw(access_token)]
);

sub new {
    my $class = shift;
    my $param = +{ @_ };

    state $rule = $param->{c}->validator(
        c             => { isa => 'DoumekiAir' },
        client_id     => { isa => 'Str' },
        client_secret => { isa => 'Str' },
        refresh_token => { isa => 'Str' },
    )->with('NoRestricted');

    $param = $rule->validate($param);

    my $self = bless {
        %$param,
        ua           => '', # set in login
        access_token => '',
        album_list   => {},
    }, $class;

    return $self;
}

sub login {
    my($self) = @_;
    infof 'login %s', __PACKAGE__;

    my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
        client_id     => $self->client_id,
        client_secret => $self->client_secret,
        scope         => [
'https://www.googleapis.com/auth/photoslibrary',
'https://www.googleapis.com/auth/photoslibrary.readonly',
'https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata',
],
    );
    my $ow = $oauth2->oauth2_webserver;
    my $token = Net::OAuth2::AccessToken->new(
        profile       => $ow,
        auto_refresh  => 1,
        refresh_token => $self->refresh_token,
    );
    $ow->update_access_token($token);
    $token->refresh;
    $oauth2->access_token($token);
    $self->access_token($token->access_token);

    $self->{ua} = Furl->new(
        headers => [
            'Authorization' => sprintf('Bearer %s', $self->access_token),
        ],
        timeout => 60,
    );

    $self->_build_album_list;

    return 1;
}

sub store {
    my($self, %param) = @_;
    infof 'store %s', __PACKAGE__;

    my $object = $param{object};

    my $datetime = $object->{shoot_datetime} || $object->{datetime};
    my $date = (split /\s+/, $datetime)[0];
    my $filename = basename($object->{filename});
    debugf 'datetime %s %s %s', $datetime, $date, $filename;

    my $url = 'https://photoslibrary.googleapis.com/v1/uploads';
    my $res;


    # upload media
    $res = retry 3, 1, sub {
        return $self->ua->post($url,
                               [
                                   'Content-Type' => 'application/octet-stream',
                                   'X-Goog-Upload-File-Name' => $filename,
                                   'X-Goog-Upload-Protocol' => 'raw',
                               ],
                               $object->{content},
                           );
    }, sub {
        my $res = shift;
        (defined $res and $res->is_success) ? 0 : 1;
    };
    if (!$res or !$res->is_success) {
        if ($res) {
            croak "failed to upload media: $!: ".$res->code.' '.$res->content;
        } else {
            croakf("failed to upload media: $!: %s", ddf($res));
        }
    }

    infof 'uploaded: %s/%s', $date, $filename;

    my $upload_token = $res->decoded_content;


    # create album if does not exist
    if (! exists $self->{album_list}{$date}) {
        $self->_create_album($date);
    }

    my $album_id = $self->{album_list}{$date};
    if (! $album_id) {
        croakf 'missing album_id for %s', $date;
    }


    # create media
    $url = 'https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate';
    $res = retry 3, 1, sub {
        return $self->ua->post($url,
                               [
                                   'Content-Type' => 'application/json',
                               ],
                               encode_json({
                                   albumId => $album_id,
                                   newMediaItems => [
                                       {
                                           description => '',
                                           simpleMediaItem => {
                                               uploadToken => $upload_token,
                                           },
                                       },
                                   ],
                               }),
                           );
    }, sub {
        my $res = shift;
        (defined $res and $res->is_success) ? 0 : 1;
    };
    if (!$res or !$res->is_success) {
        if ($res) {
            croak "failed to create media: $!: ".$res->code.' '.$res->content;
        } else {
            croakf("failed to create media: $!: %s", ddf($res));
        }
    }

    my $body = decode_json($res->decoded_content);

    infof 'successfully create media: %s', ddf($body);

    return 1;
}

sub _build_album_list {
    my($self) = @_;

    # if (-f '/tmp/albums.json') {
    #     infof 'read albums cache';
    #     open my $fh, '<', '/tmp/albums.json' or die $!;
    #     my $buf = do { local $/; <$fh> };
    #     close $fh;

    #     $self->{album_list} = decode_json($buf);
    #     return;
    # }

    my $album_list = {};

    my $next_page_token = '';

    for my $i (1..30) {
        infof 'fetch album %d', $i;
        my $res = retry 3, 1, sub {
            my $url = 'https://photoslibrary.googleapis.com/v1/albums?pageSize=50';
            if ($next_page_token) {
                $url .= "&pageToken=${next_page_token}";
            }
            debugf "url: %s", $url;

            return $self->ua->get($url);
        }, sub {
            my $res = shift;
            (defined $res and $res->is_success) ? 0 : 1;
        };
        if (!$res or !$res->is_success) {
            if ($res) {
                croak "failed to get album list: $!: ".$res->code.' '.$res->content;
            } else {
                croakf("failed to get album list: $!: %s", ddf($res));
            }
        }
        my $body = decode_json($res->decoded_content);
        for my $album (@{ $body->{albums} }) {
            my $album_title = $album->{title};
            $album_list->{$album_title} = $album->{id};
        }

        $next_page_token = $body->{nextPageToken};
        last unless $next_page_token;
    }

    infof 'fetch %d albums', scalar(keys %$album_list);

    # fixme for cache in develop
    # open my $fh, '>', '/tmp/albums.json' or die $!;
    # print {$fh} encode_json($album_list);
    # close $fh;

    $self->{album_list} = $album_list;
}

sub _create_album {
    my($self, $title) = @_;

    infof 'create album: %s', $title;

    my $url = 'https://photoslibrary.googleapis.com/v1/albums';
    my $res = retry 3, 1, sub {
        return $self->ua->post($url,
                               [
                                   'Content-Type' => 'application/json',
                               ],
                               encode_json({
                                   album => {
                                       title => $title,
                                   },
                               }),
                           );
    }, sub {
        my $res = shift;
        (defined $res and $res->is_success) ? 0 : 1;
    };
    if (!$res or !$res->is_success) {
        if ($res) {
            croak "failed to create album: $!: ".$res->code.' '.$res->content;
        } else {
            croakf("failed to create album: $!: %s", ddf($res));
        }
    }

    my $body = decode_json($res->decoded_content);
    my $album_id = $body->{id};

    infof 'successfully created album %s <%s>', $title, $album_id;
    $self->{album_list}{$title} = $album_id;

    return 1;
}

1;

__END__

# for Emacsen
# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# cperl-close-paren-offset: -4
# cperl-indent-parens-as-block: t
# indent-tabs-mode: nil
# coding: utf-8
# End:

# vi: set ts=4 sw=4 sts=0 et ft=perl fenc=utf-8 ff=unix :
