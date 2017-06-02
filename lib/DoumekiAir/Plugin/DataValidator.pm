package DoumekiAir::Plugin::DataValidator;

use strict;
use warnings;

use Data::Validator::Recursive;

sub init {
    my ($class, $context_class, $config) = @_;
    no strict 'refs';  ## no critic
    *{"$context_class\::validator"}     = \&_validator;
}

sub _validator {
    my ($self, %args) = @_;

    return Data::Validator::Recursive->new(%args);
}

1;
