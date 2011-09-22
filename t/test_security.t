use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

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
