package DoumekiAir::Model::Store::Picasa;

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

        # all, private, public, visible, protected と思ったけど
        # public private しかなくなった？
        # https://developers.google.com/picasa-web/docs/2.0/reference#gphoto_reference
        # の gphoto:access
        # でも private だと「共有中」って表示されるので protected にする。
        album_access => { isa => 'Str', default => 'protected' },
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
        scope         => ['https://picasaweb.google.com/data/', 'https://www.googleapis.com/auth/drive'],
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
            'Authorization' => sprintf('OAuth %s', $self->access_token),
            'GData-Version' => 3,
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

    my $upload_uri = $self->upload_uri($date);
    if (!$upload_uri) {
        $upload_uri = 'https://picasaweb.google.com/data/feed/api/user/default';
    }
    debugf 'upload_uri: %s', $upload_uri;

    my $res = retry 3, 1, sub {
        return $self->ua->post($upload_uri,
                               [
                                   'Content-Type'  => 'image/jpg',
                                   'Slug'          => $filename,
                               ],
                               $object->{content},
                           );
    }, sub {
        my $res = shift;
        (defined $res and $res->is_success) ? 0 : 1;
    };
    if ($res and $res->is_success) {
        infof 'uploaded: %s/%s', $date, $filename;
        return 1;
    } else {
        critf 'failed to upload: %s %s', $res->status_line, $res->decoded_content;
        return;
    }
}

sub _build_album_list {
    my($self) = @_;

    my $album_list = {};

    my $res = retry 3, 1, sub {
        return $self->ua->get('https://picasaweb.google.com/data/feed/api/user/default');
    }, sub {
        my $res = shift;
        (defined $res and $res->is_success) ? 0 : 1;
    };
    if (!$res or !$res->is_success) {
        croak "failed to get album list: $!: ".$res->code.' '.$res->content;
    }

    my $dom = XML::LibXML->load_xml(string => $res->content);
    my $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs('atom','http://www.w3.org/2005/Atom');

    my $nodes = $xpc->findnodes('//atom:entry');
    #debugf 'nodes: %s', $nodes->size;
    for my $node ($nodes->get_nodelist) {
        my $title_node = $node->getElementsByTagName('title')->get_node(1);
        my $albumname = $title_node->textContent;
        utf8::encode($albumname);
        #debugf 'album name: %s', $albumname;

        my @links = $node->getElementsByTagName('link')->get_nodelist;
        for my $link (@links) {
            if ($link->getAttribute('rel') eq 'http://schemas.google.com/g/2005#feed') {
                #debugf 'found: %s', $link->getAttribute('href');
                $album_list->{ $albumname } = $link->getAttribute('href');
                last;
            }
        }
    }

    $self->{album_list} = $album_list;
}

sub upload_uri {
    my($self, $date) = @_;

    my($albumname) = $date =~ /^(\d\d\d\d)/;

    my $upload_uri = $self->album_list->{$albumname} || "";

    return $upload_uri;
}

1;

__END__

# for Emacsen
# Picasa Variables:
# mode: cperl
# cperl-indent-level: 4
# cperl-close-paren-offset: -4
# cperl-indent-parens-as-block: t
# indent-tabs-mode: nil
# coding: utf-8
# End:

# vi: set ts=4 sw=4 sts=0 et ft=perl fenc=utf-8 ff=unix :
