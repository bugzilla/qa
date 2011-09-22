use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium(CHROME_MODE);
my $urlbase = $config->{bugzilla_installation};
my $admin_user = $config->{admin_user_login};

#######################################################################
# Security bug 472362.
#######################################################################

log_in($sel, $config, 'admin');
$sel->click_ok("link=Preferences");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Preferences");
my $admin_cookie = $sel->get_value("token");
logout($sel);

log_in($sel, $config, 'editbugs');
$sel->click_ok("link=Preferences");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Preferences");
my $editbugs_cookie = $sel->get_value("token");

# Using our own unused token is fine.

$sel->open_ok("/$urlbase/userprefs.cgi?dosave=1&display_quips=off&token=$editbugs_cookie");
$sel->title_is("User Preferences");
$sel->is_text_present_ok("The changes to your general preferences have been saved");

# Reusing a token must fail. They must all trigger the Suspicious Action warning.

my @args = ("", "token=", "token=i123x", "token=$admin_cookie", "token=$editbugs_cookie");

foreach my $arg (@args) {
    $sel->open_ok("/$urlbase/userprefs.cgi?dosave=1&display_quips=off&$arg");
    $sel->title_is("Suspicious Action");

    if ($arg eq "token=$admin_cookie") {
        $sel->is_text_present_ok("Generated by: admin <$admin_user>");
        $sel->is_text_present_ok("This token has not been generated by you");
    }
    else {
        $sel->is_text_present_ok("It looks like you didn't come from the right page");
    }
}
logout($sel);

#######################################################################
# Security bug 472206.
# Keep this test as the very last one as the File Saver will remain
# open till the end of the script. Selenium is currently* unable
# to interact with it and close it (* = 2.6.0).
#######################################################################

log_in($sel, $config, 'admin');
set_parameters($sel, { "Attachments" => {"allow_attachment_display-off" => undef} });

file_bug_in_product($sel, "TestProduct");
my $bug_summary = "Security checks";
$sel->type_ok("short_desc", $bug_summary);
$sel->type_ok("comment", "This bug will be used to test security fixes.");
$sel->type_ok("data", "/var/www/html/selenium/bugzilla/patch.diff");
$sel->type_ok("description", "simple patch, v1");
$sel->click_ok("ispatch");
$sel->click_ok('commit');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
my $bug1_id = $sel->get_value('//input[@name="id" and @type="hidden"]');
$sel->title_like(qr/Bug $bug1_id /, "Bug $bug1_id created");

# Attachments are not viewable.

$sel->click_ok("link=Details");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Attachment \d+ Details for Bug $bug1_id/);
$sel->is_text_present_ok("The attachment is not viewable in your browser due to security restrictions");
$sel->click_ok("link=View");
# Wait 1 second to give the browser a chance to display the attachment.
# Do not use wait_for_page_to_load_ok() as the File Saver will never go away.
sleep(1);
$sel->title_like(qr/Attachment \d+ Details for Bug $bug1_id/);
ok(!$sel->is_text_present('@@'), "Patch not displayed");

# Enable viewing attachments.

set_parameters($sel, { "Attachments" => {"allow_attachment_display-on" => undef} });

go_to_bug($sel, $bug1_id);
$sel->click_ok('link=simple patch, v1');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("");
$sel->is_text_present_ok('@@');
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug $bug1_id /);
logout($sel);
