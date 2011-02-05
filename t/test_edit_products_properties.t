use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

my $admin_user_login = $config->{admin_user_login};
my $unprivileged_user_login = $config->{unprivileged_user_login};
my $permanent_user = $config->{permanent_user};

log_in($sel, $config, 'admin');
set_parameters($sel, { "Bug Fields"              => {"useclassification-off" => undef,
                                                     "usetargetmilestone-on" => undef},
                       "Administrative Policies" => {"allowbugdeletion-on"   => undef}
                     });

# Create a product and add components to it. Do some cleanup first
# if the script failed during a previous run.

go_to_admin($sel);
$sel->click_ok("link=Products");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
# No risk to get the "Select classification" page. We turned off useclassification.
$sel->title_is("Select product");

my $text = trim($sel->get_text("bugzilla-body"));
if ($text =~ /(Kill me!|Kill me nicely)/) {
    my $product = $1;
    my $escaped_product = url_quote($product);
    $sel->click_ok("//a[contains(\@href, '  editproducts.cgi?action=del&product=$escaped_product')]");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Delete Product '$product'");
    $sel->click_ok("delete");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Product Deleted");
}

$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add Product");
$sel->type_ok("product", "Kill me!");
$sel->type_ok("description", "I will disappear very soon. Do not add bugs to it.");
$sel->type_ok("defaultmilestone", "0.1a");
$sel->type_ok("votesperuser", "1");
$sel->type_ok("maxvotesperbug", "1");
$sel->type_ok("votestoconfirm", "10");
$sel->type_ok("version", "0.1a");
$sel->click_ok("//input[\@value='Add']");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$text = trim($sel->get_text("message"));
ok($text =~ /You will need to add at least one component before anyone can enter bugs against this product/,
   "Display a reminder about missing components");
$sel->click_ok("link=add at least one component");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add component to the Kill me! product");
$sel->type_ok("component", "first comp");
$sel->type_ok("description", "comp 1");
$sel->type_ok("initialowner", $admin_user_login);
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Component Created");
$text = trim($sel->get_text("message"));
ok($text eq 'The component first comp has been created.', "Component successfully created");

# Try creating a second component with the same name.

$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add component to the Kill me! product");
$sel->type_ok("component", "first comp");
$sel->type_ok("description", "comp 2");
$sel->type_ok("initialowner", $admin_user_login);
$sel->type_ok("initialcc", $permanent_user);
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Component Already Exists");

# Now really create a second component, with a distinct name.

$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->type_ok("component", "second comp");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Component Created");

# Add a new version.

edit_product($sel, "Kill me!");
$sel->click_ok("//a[contains(text(),'Edit\nversions:')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select version of product 'Kill me!'");
$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->type_ok("version", "0.1");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Version Created");

# Add a new milestone.

$sel->click_ok("link='Kill me!'");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit Product 'Kill me!'");
$sel->click_ok("link=Edit milestones:");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select milestone of product 'Kill me!'");
$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add Milestone to Product 'Kill me!'");
$sel->type_ok("milestone", "0.2");
$sel->type_ok("sortkey", "2");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Milestone Created");

# Add another milestone.

$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add Milestone to Product 'Kill me!'");
$sel->type_ok("milestone", "0.1a");
# Negative sortkeys are valid for milestones.
$sel->type_ok("sortkey", "-2");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Milestone Already Exists");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->type_ok("milestone", "pre-0.1");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Milestone Created");

# Now create an UNCONFIRMED bug and add it to the newly created product.

file_bug_in_product($sel, "Kill me!");
$sel->select_ok("version", "label=0.1a");
$sel->select_ok("component", "label=first comp");
# UNCONFIRMED must be present.
$sel->select_ok("bug_status", "label=UNCONFIRMED");
$sel->type_ok("cc", $unprivileged_user_login);
$sel->type_ok("bug_file_loc", "http://www.test.com");
$sel->type_ok("short_desc", "test create/edit product properties");
$sel->type_ok("comment", "this bug will soon be dead");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug \d+ Submitted/);
my $bug1_id = $sel->get_value("//input[\@name='id' and \@type='hidden']");
my @cc_list = $sel->get_select_options("cc");
ok(grep($_ eq $unprivileged_user_login, @cc_list), "$unprivileged_user_login correctly added to the CC list");
ok(!grep($_ eq $permanent_user, @cc_list), "$permanent_user not in the CC list for 'first comp' by default");

# File a second bug, and make sure users in the default CC list are added.
file_bug_in_product($sel, "Kill me!");
$sel->select_ok("version", "label=0.1a");
$sel->select_ok("component", "label=second comp");
$sel->type_ok("short_desc", "check default CC list");
$sel->type_ok("comment", "is the CC list populated correctly?");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug \d+ Submitted/);
@cc_list = $sel->get_select_options("cc");
ok(grep($_ eq $permanent_user, @cc_list), "$permanent_user in the CC list for 'second comp' by default");

# Edit product properties and set votes_to_confirm to 0, which has
# the side-effect to confirm the UNCONFIRMED bug above.

edit_product($sel, "Kill me!");
$sel->type_ok("product", "Kill me nicely");
$sel->type_ok("description", "I will disappear very soon. Do not add bugs to it (except for testing).");
$sel->select_ok("defaultmilestone", "label=0.2");
$sel->type_ok("votesperuser", "2");
$sel->type_ok("votestoconfirm", "0");
$sel->click_ok("submit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Updating Product 'Kill me nicely'");
$sel->is_text_present_ok("Updated product name from 'Kill me!' to 'Kill me nicely'");
$sel->is_text_present_ok("Updated description");
$sel->is_text_present_ok("Updated default milestone");
$sel->is_text_present_ok("Updated votes per user");
$sel->is_text_present_ok("Updated number of votes needed to confirm a bug");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /Checking unconfirmed bugs in this product for any which now have sufficient votes/,
   "Checking for UNCO bugs with now enough votes");
ok($text =~ /Bug $bug1_id confirmed by number of votes/, "One bug confirmed by popular votes");

# Edit the bug.

$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id /);
$sel->selected_label_is("product", "Kill me nicely");
$sel->selected_label_is("bug_status", "NEW");
$sel->select_ok("target_milestone", "label=pre-0.1");
$sel->select_ok("component", "label=second comp");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug1_id processed");
$sel->click_ok("link=bug $bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug $bug1_id /);
@cc_list = $sel->get_select_options("cc");
ok(grep($_ eq $permanent_user, @cc_list), "User $permanent_user automatically added to the CC list");

# Delete the milestone the bug belongs to. This should retarget the bug
# to the default milestone.

edit_product($sel, "Kill me nicely");
$sel->click_ok("link=Edit milestones:");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select milestone of product 'Kill me nicely'");
$sel->click_ok('//a[@href="editmilestones.cgi?action=del&product=Kill%20me%20nicely&milestone=pre-0.1"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete Milestone of Product 'Kill me nicely'");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /There is 1 bug entered for this milestone/, "Warning displayed");
ok($text =~ /Do you really want to delete this milestone\?/, "Requesting confirmation");
$sel->click_ok("delete");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Milestone Deleted");
$text = trim($sel->get_text("message"));
ok($text =~ /Bugs targetted to this milestone have been retargetted to the default milestone/, "Bug retargetted");

# Try deleting the version used by the bug. This action must be rejected.

$sel->click_ok("link='Kill me nicely'");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit Product 'Kill me nicely'");
$sel->click_ok("//a[contains(text(),'Edit\nversions:')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select version of product 'Kill me nicely'");
$sel->click_ok("//a[contains(\@href, 'editversions.cgi?action=del&product=Kill%20me%20nicely&version=0.1a')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete Version of Product 'Kill me nicely'");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /Sorry, there are 2 bugs outstanding for this version/, "Rejecting version deletion");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);

# Delete an unused version. The action must succeed.

$sel->click_ok('//a[@href="editversions.cgi?action=del&product=Kill%20me%20nicely&version=0.1"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete Version of Product 'Kill me nicely'");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /Do you really want to delete this version\?/, "Requesting confirmation");
$sel->click_ok("delete");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Version Deleted");

# Delete the component the bug belongs to. The action must succeed.

$sel->click_ok("link='Kill me nicely'");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit Product 'Kill me nicely'");
$sel->click_ok("link=Edit components:");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select component of product 'Kill me nicely'");
$sel->click_ok("//a[contains(\@href, 'editcomponents.cgi?action=del&product=Kill%20me%20nicely&component=second%20comp')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete component 'second comp' from 'Kill me nicely' product");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /There are 2 bugs entered for this component/, "Warning displayed");
ok($text =~ /Do you really want to delete this component\?/, "Requesting confirmation");
$sel->click_ok("delete");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Component Deleted");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /The component second comp has been deleted/, "Component deletion confirmed");
ok($text =~ /All bugs being in this component and all references to them have also been deleted/,
   "Bug deletion confirmed");

# Only one value for component, version and milestone available. They should
# be selected by default.

file_bug_in_product($sel, "Kill me nicely");
$sel->type_ok("short_desc", "bye bye everybody!");
$sel->type_ok("comment", "I'm dead :(");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);

# Now delete the product.

go_to_admin($sel);
$sel->click_ok("link=Products");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select product");
$sel->click_ok("//a[contains(\@href, '  editproducts.cgi?action=del&product=Kill%20me%20nicely')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete Product 'Kill me nicely'");
$text = trim($sel->get_text("bugzilla-body"));
ok($text =~ /There is 1 bug entered for this product/, "Warning displayed");
ok($text =~ /Do you really want to delete this product\?/, "Confirmation request displayed");
$sel->click_ok("delete");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Product Deleted");
logout($sel);
