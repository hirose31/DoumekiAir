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
use Sub::Retry;
use Image::ExifTool;

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
    my $class = shift;
    my $param = +{ @_ };

    state $rule = $param->{c}->validator(
        id => { isa => 'Str' },
        c  => { isa => 'DoumekiAir' },
    )->with('NoRestricted');

    $param = $rule->validate($param);

    my $config = $param->{c}->config->{flashair}{ $param->{id} };
    unless (%$config) {
        croakf 'missing config for %s', $param->{id};
    }

    my $self = bless {
        %$param,
        %$config,
        ua => Furl->new(
            timeout => 200,
        ),
    }, $class;

    infof 'Model::FlashAir new: id=%s url=%s', $self->id, $self->url;

    return $self;
}

sub wakeup {
    my($self, $param) = @_;

    infof 'id: %s', $self->id;

    my $mres = DoumekiAir::ModelResponse->new;

    $mres = $self->c->model('Queue')->enqueue({
        queue       => 'wakeup',
        flashair_id => $self->id,
    });

    if ($mres->has_errors) {
        $mres->content({ status => 'error'});
    } else {
        $mres->content({ status => 'enqueue'});
    }

    return $mres;
}

sub filelist {
    my($self, $param) = @_;
    debugf 'filelist [%s]', $self->id;

    # state $rule = $self->c->validator(
    #
    # )->with('NoThrow');

    # $param = $rule->validate($param);

    my $mres = DoumekiAir::ModelResponse->new;
    # if ($rule->has_errors) {
    #     $mres->add_validator_errors($rule->clear_errors);
    #     return $mres;
    # }


    my @filelist;
    try {
        @filelist = $self->_fetch_filelist({dir => '/'});
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
    my($self, $param) = @_;

    state $rule = Data::Validator->new(
        dir => { isa => 'Str' },
    );

    $param = $rule->validate($param);

    my $url = sprintf("%s/command.cgi?op=100&DIR=%s",
                      $self->url,
                      $param->{dir},
                  );
    debugf 'url: %s', $url;
    my $res = retry 3, 1, sub {
        return $self->ua->get($url);
    }, sub {
        my $res = shift;

        if (!$res) {
            warnf 'RETRY not HTTP::Response: %s', $@;
            return 1;
        } elsif ($res->code =~ /^5/) {
            warnf 'RETRY %s', $res->status_line;
            return 1;
        }

        return;
    };
    if (!$res or !$res->is_success) {
        croakf "failed to get filelist: %s", $res->status_line;
    }
    debugf 'status_line: %s', $res->status_line;

    my @filelist;
    for my $line (split /\r?\n/, $res->decoded_content) {
        next if $line =~ /^WLANSD/;
        chomp $line;
        debugf 'filelist: %s', $line;
        my($dir,$name,$size,$attr,$date,$time) = split /,/, $line;

        if (is_dir($attr)) {
            push @filelist, $self->_fetch_filelist({dir => join('/', $dir, $name)});
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

sub fetch {
    my($self, $param) = @_;
    debugf 'fetch [%s]', $self->id;

    state $rule = $self->c->validator(
        fileinfo => { isa => 'HashRef' },
        callback => { isa => 'CodeRef' },
    )->with('NoThrow');

    $param = $rule->validate($param);

    my $mres = DoumekiAir::ModelResponse->new;
    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my $url = sprintf("%s%s",
                      $self->url,
                      $param->{fileinfo}{filename},
                  );
    debugf 'url: %s', $url;
    my $res = retry 8, 2, sub {
        return $self->ua->get($url);
    }, sub {
        my $res = shift;

        if (!$res) {
            warnf 'RETRY not HTTP::Response: %s', $@;
            return 1;
        } elsif ($res->code =~ /^5/) {
            warnf 'RETRY %s', $res->status_line;
            return 1;
        }

        return;
    };
    if (!$res or !$res->is_success) {
        my $msg = '999 unknown';
        if ($res) {
            $msg = $res->status_line;
        }
        $mres->add_error({
            field   => 'fetch',
            code    => 'error',
            message => $msg,
        });
        return $mres;
    }
    debugf 'status_line: %s', $res->status_line;

    my $object = {
        %{ $param->{fileinfo} },
        content        => $res->decoded_content,
        type           => $res->content_type,
        shoot_datetime => '',
    };
    if ($object->{type} eq 'image/jpeg') {
        my $exif = Image::ExifTool->ImageInfo(\$object->{content});
        if ($exif->{DateTimeOriginal}) {
            my($date, $time) = split /\s+/, $exif->{DateTimeOriginal};
            $object->{shoot_datetime} = sprintf '%04d-%02d-%02d %s', (split /[:\/-]/, $date), $time;
        }
    }

    $mres = $param->{callback}->($object);

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
