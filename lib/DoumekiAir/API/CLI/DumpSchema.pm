package DoumekiAir::CLI::DumpSchema;

use strict;
use warnings;
use 5.010_000;
use utf8;

use DBI;
use Path::Class;
use Teng::Schema::Dumper;
use Test::mysqld;

my %json_bool = (
    inflate => <<'EOSUB',
sub {
    my $v = shift;
    return $v ? \1 : \0;
};
EOSUB
    deflate => <<'EOSUB',
sub {
    my $v = shift;
    return $v ? 1 : 0;
};
EOSUB
);

sub run {
    my $mysqld = Test::mysqld->new(my_cnf => { 'skip-networking' => '' })
        or die $Test::mysqld::errstr;
    my $dbh = DBI->connect($mysqld->dsn);

    my $file_name = 'sql/ddl.sql';
    my $source    = file($file_name)->slurp;

    for my $stmt (split /;/, $source) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }

    my $schema_class = 'lib/DoumekiAir/DB/Schema.pm';
    my @modules = qw(
                        Carp
                );
    my $use_modules = '';
    $use_modules = 'use '.join(";\nuse ", @modules).";\n" if @modules;
    open my $fh, '>', $schema_class or die "$schema_class \: $!";
    my $content = Teng::Schema::Dumper->dump(
        dbh => $dbh,
        namespace      => 'DoumekiAir::DB',
        base_row_class => 'DoumekiAir::DB::Row',
        inflate        => {
            assets => q|
    for my $c (qw(evaluation_flg)) {
        inflate $c => |.$json_bool{inflate}.q|
        deflate $c => |.$json_bool{deflate}.q|
    }
|,
            hosts => q|
    inflate 'exception' => |.$json_bool{inflate}.q|
    deflate 'exception' => sub {
        my $v = shift;
        return $v ? 'exception' : undef;
    };

    for my $c (qw(monitor_ignore_flg dr_switch_daemon_flg)) {
        inflate $c => |.$json_bool{inflate}.q|
        deflate $c => |.$json_bool{deflate}.q|
    }
|,
        },
    );
    $content =~ s{(use warnings;)}{$1\n$use_modules};
    print $fh $content;
    close $fh;
}

1;

__END__

=encoding utf8

=head1 NAME

B<DoumekiAir::CLI::DumpSchema>

=head1 DESCRIPTION

Mainly used by C<daiku dump_schema>.

=cut
