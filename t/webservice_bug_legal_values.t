##############################################
# Test for xmlrpc call to Bug.legal_values() #
##############################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 32;

my $qa_username        = 'qa@bugzilla.jp';
my $non_privs_username = 'no-privs@bugzilla.jp';

my $password     = shift;
my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $cookie_jar = new HTTP::Cookies( file => "/tmp/lwp_cookies.dat" );
my $rpc        = new XMLRPC::Lite( proxy => $xmlrpc_url );
$rpc->transport->cookie_jar($cookie_jar);

my $call = $rpc->call( 'User.login',
    { login => $qa_username, password => $password } );

# Save the cookies in the cookie file
$rpc->transport->cookie_jar->extract_cookies(
    $rpc->transport->http_response );
$rpc->transport->cookie_jar->save;

# get product ids from their names
$call = $rpc->call( 'Tools.product_names_to_ids',
    [ 'TestProduct', 'PrivateProduct' ] );
my $product_ids = $call->result;

my $private_product_id = $product_ids->{PrivateProduct};
my $public_product_id  = $product_ids->{TestProduct};
my $invalid_product_id = -1;

$call = $rpc->call('User.logout');

my @global_fields
    = qw(bug_severity bug_status op_sys priority rep_platform resolution);
my @product_specific_fields = qw(version target_milestone component);
my $invalid_field           = 'hkjh';

my @all_tests;

for my $global_field (@global_fields) {
    my $test = [
        $non_privs_username,
        $password,
        { field => $global_field },
        "field values returned successfully for global field $global_field to a non privileged user",
    ];

    push( @all_tests, $test );
}

for my $product_specific_field (@product_specific_fields) {
    my @tests = (
        [   $non_privs_username,
            $password,
            {   product_id => $private_product_id,
                field      => => $product_specific_field,
            },
            "you don't have access",
            "trying to get values of a private product specific field $product_specific_field with unprivileged user returns error \"Invalid Product\"",
        ],
        [   $qa_username,
            $password,
            { field => $product_specific_field, },
            "argument was not set",
            "not passing product id param with product specific field $product_specific_field returns error \"Param Required\"",
        ],
        [   $qa_username,
            $password,
            {   product_id => $invalid_product_id,
                field      => $product_specific_field,
            },
            "does not exist",
            "passing invalid product id with product specific field $product_specific_field returns error \"Param Required\"",
        ],
        [   $qa_username,
            $password,
            {   product_id => $private_product_id,
                field      => $product_specific_field,
            },
            "field values returned successfully for private product specific field $product_specific_field to a privileged user",
        ],
        [   $non_privs_username,
            $password,
            {   product_id => $public_product_id,
                field      => $product_specific_field,
            },
            "field values returned successfully for public product specific field $product_specific_field to a non privileged user",
        ],
    );

    push( @all_tests, @tests );
}

my @extra_tests = (
    [   $qa_username,
        $password,
        { product_id => $private_product_id, },
        "Can't use  as a field name",
        'not passing field param returns error "Invalid Field Name"',
    ],
    [   $qa_username,
        $password,
        {   field      => $invalid_field,
            product_id => $private_product_id,
        },
        "Can't use $invalid_field as a field name",
        'passing invalid field name returns error "Invalid Field Name"',
    ],
);

push( @all_tests, @extra_tests );

# test calling Bug.legal_values without logging into Bugzilla
for my $global_field (@global_fields) {
    $call = $rpc->call('Bug.legal_values', { field => $global_field });

    cmp_ok( scalar @{ $call->result->{values} }, 'gt', '0', "trying to get values of the global field $global_field for a logged out user" );
}
for my $product_specific_field (@product_specific_fields) {
    $call = $rpc->call(
        'Bug.legal_values',
        {   product_id => $private_product_id,
            field      => $product_specific_field,
        },
    );

    cmp_ok( $call->faultstring, '=~', "you don't have access",
        "trying to get values of a private product specific field $product_specific_field without logging in returns error \"Invalid Product\""
    );
}

for my $t (@all_tests) {
    $call = $rpc->call( 'User.login',
        { login => $t->[0], password => $t->[1] } );

    # Save the cookies in the cookie file
    $rpc->transport->cookie_jar->extract_cookies(
        $rpc->transport->http_response );
    $rpc->transport->cookie_jar->save;

    $call = $rpc->call( 'Bug.legal_values', $t->[2] );
    my $result = $call->result;

    if ( $t->[4] ) {
        cmp_ok( $call->faultstring, '=~', $t->[3], $t->[4] );
    }
    else {
        cmp_ok( scalar @{ $result->{values} }, 'gt', '0', $t->[3] );
    }

    $call = $rpc->call('User.logout');
}

