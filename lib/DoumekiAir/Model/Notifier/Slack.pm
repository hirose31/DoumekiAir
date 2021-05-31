package DoumekiAir::Model::Notifier::Slack;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use Sub::Retry;
use JSON;

use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c webhook_url channel)]
);

sub new {
    my $class = shift;
    my $param = +{ @_ };

    state $rule = $param->{c}->validator(
        c           => { isa => 'DoumekiAir' },
        webhook_url => { isa => 'Str' },
        channel     => { isa => 'Str' },
    )->with('NoRestricted');

    $param = $rule->validate($param);

    my $self = bless {
        %$param,
    }, $class;

    return $self;
}

sub notify {
    my($self, %param) = @_;
    infof 'notify %s', __PACKAGE__;

    my $res = retry 3, 1, sub {
        return $self->c->ua->post(
            $self->webhook_url,
            [],
            [
                'payload' => encode_json({
                    username   => 'DoumekiAir',
                    channel    => $self->channel,
                    text       => $param{message},
                    icon_emoji => ':frame_with_picture:',
                    link_names => 1,
                    # attachments => [
                    #     {
                    #         color => '#88d066',
                    #         text => $param{message},
                    #         mrkdwn_in => [qw(pretext text fields)],
                    #     },
                    # ],
                }),
            ],
        );
    }, sub {
        my $res = shift;

        if (!$res) {
            warnf 'RETRY not HTTP::Response: %s', $@;
            return 1;
        } elsif ($res->code =~ /^5/) {
            warnf 'RETRY %s', $res->status_line;
            return 1;
        }

        return;
    };

    if (!$res or !$res->is_success) {
        warnf 'failed to post message w/ Slack: %s', ($res ? $res->status_line : 'undef');
    }
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
