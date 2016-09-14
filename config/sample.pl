use strict;

use Path::Class;

my $root_dir = file(__FILE__)->parent->parent->resolve;
my $data_dir = $root_dir->subdir('var');

+{
    'data_dir'         => $data_dir->stringify,
    'maintenance_file' => '/tmp/maintenance',
    'DBI' => [
    ],
    'redis' => {
        server => '127.0.0.1:6479',
    },
};
