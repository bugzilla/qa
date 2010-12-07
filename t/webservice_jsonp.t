use strict;
use warnings;
use lib qw(lib);
use Test::More tests => 85;
use QA::Util;
my $jsonrpc_get = QA::Util::get_jsonrpc_client('GET');

my @chars = (0..9, 'A'..'Z', 'a'..'z', '_[].');

our @tests = (
    { args => { callback => join('', @chars) },
      test => 'callback accepts all legal characters.' },
);
foreach my $char (qw(! ~ ` @ $ % ^ & * - + = { } ; : ' " < > / ? |),
                  '(', ')', '\\', '#', ',')
{
    push(@tests,
         { args  => { callback => "a$char" },
           error => "as your 'callback' parameter",
           test  => "$char is not valid in callback" });
}

$jsonrpc_get->bz_run_tests(method => 'Bugzilla.version', tests => \@tests);
