package DoumekiAir::Model::Notifier;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use UNIVERSAL::require;

use DoumekiAir::ModelResponse;
use DoumekiAir::ModelTypeConstraints;
use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c)]
);

sub new {
    my $class = shift;
    my $param = +{ @_ };

    state $rule = $param->{c}->validator(
        c  => { isa => 'DoumekiAir' },
    )->with('NoRestricted');

    $param = $rule->validate($param);

    my $self = bless {
        %$param,
        notifier => [],
    }, $class;

    $self->load();

    return $self;
}

sub load {
    my($self) = @_;

    my $config = $self->c->config->{notifier};
    infof 'initialize notifiers';

    for my $klass (keys %$config) {
        my $module = "DoumekiAir::Model::Notifier::${klass}";
        infof 'loading %s', $module;
        $module->require;
        push @{ $self->{notifier} }, $module->new(
            %{ $config->{$klass} },
            c => $self->c,
        );
    }
}

sub notify {
    my($self, $param) = @_;

    my $mres = DoumekiAir::ModelResponse->new;

    my $rule = $self->c->validator(
        message => { isa => 'Str' },
    )->with('NoThrow');

    $param = $rule->validate($param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    for my $notifier (@{ $self->{notifier} }) {
        $notifier->notify(%$param);
    }

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
