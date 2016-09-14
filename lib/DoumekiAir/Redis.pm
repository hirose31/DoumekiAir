package DoumekiAir::Redis;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Log::Minimal;
use Redis;
use Redis::Namespace;
use Redis::Key;

use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(redis)],
    rw  => [qw()],
);

sub new {
    my($class, $conf) = @_;

    my $redis = Redis->new(%$conf)
        or croakf 'failed to create Redis instance: %s', ddf($conf);

    my $run_mode = $ENV{RUN_MODE} // 'development';
    my $namespace = join ':', $run_mode, 'doumekiair';
    my $ns = Redis::Namespace->new(
        redis     => $redis,
        namespace => $namespace,
    )
        or croakf 'failed to create Redis::Namespace: %s', $namespace;

    my $self = bless {
        redis => $ns,
    }, $class;

    return $self;
}

sub key {
    my($self, $kind, $param) = @_;

    my $key;
    if (!$param) {
        $key = $kind;
    } else {
        # DoumekiAir では今のところ使ってない
        my $ref = ref($param);
        if (!$ref) {
            $key = join ':', $kind, $param;
        } elsif ($ref eq 'HASH') {
            my @ke;
            for my $ke (qw(service hostname type)) {
                if ($param->{$ke}) {
                    push @ke, $param->{$ke};
                } else {
                    croakf 'missing argument: %s', $ke;
                }
            }
            $key = join ':', @ke;
        } else {
            croakf 'invalid argument: %s', ddf($param);
        }
    }

    debugf 'key: %s', $key;
    return Redis::Key->new(redis => $self->redis, key => $key);
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
