package DoumekiAir;

use strict;
use warnings;
use 5.010_000;
use utf8;

use version; our $VERSION = version->declare('v1.0.0');

use Amon2::Config::Simple;
use Log::Minimal;
use Path::Class;
use Furl;

use DoumekiAir::Redis;
use DoumekiAir::Util;

use parent qw/Amon2/;
# Enable project local mode.
__PACKAGE__->make_local_context();

__PACKAGE__->load_plugins(
    '+DoumekiAir::Plugin::Model',
    '+DoumekiAir::Plugin::DataValidator',
);

if ($ENV{RUN_MODE} && $ENV{RUN_MODE} eq 'development') {
    eval q!
      use DBIx::QueryLog;
      $ENV{LM_DEBUG} = 1;
      $DBIx::QueryLog::OUTPUT = sub {
        my %p = @_;
        debugf("%s", $p{message});
      };
    !;
    warnf($@) if $@;
}

sub load_config {
    my $c = shift;

    my $config = Amon2::Config::Simple->load($c, {
        environment => $c->mode_name || 'development',
    });

    if ($ENV{TEST_REDIS}) {
        # connect to Test::RedisServer
        $config->{redis} = {
            $ENV{TEST_REDIS} =~ m{^/} ? (sock => $ENV{TEST_REDIS}) : (server => $ENV{TEST_REDIS}),
        };
    }

    debugf 'config: %s', ddf($config);
    debugf 'data_dir: %s', $config->{data_dir};
    dir($config->{data_dir})->mkpath(0, oct(2775));

    return $config;
}

sub ua {
    my $c = shift;
    if (!exists $c->{ua}) {
        $c->{ua} = Furl->new(
            timeout => 60,
            agent => join('/', __PACKAGE__, $VERSION),
        );
    }
    $c->{ua};
}

sub redis {
    my $c = shift;
    if (!exists $c->{redis}) {
        my $conf = $c->config->{redis}
            or die "Missing configuration about Redis";
        $c->{redis} = DoumekiAir::Redis->new($conf);
    }
    $c->{redis};
}

1;

__END__

=head1 NAME

DoumekiAir - DoumekiAir

=head1 DESCRIPTION

This is a main context class for DoumekiAir

=head1 AUTHOR

DoumekiAir authors.

