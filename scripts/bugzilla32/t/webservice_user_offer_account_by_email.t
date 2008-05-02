#########################################################
# Test for xmlrpc call to User.offer_account_by_email() #
#########################################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 5;

my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $undefined_email = undef;
my $invalid_email   = 'invalidemailATbugzillaDOTcom';
my $existing_email  = 'editbugs@bugzilla.jp';
my $user_no         = int( rand(1000) );
my $new_email       = "xmlrpc_createduser_${user_no}\@bugzilla.jp";

my @tests = (
    [   { email => $undefined_email, },
        "argument was not set",
        'passing undefined email address returns error "Param Required"',
    ],
    [   { email => $invalid_email, },
        "didn't pass our syntax",
        'passing invalid email address returns error "Illegal Email Address"',
    ],
    [   { email => $existing_email, },
        "There is already an account",
        'passing existing email address returns error "Account Already Exists"',
    ],
    [   { email => $new_email, },
        'passing valid non-existing new email address returns no errors',
    ],
);

my $rpc = new XMLRPC::Lite( proxy => $xmlrpc_url );

my $call;

for my $t (@tests) {

    $call = $rpc->call( 'User.offer_account_by_email', $t->[0] );
    my $result = $call->result;

    if ( $t->[2] ) {
        cmp_ok( $call->faultstring, '=~', $t->[1], $t->[2] );
    }
    else {
        ok( !defined $call->faultstring, $t->[1] );
        cmp_ok( $call->result, 'eq', undef,
            'passing valid non-existing new email works successfully' );
    }
}

