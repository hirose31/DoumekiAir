package DoumekiAir::ModelResponse;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Data::Validator;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(errors)],
    rw  => [qw(content)],
);

sub new {
    my($class, %args) = @_;

    my $self = bless {
        %args,
        content  => undef,
        errors   => [],
    }, $class;

    return $self;
}

sub has_errors {
    my $self = shift;
    return scalar(@{$self->errors}) == 0 ? 0 : 1;
}

sub add_validator_errors {
    my($self, $errors) = @_;

    state $code_by_type = {
        InvalidValue       => 'invalid',
        ExclusiveParameter => 'invalid',
        MissingParameter   => 'missing_field',
        UnknownParameter   => 'invalid',
    };

    for my $e (@$errors) {
        $self->add_error({
            field    => $e->{name},
            code     => ($code_by_type->{ $e->{type} } // 'invalid'),
            message  => $e->{message},
        });
    }
}

sub add_error {
    my($self, $error) = @_;

    my $rule = Data::Validator->new(
        field    => { isa => 'Str' },
        code     => { isa => 'Str' },
        message  => { isa => 'Str', optional => 1 },
    )->with('NoThrow');

    $error = $rule->validate(%$error);

    if ($rule->has_errors) {
        warn join("\n", map {$_->{message}} @{$rule->clear_errors});
        push @{ $self->{errors} }, {
            field => 'unknown',
            code  => 'unknown',
        };
    } else {
        push @{ $self->{errors} }, $error;
    }
}

1;

__END__

=encoding utf8

=head1 NAME

B<DoumekiAir::ModelResponse> - ...

=head1 SYNOPSIS

    use DoumekiAir::ModelResponse;

=head1 DESCRIPTION

モデルのレスポンスクラス。

全てのモデルの全ての返り値に使うわけじゃなくて、パラメータのバリデーションや実行結果が失敗する可能性があるものにのみ使う。

具体的には、リソース（Hostとか）のCRUD（insertとか）。

なので、例えばTagモデルのidやnameメソッドの返り値には使わない。

別な言い方をすると、コントローラがモデルのエラーの詳細を知りたい局面では ModelResponse を返るが、モデルのユーティリティメソッドには使わない。

=cut
