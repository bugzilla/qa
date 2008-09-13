use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();


my $test_bug_1 = $config->{test_bug_1};
my $test_bug_2 = $config->{test_bug_2};

# Create keywords. Do some cleanup first if necessary.

log_in($sel, $config, 'admin');
$sel->click_ok("link=Administration", undef, "Go to the Admin page");
$sel->wait_for_page_to_load(30000);
$sel->title_like(qr/^Administer your installation/, "Display admin.cgi");
$sel->click_ok("link=Keywords");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Select keyword");

# If keywords already exist, delete them to not disturb the test.

my $page = $sel->get_body_text();
my @keywords = $page =~ m/(key-selenium-\w+)/gi;

foreach my $keyword (@keywords) {
    my $url = $sel->get_attribute("link=$keyword\@href");
    $url =~ s/action=edit/action=delete/;
    $sel->click_ok("//a[\@href='$url']");
    $sel->wait_for_page_to_load(30000);
    my $title = $sel->get_title();
    if ($title eq 'Delete Keyword') {
        ok(1, "Keywords used in bugs; asking for keyword deletion");
        $sel->click_ok("delete");
        $sel->wait_for_page_to_load(30000);
    }
    $sel->title_is("Keyword Deleted");
}
# Even if no keyword has been deleted, make sure the cache is right.
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?rebuildkeywordcache=1");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Sanity Check");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");

# Now let's create our first keyword.

$sel->click_ok("link=Administration");
$sel->wait_for_page_to_load(30000);
$sel->title_like(qr/^Administer your installation/, "Display admin.cgi");
$sel->click_ok("link=Keywords");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Select keyword");
$sel->click_ok("link=Add a new keyword");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Add keyword");
$sel->type_ok("name", "key-selenium-kone");
$sel->type_ok("description", "Hopefully an ice cream");
$sel->click_ok("create");
$sel->wait_for_page_to_load(30000);
$sel->title_is("New Keyword Created");

# Try create the same keyword, to check validators.

$sel->click_ok("link=Add a new keyword");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Add keyword");
$sel->type_ok("name", "key-selenium-kone");
$sel->type_ok("description", "FIX ME!");
$sel->click_ok("create");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Keyword Already Exists");
my $error_msg = trim($sel->get_text("error_msg"));
ok($error_msg eq 'A keyword with the name key-selenium-kone already exists.', 'Already created keyword');
$sel->go_back_ok();
$sel->wait_for_page_to_load(30000);

# Create a second keyword.

$sel->type_ok("name", "key-selenium-ktwo");
$sel->type_ok("description", "FIX ME!");
$sel->click_ok("create");
$sel->wait_for_page_to_load(30000);
$sel->title_is("New Keyword Created");

# Again test validators.

$sel->click_ok("link=key-selenium-ktwo");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Edit keyword");
$sel->type_ok("name", "key-selenium-kone");
$sel->type_ok("description", "the second keyword");
$sel->click_ok("update");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Keyword Already Exists");
$error_msg = trim($sel->get_text("error_msg"));
ok($error_msg eq 'A keyword with the name key-selenium-kone already exists.', 'Already created keyword');
$sel->go_back_ok();
$sel->wait_for_page_to_load(30000);
$sel->title_is("Edit keyword");
$sel->type_ok("name", "key-selenium-ktwo");
$sel->click_ok("update");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Keyword Updated");

# Add keywords to bugs

$sel->type_ok("quicksearch_top", $test_bug_1);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(30000);
$sel->title_like(qr/^Bug $test_bug_1/, "Display bug $test_bug_1");
$sel->click_ok("keywords");
$sel->add_selection_ok("keyword-list", "label=key-selenium-kone");
$sel->click_ok("//button[\@onclick=\"document.getElementById('keyword-chooser').chooserElement.chooser.choose(); return false;\"]", undef, "Add selected keyword to the list");
$sel->click_ok("//button[\@type='button']", undef, "Confirm new keyword");
$sel->click_ok("commit");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug $test_bug_1 processed");
$sel->is_text_present_ok("Changes submitted");
$sel->type_ok("quicksearch_top", $test_bug_2);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load(30000);
$sel->title_like(qr/^Bug $test_bug_2/, "Display bug $test_bug_2");
$sel->add_selection_ok("keyword-list", "label=key-selenium-kone");
$sel->add_selection_ok("keyword-list", "label=key-selenium-ktwo");
$sel->click_ok("//button[\@onclick=\"document.getElementById('keyword-chooser').chooserElement.chooser.choose(); return false;\"]", undef, "Add selected keywords to the list");
$sel->click_ok("//button[\@type='button']", undef, "Confirm new keywords");
$sel->click_ok("commit");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug $test_bug_2 processed");
$sel->is_text_present_ok("Changes submitted");

# Now make sure these bugs correctly appear in buglists.

$sel->click_ok("link=Search");
$sel->wait_for_page_to_load(30000);
my $title = $sel->get_title();
if ($title eq "Find a Specific Bug") {
    ok(1, "Display the basic search form");
    $sel->click_ok("link=Advanced Search");
    $sel->wait_for_page_to_load(30000);
}
$sel->title_is("Search for bugs", "Display the Advanced search form");
$sel->remove_all_selections("product");
$sel->remove_all_selections("bug_status");
$sel->type_ok("keywords", "key-selenium-kone");
$sel->click_ok("Search");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug List");
$sel->is_text_present_ok("2 bugs found");

$sel->click_ok("link=Search");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Search for bugs");
$sel->remove_all_selections("product");
$sel->remove_all_selections("bug_status");
# Try with a different case than the one in the DB.
$sel->type_ok("keywords", "key-selenium-ktWO");
$sel->click_ok("Search");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug List");
$sel->is_text_present_ok("One bug found");

$sel->click_ok("link=Search");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Search for bugs");
$sel->remove_all_selections("product");
$sel->remove_all_selections("bug_status");
# Bugzilla doesn't allow substrings for keywords.
$sel->type_ok("keywords", "selenium");
$sel->click_ok("Search");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Unknown Keyword");
$sel->is_text_present_ok("selenium is not a known keyword");

# Make sure describekeywords.cgi works as expected.

$sel->click_ok("link=listed here");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bugzilla Keyword Descriptions");
$sel->is_text_present_ok("key-selenium-kone");
$sel->is_text_present_ok("Hopefully an ice cream");
$sel->is_text_present_ok("key-selenium-ktwo");
$sel->is_text_present_ok("the second keyword");
$sel->click_ok('//a[@href="buglist.cgi?keywords=key-selenium-kone"]');
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug List");
$sel->is_element_present_ok("link=$test_bug_1");
$sel->is_element_present_ok("link=$test_bug_2");
$sel->is_text_present_ok("2 bugs found");
$sel->go_back_ok();
$sel->wait_for_page_to_load(30000);
$sel->click_ok('//a[@href="buglist.cgi?keywords=key-selenium-ktwo"]');
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug List");
$sel->is_element_present_ok("link=$test_bug_2");
$sel->is_text_present_ok("One bug found");
$sel->open_ok("/$config->{bugzilla_installation}/relogin.cgi", undef, "Logout");
