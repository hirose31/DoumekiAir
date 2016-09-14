package DoumekiAir::Util;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;

use parent qw(Exporter);
our @EXPORT = qw(p to_array);

use Data::Dumper;

sub p($) { ## no critic
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Deepcopy  = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Useqq     = 1;
    local $Data::Dumper::Quotekeys = 0;
    my $d =  Dumper($_[0]);
    $d    =~ s/\\x\{([0-9a-z]+)\}/chr(hex($1))/ge;
    print STDERR $d;
}

sub to_array {
    my $v = shift;
    my $type = ref $v;
    if (!$type) {
        return ($v);
    } elsif ($type eq 'ARRAY') {
        return @{$v};
    } else {
        croak "cannot convert to array: type=$type";
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
