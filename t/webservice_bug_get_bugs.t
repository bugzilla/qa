###########################################
# Test for xmlrpc call to Bug.get_bugs()  #
###########################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use Test::More tests => 31;
my ($rpc, $config) = get_xmlrpc_client();

use constant INVALID_BUG_ID => -1;
use constant INVALID_BUG_ALIAS => 'aaaaaaa12345';
use constant PRIVS_USER => 'QA_Selenium_TEST';

my @tests = (
    { args  => { ids => ['private_bug'] },
      error => "You are not authorized to access",
      test  => 'Logged-out user cannot access a private bug',
    },
    { args => { ids => ['public_bug'] },
      test => 'Logged-out user can access a public bug.',
    },
    { args  =>  { ids => [INVALID_BUG_ID] },
      error =>  "not a valid bug number",
      test  =>  'Passing invalid bug id returns error "Invalid Bug ID"',
    },
    { args  =>  { ids => [undef] },
      error => "You must enter a valid bug number",
      test  =>  'Passing undef as bug id param returns error "Invalid Bug ID"',
    },
    { args  => { ids => [INVALID_BUG_ALIAS] },
      error =>  "nor an alias to a bug",
      test  => 'Passing invalid bug alias returns error "Invalid Bug Alias"',
    },

    { user  =>  'unprivileged',
      args  =>  { ids => ['private_bug'] },
      error =>  "You are not authorized to access",
      test  => 'Access to a private bug is denied to a user without privs',
    },
    { user => 'unprivileged',
      args => { ids => ['public_bug'] },
      test => 'User without privs can access a public bug by alias.',
    },
    { user => 'admin',
      args => { ids => ['public_bug'] },
      test => 'Admin can access a public bug.',
    },
    { user => PRIVS_USER,
      args =>  { ids => ['private_bug'] },
      test =>  'User with privs can successfully access a private bug',
    },
);

sub post_success {
    my ($call, $t) = @_;

    is(scalar @{ $call->result->{bugs} }, 1, "Got exactly one bug");
    if ($t->{user} && $t->{user} eq 'admin') {
        ok(exists $call->result->{bugs}->[0]->{internals}{estimated_time}
           && exists $call->result->{bugs}->[0]->{internals}{remaining_time}
           && exists $call->result->{bugs}->[0]->{internals}{deadline},
           'Admin correctly gets time-tracking fields');
    }
    else {
        ok(!exists $call->result->{bugs}->[0]->{internals}{estimated_time}
           && !exists $call->result->{bugs}->[0]->{internals}{remaining_time}
           && !exists $call->result->{bugs}->[0]->{internals}{deadline},
           'Time-tracking fields are not returned to logged-out users');
    }
}

xmlrpc_run_tests(rpc => $rpc, config => $config, tests => \@tests,
                 method => 'Bug.get', post_success => \&post_success);
