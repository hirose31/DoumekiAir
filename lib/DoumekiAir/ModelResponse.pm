package DoumekiAir::ModelResponse;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Data::Validator;
use Data::Dumper;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(errors)],
    rw  => [qw(content)],
);

sub new {
    my($class, %args) = @_;

    my $self    =  bless {
        %args,
        content => undef,
        errors  => [],
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

    $self->content('validation failed');

    for my $e (@$errors) {
        $self->add_error({
            field   => $e->{name},
            code    => ($code_by_type->{ $e->{type} } // 'invalid'),
            message => $e->{message},
        });
    }
}

sub add_error {
    my($self, $error) = @_;

    my $rule    =  Data::Validator->new(
        field   => { isa => 'Str' },
        code    => { isa => 'Str' },
        message => { isa => 'Str', optional => 1 },
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

sub as_string {
    my($self) = @_;

    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Deepcopy  = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Useqq     = 1;
    local $Data::Dumper::Quotekeys = 0;
    my $d =  Dumper($_[0]);
    $d    =~ s/\\x\{([0-9a-z]+)\}/chr(hex($1))/ge;
    return $d;
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

=head1 STRUCTURE

    content => Any
      正常系の場合は任意の型のデータ
      異常系はエラーメッセージ:Str
    errors  => ArrayRef[ERROR]
    
    ERROR = {
      field   => エラー起因のパラメータやモデルの名前
      code    => missing | missing_field | invalid | already_exists | fatal
      message => Str (optional)
    }

=cut
