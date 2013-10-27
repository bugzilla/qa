##################################################
# Test for xmlrpc call functions in Bugzilla.pm  #
##################################################

use strict;
use warnings;
use lib qw(lib);
use Test::More tests => 15 * 3;
use QA::Util;
my ($config, @clients) = get_rpc_clients();

foreach my $rpc (@clients) {
    my $vers_call = $rpc->bz_call_success('Bugzilla.version');
    my $version = $vers_call->result->{version};
    ok($version, "Bugzilla.version returns $version");

    my $tz_call = $rpc->bz_call_success('Bugzilla.timezone');
    my $tz = $tz_call->result->{timezone};
    ok($tz, "Bugzilla.timezone retuns $tz");

    my $ext_call = $rpc->bz_call_success('Bugzilla.extensions');
    my $extensions = $ext_call->result->{extensions};
    isa_ok($extensions, 'HASH', 'extensions');

    # There is always at least the QA extension enabled.
    my $cmp = $config->{test_extensions} ? '>' : '==';
    my @ext_names = keys %$extensions;
    my $desc = scalar(@ext_names) . ' extension(s) returned: ' . join(', ', @ext_names);
    cmp_ok(scalar(@ext_names), $cmp, 1, $desc);
    ok(grep($_ eq 'QA', @ext_names), 'The QA extension is enabled');

    my $time_call = $rpc->bz_call_success('Bugzilla.time');
    my $time_result = $time_call->result;
    foreach my $type (qw(db_time web_time web_time_utc)) {
        cmp_ok($time_result->{$type}, '=~', $rpc->DATETIME_REGEX, 
               "Bugzilla.time returns a datetime for $type");
    }
    cmp_ok($time_result->{tz_offset}, '=~', qr/^(?:\+|-)\d{4}$/,
           "Bugzilla.time's tz_offset is in the right format");
    cmp_ok($time_result->{tz_short_name}, '=~', qr/^[A-Z]{3,4}/,
           "Bugzilla.time's tz_short_name is in the right format");
    cmp_ok($time_result->{tz_name}, '=~', qr{^(?:(?:\w+/\w+)|(?:UTC))$},
           "Bugzilla.time's tz_name is in the right format");
}
