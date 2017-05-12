package DoumekiAir::Model::UploadedMemo;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;

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

sub ident {
    my $self = shift;
    my $param = +{ @_ };

    return join(',',
                map { $param->{$_} // 'UNKNOWN' } qw(filename size datetime)
            );
}

sub is_uploaded {
    my $self = shift;
    my $param = +{ @_ };

    my $rule = $self->c->validator(
        filename => { isa => 'Str' },
        size     => { isa => 'Str' },
        datetime => { isa => 'Str' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        critf 'failed to validate: %s', ddf($rule->clear_errors);
        return;
    }

    my $uploaded = $self->c->redis->key('uploaded');
    my $ident = $self->ident(%$param);

    my $v = $uploaded->hget($ident);

    debugf('already uploaded: %s', $ident) if $v;

    return $v ? 1 : ();
}

sub uploaded {
    my $self = shift;
    my $param = +{ @_ };

    my $rule = $self->c->validator(
        filename => { isa => 'Str' },
        size     => { isa => 'Str' },
        datetime => { isa => 'Str' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        critf 'failed to validate: %s', ddf($rule->clear_errors);
        return;
    }

    my $uploaded = $self->c->redis->key('uploaded');
    my $ident = $self->ident(%$param);

    my $v = $uploaded->hset($ident, time());

    return $v ? 1 : ();
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
