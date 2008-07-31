use strict;
use warnings;
use Test::WWW::Selenium;
use Test::More "no_plan";

my $conf_file = "selenium_test.conf";

# read the test configuration file
my $config = do "$conf_file"
    or die "can't read configuration '$conf_file': $!$@";

my $sel = Test::WWW::Selenium->new(
    host        => $config->{host},
    browser     => $config->{browser},
    browser_url => $config->{browser_url}
);

# Very simple test script to test if bug creation with minimal data passes successfully.
# More elaborated tests exist in other scripts. This doesn't mean this one could not
# be improved a bit.
$sel->open_ok("/$config->{bugzilla_installation}/");
$sel->type_ok("Bugzilla_login", $config->{admin_user_login}, "Enter admin login name");
$sel->type_ok("Bugzilla_password", $config->{admin_user_passwd}, "Enter admin password");
$sel->click_ok("log_in", undef, "Submit credentials");
$sel->wait_for_page_to_load(30000);
# Typing the URL directly lets us avoid the "Choose Classification" page in case
# useclassifications is on. Classifications are use in another script anyway.
$sel->open_ok("/$config->{bugzilla_installation}/enter_bug.cgi?product=TestProduct");
$sel->title_is("Enter Bug: TestProduct", "Display enter_bug.cgi for the selected product (bypass classifications)");
$sel->type_ok("short_desc", "Bug created by Selenium", "Enter bug summary");
$sel->type_ok("comment", "--- Bug created by Selenium ---", "Enter bug description");
$sel->click_ok("commit", undef, "Submit bug data to post_bug.cgi");
$sel->wait_for_page_to_load(30000);
ok($sel->get_title() =~ /Bug \d+ Submitted/, "Bug created");
