use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

my $test_bug_1 = $config->{test_bug_1};


log_in($sel, $config, 'tweakparams');
set_parameters($sel, { "User Matching"  => {"usemenuforusers-off" => undef,
                                            "usermatchmode"       => {type => 'select', value => 'off'},
                                            "maxusermatches"      => {type => 'text', value => '0'},
                                            "confirmuniqueusermatch-on" => undef},
                       "Group Security" => {"usevisibilitygroups-off" => undef}
                     });

$sel->type_ok("quicksearch_top", $test_bug_1);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We enter an incomplete email address, and user matching is off. process_bug.cgi must complain.

$sel->type_ok("newcc", $config->{unprivileged_user_login_truncated});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Match Failed");
$sel->is_text_present_ok("$config->{unprivileged_user_login_truncated} did not match anything");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We now enter a complete and valid email address, so it must be accepted.
# confirmuniqueusermatch = 1 must not trigger the confirmation page as we
# type the complete email address.

$sel->type_ok("newcc", $config->{unprivileged_user_login});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $test_bug_1 processed");

# Now test wildcards ("*").

set_parameters($sel, { "User Matching" => {"usermatchmode" => {type => 'select', value => 'wildcard'}} });

$sel->type_ok("quicksearch_top", $test_bug_1);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# There is no wildcard character ("*") and it's an incomplete email address.
# It must be rejected.

$sel->type_ok("newcc", $config->{unprivileged_user_login_truncated});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Match Failed");
$sel->is_text_present_ok("$config->{unprivileged_user_login_truncated} did not match anything");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We now append "*". Due to confirmuniqueusermatch = 1, a confirmation page
# must be displayed.

$sel->type_ok("newcc", "$config->{unprivileged_user_login_truncated}*");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Confirm Match");
$sel->is_text_present_ok("<$config->{unprivileged_user_login}>");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We now type a complete and valid email address. The confirmation should not
# be displayed, despite confirmuniqueusermatch = 1.

$sel->type_ok("newcc", $config->{unprivileged_user_login});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $test_bug_1 processed");

$sel->click_ok("link=bug $test_bug_1");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# This will return more than one account.

$sel->type_ok("newcc", "*$config->{common_email}");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Confirm Match");
$sel->is_text_present_ok("*$config->{common_email} matched:");

# Now enable the 'search' mode, with a restrictive value for 'maxusermatches'.

set_parameters($sel, { "User Matching" => {"usermatchmode"  => {type => 'select', value => 'search'},
                                           "maxusermatches" => {type => 'text', value => '1'}}
                     });

$sel->type_ok("quicksearch_top", $test_bug_1);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We type an incomplete email address, with no wildcard, but this should work.

$sel->type_ok("newcc", $config->{unprivileged_user_login_truncated});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Confirm Match");
$sel->is_text_present_ok("<$config->{unprivileged_user_login}>");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# Several user accounts match this partial email address. Due to
# maxusermatches = 1, no email address is suggested.

$sel->type_ok("newcc", "*$config->{common_email}");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Match Failed");
$sel->is_text_present_ok("matches multiple users");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We now type a complete and valid email address, so no confirmation
# page should be displayed.

$sel->type_ok("newcc", $config->{unprivileged_user_login});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $test_bug_1 processed");

# Now turn on group visibility. It involves important security checks.

set_parameters($sel, { "User Matching"  => {"maxusermatches" => {type => 'text', value => '2'}},
                       "Group Security" => {"usevisibilitygroups-on" => undef}
                     });

# By default, groups are not visible to themselves, so we have to enable this.
# The tweakparams user has not enough privs to do it himself.

logout($sel);
log_in($sel, $config, 'admin');
go_to_admin($sel);
$sel->click_ok("link=Groups");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Edit Groups");
$sel->click_ok("link=tweakparams");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Change Group: tweakparams");

my @groups = $sel->get_select_options("visible_from_add");
if (grep {$_ eq 'tweakparams'} @groups) {
    $sel->add_selection_ok("visible_from_add", "label=tweakparams");
    $sel->click_ok('//input[@value="Update Group"]');
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Change Group: tweakparams");
}
logout($sel);
log_in($sel, $config, 'tweakparams');

$sel->type_ok("quicksearch_top", $test_bug_1);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We are not in the same groups as the unprivileged user, so we cannot see him.

$sel->type_ok("newcc", $config->{unprivileged_user_login_truncated});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Match Failed");
$sel->is_text_present_ok("$config->{unprivileged_user_login_truncated} did not match anything");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# This will return too many users (there are at least always three:
# you, the admin and the permanent user (who has admin privs too)).

$sel->type_ok("newcc", $config->{common_email});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Confirm Match");
$sel->is_text_present_ok("$config->{common_email} matched more than the maximum of 2 users");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");

# We can always see ourselves.

$sel->type_ok("newcc", $config->{tweakparams_user_login_truncated});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Confirm Match");
$sel->is_text_present_ok("<$config->{tweakparams_user_login}>");

# Now test user menus. It must NOT display users we are not allowed to see.

set_parameters($sel, { "User Matching" => {"usemenuforusers-on" => undef} });

$sel->type_ok("quicksearch_top", $test_bug_1);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_like(qr/^Bug $test_bug_1/);
$sel->click_ok("cc_edit_area_showhide");
my @cc = $sel->get_select_options("newcc");
ok(!grep($_ =~ /$config->{unprivileged_user_login}/, @cc), "$config->{unprivileged_user_login} is not visible");
ok(!grep($_ =~ /$config->{canconfirm_user_login}/, @cc), "$config->{canconfirm_user_login} is not visible");
ok(grep($_ =~ /$config->{admin_user_login}/, @cc), "$config->{admin_user_login} is visible");
ok(grep($_ =~ /$config->{tweakparams_user_login}/, @cc), "$config->{tweakparams_user_login} is visible");

# Reset paramters.

set_parameters($sel, { "User Matching"  => {"usemenuforusers-off" => undef,
                                            "maxusermatches"      => {type => 'text', value => '0'},
                                            "confirmuniqueusermatch-off" => undef},
                       "Group Security" => {"usevisibilitygroups-off" => undef}
                     });
logout($sel);
