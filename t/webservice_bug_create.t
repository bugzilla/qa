########################################
# Test for xmlrpc call to Bug.create() #
########################################

use strict;
use warnings;
use lib qw(lib);
use Test::More tests => 53;
use QA::Util;

my ($rpc, $config) = get_xmlrpc_client();

########################
# Bug.create() testing #
########################

my $bug_fields = {
    'priority'     => 'P1',
    'bug_status'   => 'NEW',
    'version'      => 'unspecified',
    'reporter'     => $config->{editbugs_user_login},
    'bug_file_loc' => '',
    'comment'      => '-- Comment Created By Bugzilla XML-RPC Tests --',
    'cc'           => [$config->{unprivileged_user_login}],
    'component'    => 'TestComponent',
    'rep_platform' => 'All',
    'assigned_to'  => $config->{editbugs_user_login},
    'short_desc'   => 'XML-RPC Test Bug',
    'product'      => 'TestProduct',
    'op_sys'       => 'Linux',
    'bug_severity' => 'normal',
    'qa_contact'   => $config->{canconfirm_user_login},
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
            value       => 'public_bug'
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

# test calling Bug.create without logging into bugzilla
my $create_call = xmlrpc_call_fail($rpc, 'Bug.create', $bug_fields);
cmp_ok( $create_call->faultstring, '=~', 'Login Required',
    'calling the function without loggin in first returns error "Login Required"'
);

xmlrpc_log_in($rpc, $config, 'editbugs');

# run the tests for all the invalid values that can be passed to Bug.create()
foreach my $f (sort keys %{$fields}) {
    foreach my $val (sort keys %{$fields->{$f}}) {
        my %bug_fields_hash = %$bug_fields;
        my $bug_fields_copy = \%bug_fields_hash;
        $bug_fields_copy->{$f} = $fields->{$f}->{$val}->{value};
        my $expected_faultstring = $fields->{$f}->{$val}->{faultstring};

        my $fail_call = xmlrpc_call_fail($rpc, 'Bug.create', $bug_fields_copy);
        cmp_ok( $fail_call->faultstring, '=~', $expected_faultstring,
                "attempt to set $f to $val value got faultstring '$expected_faultstring'"
        );
    }
}

# after the loop ends all the $bug_fields value will be set to valid
# this is done by the sort so call create bug with the valid $bug_fields
# to run the test for the successful creation of the bug
my $success_create = xmlrpc_call_success($rpc, 'Bug.create', $bug_fields);
cmp_ok($success_create->result->{id}, 'gt', 0,
       "Created new bug with id " . $success_create->result->{id});
xmlrpc_call_success($rpc, 'User.logout');
