package DoumekiAir::Model::Store::Local;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use Path::Class;
use File::Basename;

use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c base_dir umask)]
);

sub new {
    my($class, %param) = @_;
    state $rule = $param{c}->validator(
        c        => { isa => 'DoumekiAir' },
        base_dir => { isa => 'Str' },
        umask    => { isa => 'Str', default => '0002' },
    )->with('Method');

    $rule->validate(@_);

    my $self = bless {
        %param,
    }, $class;

    return $self;
}

sub login {
    my($self) = @_;
    infof 'login %s', __PACKAGE__;
}

sub store {
    my($self, %param) = @_;
    infof 'store %s', __PACKAGE__;

    my $object = $param{object};

    CORE::umask oct($self->umask);

    my $datetime = $object->{shoot_datetime} || $object->{datetime};
    my $date = (split /\s+/, $datetime)[0];
    my $year = (split /-/, $date)[0];
    my $filename = basename($object->{filename});
    debugf 'datetime %s %s %s %s', $datetime, $date, $year, $filename;

    my $file = dir($self->base_dir, $year, $date)->file($filename);
    $file->dir->mkpath;
    infof 'write to %s', $file->stringify;
    $file->spew($object->{content});
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
