#!/usr/bin/perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# 
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use warnings;
use strict;

use FindBin qw($RealBin);
use lib ($RealBin, "$RealBin/t/lib");

use Carp;
use File::Basename;
use File::Path;
use Getopt::Long;
use QA::DB;

set_env();

#####################################################################
# Constants
#####################################################################

my %switch;
GetOptions(\%switch, 'full', 'skip-basic', 'config:s');

my $config_file = $switch{config} || 'config-test-checksetup';
require $config_file;

# Set up some global constants.
our $config = CONFIG();
our $test_db_name   = $config->{test_db};
our $tip_database = $test_db_name . "_tiptest";
our $answers_file = $config->{answers};
our $dump_file_url = $config->{dump_file_url};

# Configuration for the detailed tests

# How many of each object we create while we're testing the created database.
# The larger this number is, the longer the tests will take, but the more
# thorough they will be.
our $object_limit = 500;

# The login name and realname for the user that we create in the database 
# during testing.
our $test_user_login = $config->{test_user_login};
our $test_real_name  = $config->{test_real_name};

my %db_list = %{$config->{db_list}};

#####################################################################
# Subroutines
#####################################################################

sub set_env {
    $ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin';
    $ENV{PGOPTIONS}='-c client_min_messages=warning';
}

our $_db;
sub db {
    return $_db ||= QA::DB->new({ db_type  => $config->{db_type},
                                  user     => $config->{db_user},
                                  password => $config->{db_pass} });
}

sub check_schema ($$) {
    my ($for_db, $version_db) = @_;
    $version_db = '(checksetup-created)' unless $version_db;

    my $diffs = db()->diff_schema($tip_database, $for_db);
    if ($diffs) {
        print STDERR "\nWARNING: Differences found between $version_db"
                     . " and $tip_database:\n\n";
        print STDERR $diffs;
    }
}

sub check_test ($$) {
    my ($test_name, $failures) = @_;
    if ($failures) {
        print STDERR "\n\n***** $test_name FAILED! *****\n\n";
        $::total_failures += $failures;
    }
}

# Runs checksetup against the specified DB. Returns the number of times
# that the tests failed. If you specify no DB, we will create an empty
# DB and test against that.
sub run_against_db (;$$$) {
    my ($db_name, $quickly, $skip_schema) = @_;
    my $checksetup_switches = "--verbose ";
    my $failures = 0;
    $checksetup_switches .= " --no-templates" if $quickly;
    if ($db_name) {
        db()->copy_db({ from => $db_name,
                        to   => $test_db_name,
                        url  => $dump_file_url });
    }
    # Enable the Voting extension
    unlink 'extensions/Voting/disabled';
    $failures += (system("perl -w ./checksetup.pl $answers_file $checksetup_switches") != 0);
    # For the sake of consistency, now disable the extension.
    system('touch extensions/Voting/disabled');
    # Run tests against the created database only if checksetup ran.
    if(!$failures && !$skip_schema) {
        print "Validating the created schema...\n";
        check_schema($test_db_name, $db_name);
        print "\nRunning tests against the created database...\n";
        $failures += test_created_database();
    }

    return $failures;
}

our $Test_Die_Count;
# Run a bunch of tests on the DBs. Traps the DIE and WARN handler, and returns
# how many times the DIE handler has to be called.
sub test_created_database () {
    require Bugzilla;
    require Bugzilla::Bug;
    require Bugzilla::User;
    require Bugzilla::Series;
    require Bugzilla::Attachment;
    require Bugzilla::Token;
    require Bugzilla::Product;

    # Loading Bugzilla.pm cleared our environment.
    set_env();

    $Test_Die_Count = 0;

    $SIG{__DIE__} = \&test_die;

    # Everything happens in an eval block -- we don't want to ever actually
    # die during tests. Things happen in separate eval blocks because we 
    # want to continue to do the tests even if one of them fails.

    my $rand = db()->sql_random;

    my $dbh;
    eval {
        # Get a handle to the database.
        $dbh = Bugzilla->dbh;
    };
    # If we can't create the DB handle, there's no point in the
    # rest of the tests.
    return $Test_Die_Count if $Test_Die_Count;

    my $test_user;
    eval {
        # Create a User in the database.
        print "Creating a brand-new user...";
        $test_user = Bugzilla::User->create({
            login_name    => $test_user_login,
            realname      => $test_real_name,
            cryptpassword => '*'});
        print "inserted $test_user_login\n";
    };

    # If we can't create the user, most of the rest of our tests will fail anyway.
    return $Test_Die_Count if $Test_Die_Count;

    my $bug_id_list;
    eval {
        # Create some Bug objects.
        print "Reading in bug ids... ";
        $bug_id_list = $dbh->selectcol_arrayref(
            "SELECT bug_id 
               FROM (SELECT bug_id, $rand AS ord 
                      FROM bugs ORDER BY ord) AS t 
              LIMIT $object_limit");
        print "found " . scalar(@$bug_id_list) . " bugs.\n";

        print "Creating bugs";
        foreach my $bug_id (@$bug_id_list) {
            print ", $bug_id";
            my $bug = new Bugzilla::Bug($bug_id, $test_user);
            # And read in attachment data for each bug, too.
            # This also tests a lot of other code paths.
            $bug->attachments;
            # And call a few other subs for testing purposes.
            $bug->dup_id;
            $bug->actual_time;
            $bug->any_flags_requesteeble;
            $bug->blocked;
            $bug->cc;
            $bug->keywords;
            $bug->comments;
            $bug->groups;
            $bug->choices;
        }
        print "\n";
    };

    eval {
        # Create some User objects and run some methods on them.
        print "Reading in user ids... ";
        my $user_id_list = $dbh->selectcol_arrayref(
            "SELECT userid
               FROM (SELECT userid, $rand AS ord
                      FROM profiles ORDER BY ord) AS t
              LIMIT $object_limit");
        print "found " . scalar(@$user_id_list) . " users.\n";

        print "Creating users";
        foreach my $user_id (@$user_id_list) {
            print ", $user_id";
            my $created_user = new Bugzilla::User($user_id);
            $created_user->groups();
            $created_user->queries();
            $created_user->can_see_bug(1) if (@$bug_id_list);
            $created_user->get_selectable_products();
        }
        print "\n";
    };

    eval {
        # Create some Series objects.
        print "Reading in series ids... ";
        my $series_id_list = $dbh->selectcol_arrayref(
            "SELECT series_id
               FROM (SELECT series_id, $rand AS ord
                      FROM series ORDER BY ord) AS t
              LIMIT $object_limit");
        print "found " . scalar(@$series_id_list) . " series.\n";
        print "Creating series";
        foreach my $series_id (@$series_id_list) {
            print ", $series_id";
            my $created_series = new Bugzilla::Series($series_id);
            # We could have been returned undef if we couldn't see the series.
            $created_series->writeToDatabase() if $created_series;
        }
        print "\n";
    };

    eval {
        # Create some Product objects and their related items.
        print "Reading in products... ";
        my @products = Bugzilla::Product->get_all;
        print "found " . scalar(@products) . " products.\n";
        print "Testing products";
        foreach my $product (@products) {
            print ", " . $product->id;
            $product->components;
            $product->group_controls;
            $product->versions;
            $product->milestones;
        }
        print "\n";
    };

    eval {
        # Clean the token table
        print "Attempting to clean the Token table... ";
        Bugzilla::Token::CleanTokenTable();
        print "cleaned.\n";
    };

    # Disconnect so that Pg doesn't complain we're still using the DB.
    $dbh->disconnect;
    Bugzilla->clear_request_cache();

    return $Test_Die_Count;
}

# For dealing with certain signals while we're testing. We just
# print out a stack trace and increment our global counter
# of how many times we died.
sub test_die ($) {
    my ($message) = @_;
    $Test_Die_Count++;
    Carp::cluck($message);
}

#####################################################################
# Read-In Command-Line Arguments
#####################################################################

# The user can specify versions to test against on the command-line.
my @runversions;
if ($switch{'full'}) {
    # The --full switch overrides the version list.
    @runversions = (keys %db_list);
}
else {
    # All arguments that are not switches are version numbers.
    @runversions = @ARGV;
    # Skip the basic tests if we were passed-in version numbers.
    $switch{'skip-basic'} = $switch{'skip-basic'} || scalar @runversions;
}

#####################################################################
# Main Code
#####################################################################

# Basically, what we do is import databases into our current installation
# over and over and see if we can upgrade them with our checksetup.

our $total_failures = 0;

# We have to be in the right directory for checksetup to run.
chdir $config->{base_dir} || die "Could not change to the base directory: $!";

db()->reset();

# Try to run cleanly against the tip database.
print "== Testing against tip database " . $config->{tip_db} . "\n";
check_test("Test against tip database",
           run_against_db($config->{tip_db}, "quickly", "skip schema"));

# And now copy the database that we created to be our "tip
# database" for schema comparisons in the future.
print "Copying $test_db_name to $tip_database for future schema tests...\n\n";
db()->copy_db({ from => $test_db_name,
                to   => $tip_database,
                url  => $dump_file_url });

# If the user specified a specific version to test, don't 
# do certain generic tests.
if (!$switch{'skip-basic'}) {
    # Have checksetup create an empty DB.
    print "== Creating a blank database called $test_db_name\n";
    # We only want to test the chart migration once (because it's slow), so 
    # let's do it here.
    db()->drop_db($test_db_name);
    check_test("Test of creating an empty database", run_against_db());
}

# If we're running --full or if we have version numbers, test that stuff.
# But if we failed to do the basic runs, then don't test that stuff.
if (scalar @runversions && !$total_failures) {
    # Now run against every version that we have a database for.
    foreach my $version (sort @runversions) {
        print "== Testing against database from version $version\n";
        check_test("Test against database from version $version",
                   run_against_db($db_list{$version}, "quickly"));
    }
}

print "\nTest complete. Failed $total_failures time(s).\n";
exit $total_failures;
