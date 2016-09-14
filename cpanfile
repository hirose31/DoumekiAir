requires 'Amon2', '6.13';
requires 'Crypt::CBC';
requires 'Crypt::Rijndael';
requires 'DBD::SQLite', '1.33';
requires 'HTML::FillInForm::Lite', '1.11';
requires 'HTTP::Session2', '1.03';
requires 'JSON', '2.50';
requires 'Module::Functions', '2';
requires 'Plack::Middleware::ReverseProxy', '0.09';
requires 'Router::Boom', '0.06';
requires 'Starlet', '0.20';
requires 'Teng', '0.18';
requires 'Test::WWW::Mechanize::PSGI';
requires 'Text::Xslate', '2.0009';
requires 'Time::Piece', '1.20';
requires 'perl', '5.010_001';

requires 'Log::Minimal';
requires 'Path::Class';
requires 'Class::Accessor::Lite';
requires 'Redis';
requires 'Redis::Namespace';
requires 'Redis::Key';
requires 'Data::Validator';
requires 'Data::Validator::Recursive', '0.07';
requires 'IPC::Cmd';
requires 'Sub::Retry';
requires 'Try::Tiny';
requires 'Parallel::Prefork';
requires 'Daiku';
requires 'DBIx::QueryLog';

on configure => sub {
    requires 'Module::Build', '0.38';
    requires 'Module::CPANfile', '0.9010';
};

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Harriet';
    requires 'Test::Pretty';
    requires 'Test::RedisServer';
    requires 'Text::SimpleTable';
};
