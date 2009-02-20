##################################################
# Test for xmlrpc call functions in Bugzilla.pm  #
##################################################

use strict;
use warnings;
use lib qw(lib);
use Test::More tests => 7;
use QA::Util;
my ($rpc, $config) = get_xmlrpc_client();

my $vers_call = xmlrpc_call_success($rpc, 'Bugzilla.version');
my $version = $vers_call->result->{version};
ok($version, "Bugzilla.version returns $version");

my $tz_call = xmlrpc_call_success($rpc, 'Bugzilla.timezone');
my $tz = $tz_call->result->{timezone};
ok($tz, "Bugzilla.timezone retuns $tz");

my $ext_call = xmlrpc_call_success($rpc, 'Bugzilla.extensions');
my $extensions = $ext_call->result->{extensions};
isa_ok($extensions, 'HASH', 'extensions');
is(scalar keys %$extensions, 0, 'No extensions returned.');
