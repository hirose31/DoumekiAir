package DoumekiAir::CLI::DumpData;

use strict;
use warnings;
use 5.010_000;
use utf8;

use YAML;
use Path::Class;

use DoumekiAir;
use DoumekiAir::Util;

my @tables = qw(users);
if ($ENV{DUMP_TABLE}) {
    @tables = split /\s+/, $ENV{DUMP_TABLE};
}

sub run {
    my $c = DoumekiAir->bootstrap();
    my $dbh = $c->db->dbh;

    for my $table (@tables) {
        print "$table\n";
        my $res = $dbh->selectall_arrayref("select * from $table", +{ Slice => +{} });
        dir('data')->file($table.'.yaml')->spew(iomode => '>:encoding(UTF-8)', YAML::Dump($res));
    }
}

1;

__END__

=encoding utf8

=head1 NAME

B<DoumekiAir::CLI::DumpData>

=head1 DESCRIPTION

Mainly used by C<daiku dump_data>.

=cut
