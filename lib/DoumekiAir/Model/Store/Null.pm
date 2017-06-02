package DoumekiAir::Model::Store::Null;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;

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
    }, $class;

    return $self;
}

sub login {
    my($self) = @_;
    infof 'login %s', __PACKAGE__;
}

sub store {
    my($self) = @_;
    infof 'store %s', __PACKAGE__;
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
