use strict;
use warnings;
use Test::WWW::Selenium;
use Test::More "no_plan";

my $conf_file = "../config/selenium_test.conf";

# read the test configuration file
my $config = do "$conf_file"
    or die "can't read configuration '$conf_file': $!$@";

my $sel = Test::WWW::Selenium->new(
    host        => $config->{host},
    browser     => $config->{browser},
    browser_url => $config->{browser_url}
);

# TODO: This test really needs improvement. There is by far much more stuff
# to test in this area.

# First, a very trivial search, which returns no result.

$sel->open_ok("/$config->{bugzilla_installation}/query.cgi?format=advanced");
$sel->title_is("Search for bugs", "Display the Advanced Query Form");
$sel->type_ok("short_desc", "justdave", "Type a non-existent string in the bug summary field");
$sel->click_ok("Search", undef, "Start search");
$sel->wait_for_page_to_load(30000);
$sel->title_is("Bug List", "Display buglist");
$sel->is_text_present_ok("Zarro Boogs found.", undef, "0 bugs found");

# Display all available columns. Look for all bugs assigned to a user who doesn't exist.

$sel->open_ok("/$config->{bugzilla_installation}/buglist.cgi?quicksearch=%40xx45ft&columnlist=all");
$sel->title_is("Bug List", "Display buglist");
$sel->is_text_present_ok("Zarro Boogs found.", undef, "0 bugs found");
