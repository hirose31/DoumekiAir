package DoumekiAir::Worker::Base;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Try::Tiny;
use Parallel::Prefork;
use Log::Minimal;
use Carp;

use DoumekiAir;
use DoumekiAir::Util;

use Class::Accessor::Lite (
    new => 0,
    rw  => [qw(
                  c
                  max_workers
                  job_count
                  max_job_count
                  timeout
          )]
);

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;

    my $self = bless {
        max_workers   => 2,
        job_count     => 0,
        max_job_count => 20,
        timeout       => 60,
        %args,
        c             => DoumekiAir->bootstrap(),
    }, $class;

    return $self;
}

sub queue   { die "abstract base method. please implement this method in child class" }

# this method must return boolean value.
# true if suceeded, false otherwise.
sub process { die "abstract base method. please implement this method in child class" }

sub run {
    my $self = shift;

    # time is not required, because I use multilog
    # print pid for debugging
    local $Log::Minimal::PRINT = sub {
        my ( $time, $type, $message, $trace ) = @_;
        print STDERR "[$$] [$type] $message at $trace\n";
    };

    infof("start: $$");

    my $pm = Parallel::Prefork->new(
        {
            max_workers  => $self->max_workers,
            trap_signals => {
                TERM => 'TERM',
                HUP  => 'TERM',
                INT  => 'TERM',
                USR1 => undef,
            }
        }
    );
    while ($pm->signal_received !~ /^(?:TERM|INT)$/) {
        $pm->start and next;

        infof("job done/max=%d/%d", $self->job_count, $self->max_job_count);

        my $term = 0;
        LOOP: while (!$term && $self->max_job_count >= $self->{job_count}++) {
            debugf("waiting... %s", $self->queue);
            my $mres = $self->c->model('Queue')->dequeue({
                queue   => $self->queue,
                timeout => $self->timeout,
            });
            if ($mres->has_errors) {
                critf '%s', ddf($mres->errors);
                next LOOP;
            }

            my $got_job = $mres->content;
            debugf 'got_job: %s', ddf($got_job);
            if (ref($got_job) ? !%{$got_job} : !$got_job) {
                debugf("no job...");
                next LOOP;
            };
            infof("got job: %s", ddf($got_job));

            try {
                local $SIG{TERM} = sub { infof("TERM RECEIVED : ");  $term++ };

                my $retval = $self->process($got_job);
                if ($retval) {
                    infof("finished");
                } else {
                    critff("failed");
                }
            } catch {
                critff("error occured: $_");
            };
        }

        $pm->finish;
    }
    infof("parent is ready for exit");
    $pm->wait_all_children();
    infof("ok, I'll die!");
}

1;

__END__
