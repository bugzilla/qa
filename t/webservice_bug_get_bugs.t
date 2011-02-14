###########################################
# Test for xmlrpc call to Bug.get_bugs()  #
###########################################

use strict;
use warnings;
use lib qw(lib);
use Data::Dumper;
use DateTime;
use QA::Util;
use QA::Tests qw(bug_tests PRIVATE_BUG_USER);
use Test::More tests => 1012;
my ($config, @clients) = get_rpc_clients();

my $xmlrpc = $clients[0];
our $creation_time = DateTime->now();
our ($public_bug, $private_bug) = $xmlrpc->bz_create_test_bugs('private');
my $private_id = $private_bug->{id};
my $public_id = $public_bug->{id};

my $base_url = $config->{browser_url} . "/"
              . $config->{bugzilla_installation} . '/';

# Set a few fields on the private bug, including setting up
# a dependency relationship.
$xmlrpc->bz_log_in(PRIVATE_BUG_USER);
$xmlrpc->bz_call_success('Bug.update', {
    ids => [$private_id],
    blocks => { set => [$public_id] },
    dupe_of => $public_id,
    is_creator_accessible => 0,
    keywords => { set => ['test-keyword-1', 'test-keyword-2'] },
    see_also => { add => ["${base_url}show_bug.cgi?id=$public_id"] },
    cf_qa_status => ['in progress', 'verified'],
    cf_single_select => 'two',
}, 'Update the private bug');
$xmlrpc->bz_call_success('User.logout');

$private_bug->{blocks} = [$public_id];
$private_bug->{dupe_of} = $public_id;
$private_bug->{status} = 'RESOLVED';
$private_bug->{is_open} = 0;
$private_bug->{resolution} = 'DUPLICATE';
$private_bug->{is_creator_accessible} = 0;
$private_bug->{is_cc_accessible} = 1;
$private_bug->{keywords} = ['test-keyword-1', 'test-keyword-2'];
$private_bug->{see_also} = ["${base_url}show_bug.cgi?id=$public_id"];
$private_bug->{cf_qa_status} = ['in progress', 'verified'];
$private_bug->{cf_single_select} = 'two';

$public_bug->{depends_on} = [$private_id];
$public_bug->{dupe_of} = undef;
$public_bug->{resolution} = '';
$public_bug->{is_open} = 1;
$public_bug->{is_creator_accessible} = 1;
$public_bug->{is_cc_accessible} = 1;
$public_bug->{keywords} = [];
$public_bug->{see_also} = [];
$public_bug->{cf_qa_status} = [];
$public_bug->{cf_single_select} = '---';

# Fill in the timetracking fields on the public bug.
$xmlrpc->bz_log_in('admin');
$xmlrpc->bz_call_success('Bug.update', {
    ids => [$public_id],
    deadline => '2038-01-01',
    estimated_time => '10.0',
    remaining_time => '5.0',
});
$xmlrpc->bz_call_success('User.logout');

# Populate other fields.
$public_bug->{classification} = 'Unclassified';
$private_bug->{classification} = 'Unclassified';
$private_bug->{groups} = ['QA-Selenium-TEST'];
$public_bug->{groups} = [];

# The user filing $private_bug doesn't have permission to set the status
# or qa_contact, so they differ from normal $public_bug values.
$private_bug->{qa_contact} = $config->{PRIVATE_BUG_USER . '_user_login'};

sub post_success {
    my ($call, $t, $rpc) = @_;

    is(scalar @{ $call->result->{bugs} }, 1, "Got exactly one bug");
    my $bug = $call->result->{bugs}->[0];

    if ($t->{user} && $t->{user} eq 'admin') {
        ok(exists $bug->{estimated_time} && exists $bug->{remaining_time}
           && exists $bug->{deadline},
           'Admin correctly gets time-tracking fields');

        is($bug->{deadline}, '2038-01-01', 'deadline is correct');
        cmp_ok($bug->{estimated_time}, '==', '10.0', 
               'estimated_time is correct');
        cmp_ok($bug->{remaining_time}, '==', '5.0',
               'remaining_time is correct');
    }
    else {
        ok(!exists $bug->{estimated_time} && !exists $bug->{remaining_time}
           && !exists $bug->{deadline},
           'Time-tracking fields are not returned to non-privileged users');
    }

    if ($t->{user}) {
        ok($bug->{update_token}, 'Update token returned for logged-in user');
    }
    else {
        ok(!exists $bug->{update_token}, 
           'Update token not returned for logged-out users');
    }

    my $expect = $bug->{id} == $private_bug->{id} ? $private_bug : $public_bug;

    my @fields = sort keys %$expect;
    push(@fields, 'creation_time', 'last_change_time');

    foreach my $field (@fields) {
        # "description" is used by Bug.create but comments are not returned
        # by Bug.get.
        next if $field eq 'description';

        my @include = @{ $t->{args}->{include_fields} || [] };
        my @exclude = @{ $t->{args}->{exclude_fields} || [] };
        if ((@include and !grep { $_ eq $field } @include )
            or (@exclude and grep { $_ eq $field } @exclude))
        {
            ok(!exists $bug->{$field}, "$field is not included")
              or diag Dumper($bug);
            next;
        }

        if ($field =~ /^is_/) {
            ok(defined $bug->{$field}, $rpc->TYPE . ": $field is not null");
            is($bug->{$field} ? 1 : 0, $expect->{$field} ? 1 : 0,
               $rpc->TYPE . ": $field has the right boolean value");
        }
        elsif ($field eq 'cc') {
            foreach my $cc_item (@{ $expect->{cc} || [] }) {
                ok(grep($_ eq $cc_item, @{ $bug->{cc} }),
                   $rpc->TYPE . ": $field contains $cc_item");
            }
        }
        elsif ($field eq 'creation_time' or $field eq 'last_change_time') {
            my $creation_day;
            # XML-RPC and JSON-RPC have different date formats.
            if ($rpc->isa('QA::RPC::XMLRPC')) {
                $creation_day = $creation_time->ymd('');
            }
            else {
                $creation_day = $creation_time->ymd;
            }
            
            like($bug->{$field}, qr/^\Q${creation_day}\ET\d\d:\d\d:\d\d/,
                 $rpc->TYPE . ": $field has the right format");
        }
        else {
            is_deeply($bug->{$field}, $expect->{$field},
                      $rpc->TYPE . ": $field value is correct");
        }
    }
}

my @tests = (
    @{ bug_tests($public_id, $private_id) },
    { args => { ids => [$public_id],
                include_fields => ['id', 'summary', 'groups'] },
      test => 'include_fields',
    },
    { args => { ids => [$public_id],
                exclude_fields => ['assigned_to', 'cf_qa_status'] },
      test => 'exclude_fields' },
    { args => { ids => [$public_id], 
                include_fields => ['id', 'summary', 'groups'],
                exclude_fields => ['summary'] },
      test => 'exclude_fields overrides include_fields' },
);

foreach my $rpc (@clients) {
    $rpc->bz_run_tests(tests => \@tests,  method => 'Bug.get',
                       post_success => \&post_success);
}
