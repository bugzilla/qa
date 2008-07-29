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

$sel->open_ok("/$config->{bugzilla_installation}/long_list.cgi?id=1");
$sel->title_is("Full Text Bug Listing", "Display bug as format for printing");
my $text = $sel->get_text("//h1");
$text =~ s/[\r\n\t\s]+/ /g;
is($text, 'Bug 1', 'Display bug 1 specifically');
