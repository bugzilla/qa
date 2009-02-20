###########################################
# Test for xmlrpc call to Bug.get_bugs()  #
###########################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 10;

my $privileged_username = 'admin@bugzilla.jp';
my $non_privs_username  = 'no-privs@bugzilla.jp';

my $password     = shift;
my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $private_bug       = 32;
my $public_bug        = 1;
my $bug_alias         = 'aliasaliasalias';
my $invalid_bug_id    = -1;
my $invalid_bug_alias = 'hjgh';
my $undefined_bug     = undef;

my @tests = (
    [   $non_privs_username,
        $password,
        { ids => [$private_bug] },
        "You are not authorized to access bug #$private_bug",
        'trying to get private bug information with logged in unprivileged user returns error "Access Denied"',
    ],
    [   $privileged_username,
        $password,
        { ids => [$undefined_bug], },
        "You must enter a valid bug number",
        'passing undefined bug id param returns error "Invalid Bug ID"',
    ],
    [   $privileged_username,
        $password,
        { ids => [$invalid_bug_id], },
        "not a valid bug number",
        'passing invalid bug id returns error "Invalid Bug ID"',
    ],
    [   $privileged_username,
        $password,
        { ids => [$invalid_bug_alias], },
        "nor an alias to a bug",
        'passing invalid bug alias returns error "Invalid Bug Alias"',
    ],
    [   $privileged_username,
        $password,
        { ids => [ $private_bug, $bug_alias, $public_bug ], },
        'privileged logged in user can successfully access private and public bug information',
    ],

);

my $cookie_jar = new HTTP::Cookies( file => "/tmp/lwp_cookies.dat" );
my $rpc        = new XMLRPC::Lite( proxy => $xmlrpc_url );

my $call;

# test calling Bug.get_bugs without logging into bugzilla to get private bug
$call = $rpc->call( 'Bug.get_bugs', { ids => [$private_bug], }, );
cmp_ok(
    $call->faultstring,
    '=~',
    "You are not authorized to access bug #$private_bug",
    'trying to get private bug information without logging in returns error "Access Denied"'
);

# test calling Bug.get_bugs without logging into bugzilla to get public bug
$call = $rpc->call( 'Bug.get_bugs', { ids => [$public_bug], }, );

cmp_ok( $call->result->{bugs}->[0]->{id}, '==', $public_bug,
    'trying to get public bug information without logging in returns the bug information successfully'
);
ok( (   !defined $call->result->{bugs}->[0]->{internals}{estimated_time}
            && !defined $call->result->{bugs}->[0]->{internals}{remaining_time}
            && !defined $call->result->{bugs}->[0]->{internals}{deadline}
    ),
    'timetracking fields are not returned to non privileged/logged-in users'
);

$rpc->transport->cookie_jar($cookie_jar);

for my $t (@tests) {
    $call = $rpc->call( 'User.login',
        { login => $t->[0], password => $t->[1] } );

    # Save the cookies in the cookie file
    $rpc->transport->cookie_jar->extract_cookies(
        $rpc->transport->http_response );
    $rpc->transport->cookie_jar->save;

    $call = $rpc->call( 'Bug.get_bugs', $t->[2] );
    my $result = $call->result;

    if ( $t->[4] ) {
        cmp_ok( $call->faultstring, '=~', $t->[3], $t->[4] );
    }
    else {
        ok( !defined $call->faultstring, $t->[3] );
        cmp_ok( scalar @{ $result->{bugs} }, '==', '3',
            "information for all requested bugs have been returned successfully to privileged user"
        );
        ok( (   defined $result->{bugs}->[0]->{internals}{estimated_time}
                    && defined $result->{bugs}->[0]->{internals}{remaining_time}
                    && defined $result->{bugs}->[0]->{internals}{deadline}
            ),
            'timetracking fields are returned successfully to the privileged user'
        );
    }

    $call = $rpc->call('User.logout');
}

