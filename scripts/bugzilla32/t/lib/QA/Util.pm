# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::Util;

use strict;
use Data::Dumper;
use HTTP::Cookies;
use Test::More;
use Test::WWW::Selenium;
use WWW::Selenium::Util qw(server_is_running);
use XMLRPC::Lite;

use base qw(Exporter);
@QA::Util::EXPORT = qw(
    trim
    log_in
    file_bug_in_product
    edit_product
    open_advanced_search_page

    get_selenium
    get_xmlrpc_client

    xmlrpc_log_in
    xmlrpc_call_success
    xmlrpc_call_fail

    WAIT_TIME
);

# How long we wait for pages to load.
use constant WAIT_TIME => 30000;
use constant CONF_FILE =>  "../config/selenium_test.conf";

# Remove consecutive as well as leading and trailing whitespaces.
sub trim {
    my ($str) = @_;
    if ($str) {
      $str =~ s/[\r\n\t\s]+/ /g;
      $str =~ s/^\s+//g;
      $str =~ s/\s+$//g;
    }
    return $str;
}

###################
# Setup Functions #
###################

sub get_config {
    # read the test configuration file
    my $conf_file = CONF_FILE;
    my $config = do($conf_file)
        or die "can't read configuration '$conf_file': $!$@";
}

sub get_selenium {
    my $config = get_config();

    if (!server_is_running) {
        die "Selenium Server isn't running!";
    }

    my $sel = Test::WWW::Selenium->new(
        host        => $config->{host},
        browser     => $config->{browser},
        browser_url => $config->{browser_url}
    );

    return ($sel, $config);
}

sub get_xmlrpc_client {
    my $config = get_config();
    my $xmlrpc_url = $config->{browser_url} . "/"
                    . $config->{bugzilla_installation} . "/xmlrpc.cgi";


    # A temporary cookie jar that isn't saved after the script closes.
    my $cookie_jar = new HTTP::Cookies({});
    my $rpc        = new XMLRPC::Lite(proxy => $xmlrpc_url);
    $rpc->transport->cookie_jar($cookie_jar);
    return ($rpc, $config);
}

###############################
# Helpers for XML-RPC scripts #
###############################

sub xmlrpc_log_in {
    my ($rpc, $config, $user) = @_;
    my $username = $config->{"${user}_user_login"};
    my $password = $config->{"${user}_user_passwd"};

    my $call = xmlrpc_call_success($rpc, 'User.login', 
                                { login => $username, password => $password });
    cmp_ok($call->result->{id}, 'gt', 0,
           'Logged in with an id greater than 0.');

    # Save the cookies in the cookie file
    $rpc->transport->cookie_jar->extract_cookies(
        $rpc->transport->http_response);
    $rpc->transport->cookie_jar->save;
}

sub xmlrpc_call_success {
    my ($rpc, $method, $args) = @_;
    my $call = $rpc->call($method, $args);
    ok(!defined $call->fault, "$method returned successfully")
        or diag($call->faultstring);
    return $call;
}

sub xmlrpc_call_fail {
    my ($rpc, $method, $args) = @_;
    my $call = $rpc->call($method, $args);
    ok(defined $call->fault, "$method failed (as intended)")
        or diag("Returned: " . Dumper($call->result));
    return $call;
}

################################
# Helpers for Selenium Scripts #
################################

# Go to the home/login page and log in.
sub log_in {
    my ($sel, $config, $user) = @_;

    $sel->open_ok("/$config->{bugzilla_installation}/", undef, "Go to the login page");
    $sel->type_ok("Bugzilla_login", $config->{"${user}_user_login"}, "Enter $user login name");
    $sel->type_ok("Bugzilla_password", $config->{"${user}_user_passwd"}, "Enter $user password");
    $sel->click_ok("log_in", undef, "Submit credentials");
    $sel->wait_for_page_to_load(WAIT_TIME);
    $sel->title_is("Bugzilla Main Page", "User is logged in");
}

# Display the bug form to enter a bug in the given product.
sub file_bug_in_product {
    my ($sel, $product, $classification) = @_;

    $classification ||= "Unclassified";
    $sel->click_ok("link=New", undef, "Go create a new bug");
    $sel->wait_for_page_to_load(WAIT_TIME);
    my $title = $sel->get_title();
    if ($title eq "Select Classification") {
        ok(1, "More than one enterable classification available. Display them in a list");
        $sel->click_ok("link=$classification", undef, "Choose $classification");
        $sel->wait_for_page_to_load(WAIT_TIME);
    }
    else {
        $sel->title_is("Enter Bug", "Display the list of enterable products");
    }
    $sel->click_ok("link=$product", undef, "Choose $product");
    $sel->wait_for_page_to_load(WAIT_TIME);
    $sel->title_is("Enter Bug: $product", "Display form to enter bug data");
}

# Go to editproducts.cgi and display the given product.
sub edit_product {
    my ($sel, $product, $classification) = @_;

    $classification ||= "Unclassified";
    $sel->click_ok("link=Administration", undef, "Go to the Admin page");
    $sel->wait_for_page_to_load(WAIT_TIME);
    $sel->title_like(qr/^Administer your installation/, "Display admin.cgi");
    $sel->click_ok("link=Products", undef, "Go to the Products page");
    $sel->wait_for_page_to_load(WAIT_TIME);
    my $title = $sel->get_title();
    if ($title eq "Select Classification") {
        ok(1, "More than one enterable classification available. Display them in a list");
        $sel->click_ok("link=$classification", undef, "Choose $classification");
        $sel->wait_for_page_to_load(WAIT_TIME);
    }
    else {
        $sel->title_is("Select product", "Display the list of enterable products");
    }
    $sel->click_ok("link=$product", undef, "Choose $product");
    $sel->wait_for_page_to_load(WAIT_TIME);
    $sel->title_is("Edit Product '$product'", "Display properties of $product");
}

sub open_advanced_search_page {
    my $sel = shift;

    $sel->click_ok("link=Search");
    $sel->wait_for_page_to_load(WAIT_TIME);
    my $title = $sel->get_title();
    if ($title eq "Find a Specific Bug") {
        ok(1, "Display the basic search form");
        $sel->click_ok("link=Advanced Search");
        $sel->wait_for_page_to_load(WAIT_TIME);
    }
    $sel->title_is("Search for bugs", "Display the Advanced search form");
}

1;

__END__
