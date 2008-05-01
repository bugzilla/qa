########################################
# Test for xmlrpc call to Bug.create() #
########################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 26;

my $username = 'editbugs@bugzilla.jp';
my $password = shift;

my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

###################################################################
# Bug.create() testing
###################################################################

my $bug_fields = {
    'priority'     => 'P1',
    'bug_status'   => 'NEW',
    'version'      => 'unspecified',
    'reporter'     => "$username",
    'bug_file_loc' => '',
    'comment'      => 'please ignore this bug',
    'cc'           => ['no-privs@bugzilla.jp'],
    'component'    => 'TestComp',
    'rep_platform' => 'All',
    'assigned_to'  => "$username",
    'short_desc'   => 'This is a testing bug only',
    'product'      => 'TestProduct',
    'op_sys'       => 'Linux',
    'bug_severity' => 'normal',
    'qa_contact'   => 'canconfirm@bugzilla.jp',
};

# hash to contain all the possible $bug_fields values that
# can be passed to createBug()
my $fields = {
    short_desc => {
        undefined => {
            faultstring => 'You must enter a summary for this bug',
            value       => undef
        },
    },

    product => {
        undefined => { faultstring => 'does not exist', value => undef },
        invalid =>
            { faultstring => 'does not exist', value => 'does-not-exist' },
    },

    component => {
        undefined => {
            faultstring => 'you must first choose a component',
            value       => undef
        },
        invalid => {
            faultstring => "There is no component named 'does-not-exist'",
            value => 'does-not-exist'
        },
    },

    version => {
        undefined =>
            { faultstring => 'A legal Version was not set', value => undef },
        invalid => {
            faultstring => 'A legal Version was not set',
            value       => 'does-not-exist'
        },
    },
    rep_platform => {
        undefined =>
            { faultstring => 'A legal Platform was not set', value => undef },
        invalid => {
            faultstring => 'A legal Platform was not set',
            value       => 'does-not-exist'
        },
    },

    bug_status => {
        invalid => {
            faultstring => "There is no status named 'does-not-exist'",
            value       => 'does-not-exist'
        },
    },

    bug_severity => {
        undefined =>
            { faultstring => 'A legal Severity was not set', value => undef },
        invalid => {
            faultstring => 'A legal Severity was not set',
            value       => 'does-not-exist'
        },
    },

    priority => {
        undefined =>
            { faultstring => 'A legal Priority was not set', value => undef },
        invalid => {
            faultstring => 'A legal Priority was not set',
            value       => 'does-not-exist'
        },
    },

    op_sys => {
        undefined => {
            faultstring => 'A legal OS/Version was not set',
            value       => undef
        },
        invalid => {
            faultstring => 'A legal OS/Version was not set',
            value       => 'does-not-exist'
        },
    },

    cc => {
        invalid => {
            faultstring => 'not a valid username',
            value       => ['nonuserATbugillaDOTorg']
        },
    },

    assigned_to => {
        invalid => {
            faultstring => "There is no user named 'does-not-exist'",
            value       => 'does-not-exist'
        },
    },
    qa_contact => {
        invalid => {
            faultstring => "There is no user named 'does-not-exist'",
            value       => 'does-not-exist'
        },
    },
    alias => {
        long => {
            faultstring => 'Bug aliases cannot be longer than 20 characters',
            value       => 'MyyyyyyyyyyyyyyyyyyBugggggggggggggggggggggg'
        },
        existing => {
            faultstring => 'already taken the alias',
            value       => 'testtesttest'
        },
        numeric => {
            faultstring => 'aliases cannot be merely numbers',
            value       => '12345'
        },
        commma_or_space_separated => {
            faultstring => 'contains one or more commas or spaces',
            value       => 'Bug 12345'
        },

        }

};
my $cookie_jar = new HTTP::Cookies( file => "/tmp/lwp_cookies.dat" );
my $rpc        = new XMLRPC::Lite( proxy => $xmlrpc_url );

# test calling Bug.create without logging into bugzilla
my $call = $rpc->call( 'Bug.create', $bug_fields );
cmp_ok( $call->faultstring, '=~', 'Login Required',
    'calling the function without loggin in first returns error "Login Required"'
);

$rpc->transport->cookie_jar($cookie_jar);

$call = $rpc->call('User.login', { login => $username, password => $password });

# Save the cookies in the cookie file
$rpc->transport->cookie_jar->extract_cookies($rpc->transport->http_response);
$rpc->transport->cookie_jar->save;

# run the tests for all the invalid values that can be passed to Bug.create()
foreach my $f (sort keys %{$fields}) {
    foreach my $val (sort keys %{$fields->{$f}}) {
        my %bug_fields_hash = %$bug_fields;
        my $bug_fields_copy = \%bug_fields_hash;
        $bug_fields_copy->{$f} = $fields->{$f}->{$val}->{value};
        my $expected_faultstring = $fields->{$f}->{$val}->{faultstring};

        $call = $rpc->call('Bug.create', $bug_fields_copy);
        cmp_ok( $call->faultstring, '=~', $expected_faultstring,
                "attempt to set $f to $val value got faultstring '$expected_faultstring'"
        );
    }
}

# after the loop ends all the $bug_fields value will be set to valid
# this is done by the sort so call create bug with the valid $bug_fields
# to run the test for the successful creation of the bug
$call = $rpc->call( 'Bug.create', $bug_fields );

my $result = $call->result;

is( $call->faultstring, undef,
    'Bug.create() produced no faults when called with all valid required bug fields'
);
cmp_ok( $result->{id}, 'gt', 0, "new bug has been created and got a new id $result->{id}" );

$rpc->call('User.logout');
