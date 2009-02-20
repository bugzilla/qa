###################################################
# Test for xmlrpc call functions in Bugzilla.pm:  #
# Bugzilla.version()                              #
# Bugzilla.timezone()                             #
###################################################

use strict;
use warnings;

use XMLRPC::Lite;

use Test::More tests => 4;

my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $rpc = new XMLRPC::Lite( proxy => $xmlrpc_url );

my $call   = $rpc->call('Bugzilla.version');
my $result = $call->result;
ok( !defined $call->faultstring,
    'call to Bugzilla.version returns no errors' );
ok( defined $result->{version},
    "Bugzilla.version returns the Bugzilla version sucessfully which is $result->{version}"
);

$call = $rpc->call('Bugzilla.timezone');
$result = $call->result;
ok( !defined $call->faultstring,
    'call to Bugzilla.timezone returns no errors' );
ok( defined $result->{timezone},
    "Bugzilla.timezone returns the timezone of the server Bugzilla is running on sucessfully which is $result->{timezone}"
);

