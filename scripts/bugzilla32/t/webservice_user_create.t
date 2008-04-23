#########################################
# Test for xmlrpc call to User.Create() #
#########################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 7;

my $editusers_username = 'editusers@bugzilla.jp';
my $non_privs_username = 'no-privs@bugzilla.jp';

my $password     = shift;
my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $undefined_email = undef;
my $invalid_email   = 'invalidemailATbugzillaDOTcom';
my $existing_email  = 'editbugs@bugzilla.jp';
my $user_no         = int( rand(1000) );
my $new_email       = "xmlrpc_createduser_${user_no}\@bugzilla.jp";

my $new_realname = 'xmlrpc_createduser';
my $new_password = 'password';

my @tests = (
    [   $non_privs_username,
        $password,
        {   email     => $new_email,
            full_name => $new_realname,
            password  => $new_password
        },
        "you are not authorized",
        'calling the function with unprivileged user returns error "Authorization Failure"',
    ],
    [   $editusers_username,
        $password,
        {   email     => $undefined_email,
            full_name => $new_realname,
            password  => $new_password
        },
        "argument was not set",
        'passing undefined email param returns error "Param Required"',
    ],
    [   $editusers_username,
        $password,
        {   email     => $invalid_email,
            full_name => $new_realname,
            password  => $new_password
        },
        "didn't pass our syntax checking for a legal email address",
        'passing invalid email address returns error "Illegal Email Address"',
    ],
    [   $editusers_username,
        $password,
        {   email     => $existing_email,
            full_name => $new_realname,
            password  => $new_password
        },
        "There is already an account",
        'passing an existing email adddress returns error "Account Already Exists"',
    ],
    [   $editusers_username,
        $password,
        {   email     => $new_email,
            full_name => $new_realname,
            password  => $new_password
        },
        'calling function with privileged user and valid email address passes successfuly',
    ],

);

my $cookie_jar = new HTTP::Cookies( file => "/tmp/lwp_cookies.dat" );
my $rpc        = new XMLRPC::Lite( proxy => $xmlrpc_url );

my $call;

# test calling User.create without logging into bugzilla
$call = $rpc->call(
    'User.create',
    {   email     => $new_email,
        full_name => $new_realname,
        password  => $new_password
    },
);
cmp_ok( $call->faultstring, '=~', 'you are not authorized',
    'calling the function without loggin in first returns error "Authorization Failure"'
);

$rpc->transport->cookie_jar($cookie_jar);

for my $t (@tests) {
    $call = $rpc->call( 'User.login',
        { login => $t->[0], password => $t->[1] } );

    # Save the cookies in the cookie file
    $rpc->transport->cookie_jar->extract_cookies(
        $rpc->transport->http_response );
    $rpc->transport->cookie_jar->save;

    $call = $rpc->call( 'User.create', $t->[2] );
    my $result = $call->result;

    if ( $t->[4] ) {
        cmp_ok( $call->faultstring, '=~', $t->[3], $t->[4] );
    }
    else {
        ok( !defined $call->faultstring, $t->[3] );
        cmp_ok( $result->{id}, 'gt', '0',
            "New user has been created successfully with id $result->{id}" );
    }

    $call = $rpc->call('User.logout');
}

