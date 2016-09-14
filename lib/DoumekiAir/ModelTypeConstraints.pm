package DoumekiAir::ModelTypeConstraints;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Mouse::Util::TypeConstraints;

subtype 'DAIPAddress'
    => as 'Str'
    => where { /\A(?:(?:2(?:5[0-5]|[0-4][0-9])|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}(?:2(?:5[0-5]|[0-4][0-9])|1[0-9]{2}|[1-9][0-9]|[0-9])\z/ }
    => message { 'Not IPv4 format' }
;

no Mouse::Util::TypeConstraints;

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
