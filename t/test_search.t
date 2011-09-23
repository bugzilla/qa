use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use Test::More "no_plan";

my ($sel, $config) = get_selenium();

# TODO: This test really needs improvement. There is by far much more stuff
# to test in this area.

# First, a very trivial search, which returns no result.

go_to_home($sel, $config);
open_advanced_search_page($sel);
$sel->type_ok("short_desc", "ois£jdfm#sd%fasd!fm", "Type a non-existent string in the bug summary field");
$sel->click_ok("Search");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Bug List");
$sel->is_text_present_ok("Zarro Boogs found");

# Display all available columns. Look for all bugs assigned to a user who doesn't exist.

$sel->open_ok("/$config->{bugzilla_installation}/buglist.cgi?quicksearch=%40xx45ft&columnlist=all");
$sel->title_is("Bug List");
$sel->is_text_present_ok("Zarro Boogs found");

# Now some real tests.

log_in($sel, $config, 'canconfirm');
file_bug_in_product($sel, "TestProduct");
my $bug_summary = "Update this summary with this bug ID";
$sel->type_ok("short_desc", $bug_summary);
$sel->type_ok("comment", "I'm supposed to appear in the coming buglist.");
my $bug1_id = create_bug($sel, $bug_summary);
$sel->click_ok("editme_action");
$bug_summary .= ": my ID is $bug1_id";
$sel->type_ok("short_desc", $bug_summary);
$sel->type_ok("comment", "Updating bug summary....");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug1_id processed");

# Test pronoun substitution.

open_advanced_search_page($sel);
$sel->remove_all_selections("bug_status");
$sel->remove_all_selections("resolution");
$sel->type_ok("short_desc", "my ID is $bug1_id");
$sel->select_ok("field0-0-0", "label=Commenter");
$sel->select_ok("type0-0-0", "label=is equal to");
$sel->type_ok("value0-0-0", "%user%");
$sel->click_ok("cmd-add0-1-0");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search for bugs");
$sel->select_ok("field0-1-0", "label=Comment");
$sel->select_ok("type0-1-0", "label=contains the string");
$sel->type_ok("value0-1-0", "coming buglist");
$sel->click_ok("Search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List");
$sel->is_text_present_ok("One bug found");
$sel->is_text_present_ok("Update this summary with this bug ID: my ID is $bug1_id");
logout($sel);
