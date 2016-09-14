package DoumekiAir::Model::Queue;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use JSON qw(encode_json decode_json);
use UNIVERSAL::require;

use DoumekiAir::ModelResponse;
use DoumekiAir::ModelTypeConstraints;
use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c)]
);

sub new {
    my($class, %args) = @_;
    return bless \%args, $class;
}

sub enqueue {
    my($self, $param) = @_;

    my $mres = DoumekiAir::ModelResponse->new;

    my $rule = $self->c->validator(
        queue => { isa => 'Str' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    croak 'not implemented';
    # my $queue  = $self->c->redis->key('queue' => $param);

    # ### begin transaction
    # $task->multi;

    # # queue
    # $queue->rpush(encode_json(\%task_data));

    # ### commit transaction
    # $task->exec;

    # $mres = $self->status({
    #     service  => $param->{service},
    #     hostname => $param->{hostname},
    #     type     => $param->{type},
    # });
    # if ($mres->has_errors) {
    #     $mres->add_error({
    #         message => "failed to get task info for $key",
    #         field   => 'task',
    #         code    => 'invalid',
    #     });
    #     return $mres;
    # }

    # return $mres;
}

sub dequeue {
    my($self, $param) = @_;

    my $mres = DoumekiAir::ModelResponse->new;

    my $rule = $self->c->validator(
        queue   => { isa => 'Str' },
        timeout => { isa => 'Int', default => 0 },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my $queue = $self->c->redis->key($param->{queue});
    my $job_raw = $queue->blpop($param->{timeout});
    debugf 'job: %s', ddf($job_raw // 'UNDEFINED');
    my $job = '';
    if (defined $job_raw) {
        $job = $job_raw->[1];
    }

    $mres->content($job);

    return $mres;
}

sub check {
    my($self, $param) = @_;

    my $mres = DoumekiAir::ModelResponse->new;

    my $task = $self->concrete_task($param->{type});

    $mres = $task->check($param);

    return $mres;
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
