package DoumekiAir::Worker::Uploader;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Log::Minimal;
use Carp;
use JSON qw(encode_json decode_json);

use DoumekiAir;
use DoumekiAir::Util;

use parent qw(DoumekiAir::Worker::Base);

sub queue { 'wakeup' }

sub process {
    my($self, $job) = @_;

    infof "start job";

    debugf 'job: %s', ddf($job);

    my $flashair_id = $job;
    infof 'flashair id: %s', $flashair_id;

    ### fetch list of files
    my $config = $self->c->config->{flashair}{ $flashair_id };
    unless (%$config) {
        croakf 'missing config for %s', $flashair_id;
    }

    my $flashair = $self->c->model('FlashAir', {
        id => $flashair_id,
        %$config,
    });
    # fixme フィルタリングもfilelistでやる？
    my @files = $flashair->filelist();

    # fixme
    # for my $file (@files) {
    #     $flashair->fetch({
    #         file => $file,
    #         callback => sub {
    #             $self->c->model('Store')->store({
    #                 file => $file,
    #             });
    #         },
    #     });
    # }

    ### store
    # $self->c->model('Store')->store({
    #     id => $flashair_id,
    # });

    my $r = 1;

    infof "end   job";
    return $r ? 1 : ();
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
