use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# Very simple test script to test if bug creation with minimal data 
# passes successfully for different user privileges.
#
# More elaborate tests exist in other scripts. This doesn't mean this
# one could not be improved a bit.

my $bug_summary = "Bug created by Selenium";
foreach my $user (qw(admin unprivileged canconfirm)) {
    log_in($sel, $config, $user);
    file_bug_in_product($sel, "TestProduct");
    $sel->type_ok("short_desc", $bug_summary, "Enter bug summary");
    $sel->type_ok("comment", "--- Bug created by Selenium ---", "Enter bug description");
    create_bug($sel, $bug_summary);
    logout($sel);
}
