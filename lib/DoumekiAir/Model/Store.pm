package DoumekiAir::Model::Store;

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
        store => [],
    }, $class;

    $self->load();

    return $self;
}

sub load {
    my($self) = @_;

    my $config = $self->c->config->{store};
    infof 'initialize sotres';

    for my $klass (keys %$config) {
        my $module = "DoumekiAir::Model::Store::${klass}";
        infof 'loading %s', $module;
        $module->require;
        push @{ $self->{store} }, $module->new(
            %{ $config->{$klass} },
            c => $self->c,
        );
    }
}

sub login {
    my($self) = @_;

    for my $store (@{ $self->{store} }) {
        $store->login();
    }
}

sub store {
    my($self, $param) = @_;

    my $mres = DoumekiAir::ModelResponse->new;

    my $rule = $self->c->validator(
        object => { isa => 'HashRef' },
    )->with('NoThrow');

    $param = $rule->validate($param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my $object = $param->{object};
    infof 'store: [%s] %s (%d) %s / %s', @{$object}{qw(type filename size datetime)}, $object->{shoot_datetime};

    for my $store (@{ $self->{store} }) {
        $store->store(object => $object);
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
