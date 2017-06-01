package DoumekiAir::CLI::Release;

use strict;
use warnings;
use 5.010_000;
use utf8;

use YAML;
use Path::Class;

use DoumekiAir;
use DoumekiAir::Util;

sub run {
    # かなり雑だよ！

    if (git_modified()) {
        warn "[ERROR] git commit before release\n";
        return;
    }

    my $old_version = $DoumekiAir::VERSION->normal;
    my $new_version = version->parse($DoumekiAir::VERSION->numify + 0.000001)->normal;
    printf "%s -> %s\n", $old_version, $new_version;

    # カレントディレクトリに依存してるので雑
    open my $rfh, '<', 'lib/DoumekiAir.pm' or die $!;
    my @contents = <$rfh>;
    close $rfh;

    open my $wfh, '>', 'lib/DoumekiAir.pm' or die $!;
    for (@contents) {
        s/declare\('$old_version'\)/declare('$new_version')/;
        print {$wfh} $_;
    }
    close $wfh;

    system(qq{git add -A . && git commit -m "$new_version" && git tag -m "" -a "$new_version"});
    print "TODO\n  git push; git push --tags\n";
}

sub git_modified {
    my $out = qx{git status --porcelain | grep -v ' CHANGELOG.md\$'};
    return $out ? 1 : ();
}

1;

__END__

=encoding utf8

=head1 NAME

B<DoumekiAir::CLI::Release>

=head1 DESCRIPTION

Mainly used by C<daiku release>.

=cut
