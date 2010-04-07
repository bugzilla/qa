# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::RPC::JSONRPC;
use strict;
use base qw(QA::RPC JSON::RPC::Client);

use constant TYPE => 'JSON-RPC';
use constant DATETIME_REGEX => qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/;

#################################
# Consistency with XMLRPC::Lite #
#################################

sub transport { return $_[0]->ua }

sub call {
    my $self = shift;
    my ($method, $args) = @_;
    my %params = ( method => $method, params => [$args] );
    my $config = $self->bz_config;
    my $url = $config->{browser_url} . "/"
              . $config->{bugzilla_installation} . "/jsonrpc.cgi";
    my $result = $self->SUPER::call($url, \%params);
    if ($result) {
        bless $result, 'QA::RPC::JSONRPC::ReturnObject';
    }
    return $result;
}

1;

package QA::RPC::JSONRPC::ReturnObject;
use strict;
use JSON::RPC::Client;
use base qw(JSON::RPC::ReturnObject);

#################################
# Consistency with XMLRPC::Lite #
#################################

sub faultstring { $_[0]->{content}->{error}->{message} }
sub fault { $_[0]->is_error }

__END__
