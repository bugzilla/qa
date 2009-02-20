##########################################################
# Test for xmlrpc call to User.login() and User.logout() #
##########################################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 8;

my $password     = shift;
my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $undefined_email = undef;
my $invalid_email   = 'invalidemailATbugzillaDOTcom';
my $existing_email  = 'editbugs@bugzilla.jp';
my $disabled_email  = 'disabled_user@bugzilla.jp';

my $undefined_password = undef;
my $invalid_password   = 'hsdaj';

my @tests = (
    [   {   login    => $undefined_email,
            password => $password,
            remember => 1,
        },
        "The username or password you entered is not valid",
        'passing undefined username returns error "Invalid Username or Password"',
    ],
    [   {   login    => $invalid_email,
            password => $password,
            remember => 1,
        },
        "The username or password you entered is not valid",
        'passing invalid username returns error "Invalid Username or Password"',
    ],
    [   {   login    => $existing_email,
            password => $undefined_password,
            remember => 1,
        },
        "The username or password you entered is not valid",
        'passing undefined password returns error "Invalid Username or Password"',
    ],
    [   {   login    => $existing_email,
            password => $invalid_password,
            remember => 1,
        },
        "The username or password you entered is not valid",
        'passing invalid password returns error "Invalid Username or Password"',
    ],
    [   {   login    => $disabled_email,
            password => $password,
            remember => 1,
        },
        "If you believe your account should be restored",
        'trying to login with disabled account returns error "Account Disabled"',
    ],
    [   {   login    => $existing_email,
            password => $password,
            remember => 1,
        },
        'passing valid username and password returns no errors',
    ],

);

my $cookie_jar = new HTTP::Cookies( file => "/tmp/lwp_cookies.dat" );
my $rpc        = new XMLRPC::Lite( proxy => $xmlrpc_url );

my $call;

$rpc->transport->cookie_jar($cookie_jar);

for my $t (@tests) {
    $call = $rpc->call( 'User.login', $t->[0] );

    # Save the cookies in the cookie file
    $rpc->transport->cookie_jar->extract_cookies(
        $rpc->transport->http_response );
    $rpc->transport->cookie_jar->save;

    my $result = $call->result;

    if ( $t->[2] ) {
        cmp_ok( $call->faultstring, '=~', $t->[1], $t->[2] );
    }
    else {
        ok( !defined $call->faultstring, $t->[1] );
        cmp_ok( $result->{id}, 'gt', '0',
            "user has been logged in successfully and their id:$result->{id} is returned"
        );
    }

    $call = $rpc->call('User.logout');
}

# test User.logout
ok( ( !defined $call->faultstring && !$call->result ),
    'logging out worked successfully with no errors returned'
);
