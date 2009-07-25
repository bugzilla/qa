#########################################
# Test for xmlrpc call to Bug.history() #
#########################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use QA::Tests qw(STANDARD_BUG_TESTS);
use Test::More tests => 31;
my ($rpc, $config) = get_xmlrpc_client();

sub post_success {
    my ($call, $t) = @_;
    is(scalar @{ $call->result->{bugs} }, 1, "Got exactly one bug");
    isa_ok($call->result->{bugs}->[0]->{history}, 'ARRAY', "Bug's history");
}

xmlrpc_run_tests(rpc => $rpc, config => $config, tests => STANDARD_BUG_TESTS,
                 method => 'Bug.history', post_success => \&post_success);
