##########################################################
# Test for xmlrpc call to User.login() and User.logout() #
##########################################################

use strict;
use warnings;
use lib qw(lib);
use Data::Dumper;
use QA::Util;
use Test::More tests => 132;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

use constant INVALID_EMAIL => '@invalid_user@';

my $user = $config->{unprivileged_user_login};
my $pass = $config->{unprivileged_user_passwd};
my $error = "The username or password you entered is not valid";

my @tests = (
    { user => 'unprivileged',
      test => "Unprivileged user can log in successfully",
    },

    { args  => { login => $user, password => '' },
      error => $error,
      test  => "Empty password can't log in",
    },
    { args  => { login => '', password => $pass },
      error => $error,
      test  => "Empty login can't log in",
    },
    { args  => { login => $user },
      error => "requires a password argument",
      test  => "Undef password can't log in",
    },
    { args  => { password => $pass },
      error => "requires a login argument",
      test  => "Undef login can't log in",
    },

    { args  => { login => INVALID_EMAIL, password => $pass },
      error => $error,
      test  => "Invalid email can't log in",
    },
    { args  => { login => $user, password => '*' },
      error => $error,
      test  => "Invalid password can't log in",
    },

    { args  => { login    => $config->{disabled_user_login}, 
                 password => $config->{disabled_user_passwd} },
      error => "!!This is the text!!",
      test  => "Can't log in with a disabled account",
      clears_cookies => 1,
    },
    { args  => { login => $config->{disabled_user_login}, password => '*' },
      error => $error,
      test  => "Logging in with invalid password doesn't show disabledtext",
    },
);

sub _check_has_cookies {
    my $rpc = shift;
    my @cookies = $rpc->transport->http_response->header('Set-Cookie');
    my $cookie_string = join("\n", @cookies);
    cmp_ok($cookie_string, '=~', qr/^Bugzilla_login/m,
           'Response has the Bugzilla_login cookie');
    cmp_ok($cookie_string, '=~', qr/^Bugzilla_logincookie/m,
           "Response has the Bugzilla_logincookie cookie");
}

sub _check_no_cookies {
    my ($rpc, $clears_cookies) = @_;
    my @cookies = $rpc->transport->http_response->header('Set-Cookie');
    if ($clears_cookies) {
        my $cookie_string = join("\n", @cookies);
        cmp_ok($cookie_string, '=~', qr/^Bugzilla_login=X;/m,
               'Response clears the Bugzilla_login cookie');
        cmp_ok($cookie_string, '=~', qr/^Bugzilla_logincookie=X;/m,
               "Response clears the Bugzilla_logincookie cookie");
    }
    else {
        is_deeply(\@cookies, [], 'Response has no cookies')
            or diag(Dumper(\@cookies));
    }
}

sub _login_args {
    my $args = shift;
    my %fixed_args = %$args;
    $fixed_args{Bugzilla_login} = delete $fixed_args{login};
    $fixed_args{Bugzilla_password} = delete $fixed_args{password};
    return \%fixed_args;
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    for my $t (@tests) {
        if ($t->{user}) {
            $rpc->bz_log_in($t->{user});
            _check_has_cookies($rpc);
            $rpc->bz_call_success('User.logout');
            my $password = $config->{$t->{user} . '_user_passwd'};
            $rpc->bz_call_success('Bugzilla.version',
                { Bugzilla_login => $config->{$t->{user} . '_user_login'}, 
                  Bugzilla_password => $password });
            _check_has_cookies($rpc); 
        }
        else {
            $rpc->bz_call_fail('User.login', $t->{args}, $t->{error}, 
                               $t->{test});
            _check_no_cookies($rpc, $t->{clears_cookies});
            if (defined $t->{args}->{login} 
                and defined $t->{args}->{password}) 
            {
                my $fixed_args = _login_args($t->{args});
                $rpc->bz_call_fail('Bugzilla.version', $fixed_args,
                    $t->{error}, "Bugzilla_login: " . $t->{test});
                _check_no_cookies($rpc, $t->{clears_cookies});
            }
        }
    }
}
