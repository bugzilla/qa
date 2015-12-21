#######################################
# Tests for REST calls in Bugzilla.pm #
#######################################

use 5.10.1;
use strict;
use warnings;

use lib qw(lib);

use Test::More tests => 11;
use QA::REST;

my $rest = get_rest_client();
my $config = $rest->bz_config;

my $version = $rest->call('version')->{version};
ok($version, "GET /rest/version returns $version");

my $extensions = $rest->call('extensions')->{extensions};
isa_ok($extensions, 'HASH', 'GET /rest/extensions');
my @ext_names = sort keys %$extensions;
# There is always at least the QA extension enabled.
ok(scalar(@ext_names), scalar(@ext_names) . ' extension(s) found: ' . join(', ', @ext_names));
ok($extensions->{QA}, 'The QA extension is enabled, with version ' . $extensions->{QA}->{version});

my $timezone = $rest->call('timezone')->{timezone};
ok($timezone, "GET /rest/timezone retuns $timezone");

my $time = $rest->call('time');
foreach my $type (qw(db_time web_time)) {
    ok($time->{$type}, "GET /rest/time returns $type = " . $time->{$type});
}

# Logged-out users can only access the maintainer and requirelogin parameters.
my $params = $rest->call('parameters')->{parameters};
my @param_names = sort keys %$params;
ok(@param_names == 2 && defined $params->{maintainer} && defined $params->{requirelogin},
   'Only 2 parameters accessible to logged-out users: ' . join(', ', @param_names));

# Powerless users can access much more parameters.
$params = $rest->call('parameters', { api_key => $config->{unprivileged_user_api_key} })->{parameters};
@param_names = sort keys %$params;
ok(@param_names > 2, scalar(@param_names) . ' parameters accessible to powerless users');

# Admins can access all parameters.
$params = $rest->call('parameters', { api_key => $config->{admin_user_api_key} })->{parameters};
@param_names = sort keys %$params;
ok(@param_names > 2, scalar(@param_names) . ' parameters accessible to admins');

my $timestamp = $rest->call('last_audit_time')->{last_audit_time};
ok($timestamp, "GET /rest/last_audit_time returns $timestamp");
