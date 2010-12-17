# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::RPC;
use strict;
use Data::Dumper;
use QA::Util;
use QA::Tests qw(PRIVATE_BUG_USER create_bug_fields);
use Storable qw(dclone);
use Test::More;

sub bz_config {
    my $self = shift;
    $self->{bz_config} ||= QA::Util::get_config();
    return $self->{bz_config}; 
}

# True if we're doing calls over GET instead of POST.
sub bz_get_mode { return 0 }

# When doing bz_log_in over GET, we can't actually call User.login,
# we just store credentials here and then pass them as Bugzilla_login
# and Bugzilla_password with every future call until User.logout is called
# (which actually just calls _bz_clear_credentials, under GET).
sub _bz_credentials {
    my ($self, $user, $pass) = @_;
    if (@_ == 3) {
        $self->{_bz_credentials}->{user} = $user;
        $self->{_bz_credentials}->{pass} = $pass;
    }
    return $self->{_bz_credentials};
}
sub _bz_clear_credentials { delete $_[0]->{_bz_credentials} }

################################
# Helpers for RPC test scripts #
################################

sub bz_log_in {
    my ($self, $user) = @_;
    my $username = $self->bz_config->{"${user}_user_login"};
    my $password = $self->bz_config->{"${user}_user_passwd"};

    if ($self->bz_get_mode) {
        $self->_bz_credentials($username, $password);
        return;
    }

    my $call = $self->bz_call_success(
        'User.login', { login => $username, password => $password });
    cmp_ok($call->result->{id}, 'gt', 0, $self->TYPE . ": Logged in as $user");

    # Save the cookies in the cookie file
    $self->transport->cookie_jar->extract_cookies(
        $self->transport->http_response);
    $self->transport->cookie_jar->save;
}

sub bz_call_success {
    my ($self, $method, $args, $test_name) = @_;

    if ($self->bz_get_mode and $method eq 'User.logout') {
        $self->_bz_clear_credentials();
        return;
    }

    my $call;
    # Under XMLRPC::Lite, if we pass undef as the second argument,
    # it sends a single param <value />, which shows up as an
    # empty string on the Bugzilla side.
    if ($args) {
        $call = $self->call($method, $args);
    }
    else {
        $call = $self->call($method);
    }
    $test_name ||= "$method returned successfully";
    $self->_handle_undef_response($test_name) if !$call;
    ok(!$call->fault, $self->TYPE . ": $test_name")
        or diag($call->faultstring);
    return $call;
}

sub bz_call_fail {
    my ($self, $method, $args, $faultstring, $test_name) = @_;
    $test_name ||= "$method failed (as intended)";
    my $call = $self->call($method, $args);
    $self->_handle_undef_response($test_name) if !$call;
    ok($call->fault, $self->TYPE . ": $test_name")
        or diag("Returned: " . Dumper($call->result));
    if (defined $faultstring) {
        cmp_ok(trim($call->faultstring), '=~', $faultstring, 
               $self->TYPE . ": Got correct fault for $method");
    }
    ok($call->faultcode 
       && (($call->faultcode < 32000 && $call->faultcode > -32000) 
           # Fault codes 32610 and above are OK because they are errors
           # that we expect and test for sometimes.
           || $call->faultcode >= 32610), 
       $self->TYPE . ': Fault code is set properly')
        or diag("Code: " . $call->faultcode 
                . " Message: " . $call->faultstring);

    return $call;
}

sub _handle_undef_response {
    my ($self, $test_name) = @_;
    my $response = $self->transport->http_response;
    die "$test_name:\n", $response->as_string;
}

sub bz_get_products {
    my ($self) = @_;
    $self->bz_log_in('QA_Selenium_TEST');

    my $accessible = $self->bz_call_success('Product.get_accessible_products');
    my $prod_call = $self->bz_call_success('Product.get', $accessible->result);
    my %products;
    foreach my $prod (@{ $prod_call->result->{products} }) {
        $products{$prod->{name}} = $prod->{id};
    }

    $self->bz_call_success('User.logout');
    return \%products;
}

sub _string_array { map { random_string() } (1..$_[0]) }

sub bz_create_test_bugs {
    my ($self, $config, $second_private) = @_;

    my @whiteboard_strings = _string_array(3);
    my @summary_strings = _string_array(3);

    my $public_bug = create_bug_fields($config);
    $public_bug->{alias} = random_string(20);
    $public_bug->{whiteboard} = join(' ', @whiteboard_strings);
    $public_bug->{summary} = join(' ', @summary_strings);

    my $private_bug = dclone($public_bug);
    $private_bug->{alias} = random_string(20);
    if ($second_private) {
        $private_bug->{product}   = 'QA-Selenium-TEST';
        $private_bug->{component} = 'QA-Selenium-TEST';
        $private_bug->{target_milestone} = 'QAMilestone';
        $private_bug->{version} = 'QAVersion';
    }

    my @create_bugs = (
        { user => 'editbugs',
          args => $public_bug,
          test => 'Create a public bug' },
        { user => $second_private ? PRIVATE_BUG_USER : 'editbugs',
          args => $private_bug,
          test => $second_private ? 'Create a private bug' 
                                  : 'Create a second public bug' },
    );

    my $post_success = sub {
        my ($call, $t) = @_;
        my $id = $call->result->{id};
        $t->{args}->{id} = $id;
    };

    # Creating the bugs isn't really a test, it's just preliminary work
    # for the tests. So we just run it with one of the RPC clients.
    $self->bz_run_tests(tests => \@create_bugs, method => 'Bug.create',
                        post_success => $post_success);

    return ($public_bug, $private_bug);
}

sub bz_run_tests {
    my ($self, %params) = @_;
    # Required params
    my $config = $self->bz_config;
    my $tests  = $params{tests};
    my $method = $params{method};

    # Optional params
    my $post_success = $params{post_success};

    my $former_user = '';
    foreach my $t (@$tests) {
        # Only logout/login if the user has changed since the last test
        # (this saves us LOTS of needless logins).
        my $user = $t->{user} || '';
        if ($former_user ne $user) {
            $self->bz_call_success('User.logout') if $former_user;
            $self->bz_log_in($user) if $user;
            $former_user = $user;
        }

        if ($t->{error}) {
            $self->bz_call_fail($method, $t->{args}, $t->{error}, $t->{test});
        }
        else {
            my $call = $self->bz_call_success($method, $t->{args}, $t->{test});
            if ($call->result && $post_success) {
                $post_success->($call, $t, $self);
            }
        }
    }

    $self->bz_call_success('User.logout') if $former_user;
}

1;

__END__
