package DoumekiAir::Model::FlashAir;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use JSON qw(encode_json decode_json);

use DoumekiAir::ModelResponse;
use DoumekiAir::ModelTypeConstraints;
use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c id url)]
);

sub new {
    my($class, %args) = @_;
    # validate args? id, url

    my $self = bless {
        %args,
    }, $class;

    infof 'Model::FlashAir new: id=%s url=%s', $self->id, $self->url;

    return $self;
}

sub filelist {
    my($self, $param) = @_;
    debugf 'filelist [%s]', $self->id;

    my $mres = DoumekiAir::ModelResponse->new;

    my $rule = $self->c->validator(

    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }


    $mres->content();

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
