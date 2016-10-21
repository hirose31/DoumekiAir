package DoumekiAir::Model::FlashAir;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use JSON qw(encode_json decode_json);
use Furl;
use Try::Tiny;

use DoumekiAir::ModelResponse;
use DoumekiAir::ModelTypeConstraints;
use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c id url ua)]
);

my $F_READONLY  = 1 << 0;
my $F_HIDDEN    = 1 << 1;
my $F_SYSTEM    = 1 << 2;
my $F_VOLUME    = 1 << 3;
my $F_DIRECTORY = 1 << 4;
my $F_ARCHIVE   = 1 << 5;

my $MASK_DAY  = 0x001F;
my $MASK_MON  = 0x01E0;
my $MASK_YEAR = 0xFE00;

my $MASK_SEC  = 0x001F;
my $MASK_MIN  = 0x07E0;
my $MASK_HOUR = 0xF800;

sub new {
    my($class, %param) = @_;
    state $rule = $param{c}->validator(
        id => { isa => 'Str' },
        c  => { isa => 'DoumekiAir' },
    )->with('Method');

    $rule->validate(@_);

    my $config = $param{c}->config->{flashair}{ $param{id} };
    unless (%$config) {
        croakf 'missing config for %s', $param{id};
    }

    my $self = bless {
        %param,
        %$config,
        ua => Furl->new(
            timeout => 16,
        ),
    }, $class;

    infof 'Model::FlashAir new: id=%s url=%s', $self->id, $self->url;

    return $self;
}

sub filelist {
    my $self = shift;
    debugf 'filelist [%s]', $self->id;

    state $rule = $self->c->validator(

    )->with('NoThrow');

    my $param = $rule->validate(@_);

    my $mres = DoumekiAir::ModelResponse->new;
    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }


    my @filelist;
    try {
        @filelist = $self->_fetch_filelist(dir => '/');
    } catch {
        $mres->add_error({
            field   => 'fetch_filelist',
            code    => 'error',
            message => $_,
        });
        return $mres;
    };

    $mres->content(\@filelist);

    return $mres;
}

sub _fetch_filelist {
    my $self = shift;

    state $rule = Data::Validator->new(
        dir => { isa => 'Str' },
    );

    my $param = $rule->validate(@_);

    my $url = sprintf("%s/command.cgi?op=100&DIR=%s",
                      $self->url,
                      $param->{dir},
                  );
    debugf 'url: %s', $url;
    my $res = $self->ua->get($url);
    debugf 'status_line: %s', $res->status_line;
    if (!$res->is_success) {
        croakf "failed to get filelist: %s", $res->status_line;
    }

    my @filelist;
    for my $line (split /\r?\n/, $res->decoded_content) {
        next if $line =~ /^WLANSD/;
        chomp $line;
        debugf 'filelist: %s', $line;
        my($dir,$name,$size,$attr,$date,$time) = split /,/, $line;

        if (is_dir($attr)) {
            push @filelist, $self->_fetch_filelist(dir => join('/', $dir, $name));
        } else {
            if ($size <= 0) {
                debugf 'SKIP %s: size is 0', $name;
                next;
            }

            my $day  = ($date & $MASK_DAY);
            my $mon  = ($date & $MASK_MON) >> 5;
            my $year = ($date % $MASK_YEAR) >> 9;
            $year += 1980;

            my $sec  = ($time & $MASK_SEC);
            my $min  = ($time & $MASK_MIN) >> 5;
            my $hour = ($time & $MASK_HOUR) >> 11;

            my $datetime = sprintf '%04d-%02d-%02d %02d:%02d:%02d', $year, $mon, $day, $hour, $min, $sec;

            push @filelist, {
                filename => join('/', $dir, $name),
                size     => $size,
                datetime => $datetime,
            };
        }
    }

    return @filelist;
}

sub is_readonly {
    my $attr = shift;

    return ($attr & $F_READONLY) ? 1 : ();
}

sub is_hidden {
    my $attr = shift;

    return ($attr & $F_HIDDEN) ? 1 : ();
}
sub is_system {
    my $attr = shift;

    return ($attr & $F_SYSTEM) ? 1 : ();
}

sub is_volume {
    my $attr = shift;

    return ($attr & $F_VOLUME) ? 1 : ();
}

sub is_dir {
    my $attr = shift;

    return ($attr & $F_DIRECTORY) ? 1 : ();
}

sub is_archive {
    my $attr = shift;

    return ($attr & $F_ARCHIVE) ? 1 : ();
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
