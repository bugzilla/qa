########################################
# Test for xmlrpc calls to:            #
# Product.get_selectable_products()    #
# Product.get_enterable_products()     #
# Product.get_accessible_products()    #
# Product.get_products()               #
########################################

use strict;
use warnings;

use XMLRPC::Lite;
use HTTP::Cookies;

use Test::More tests => 23;

my $qa_username        = 'qa@bugzilla.jp';
my $non_privs_username = 'no-privs@bugzilla.jp';

my $password     = shift;
my $installation = shift;
my $xmlrpc_url   = "http://landfill.bugzilla.org/${installation}/xmlrpc.cgi";

my $cookie_jar = new HTTP::Cookies( file => "/tmp/lwp_cookies.dat" );
my $rpc        = new XMLRPC::Lite( proxy => $xmlrpc_url );
$rpc->transport->cookie_jar($cookie_jar);

# test with privileged logged in user
my $call = $rpc->call( 'User.login',
    { login => $qa_username, password => $password } );

# Save the cookies in the cookie file
$rpc->transport->cookie_jar->extract_cookies(
    $rpc->transport->http_response );
$rpc->transport->cookie_jar->save;

# get product ids from thier names
$call = $rpc->call( 'Tools.product_names_to_ids',
    [ 'TestProduct', 'PrivateProduct', 'NoEntryProduct' ] );
my $product_ids = $call->result;

my $private_product_id     = $product_ids->{PrivateProduct};
my $search_only_product_id = $product_ids->{NoEntryProduct};
my $public_product_id      = $product_ids->{TestProduct};

############################################################################################################

# test with logged in privileged user
$call = $rpc->call('Product.get_selectable_products');
my $result = $call->result;
ok( grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_selectable_products works successfully and returns private products for privileged users'
);

$call   = $rpc->call('Product.get_enterable_products');
$result = $call->result;
ok( grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_enterable_products works successfully and returns private products for privileged users'
);
ok( !grep( $_ == $search_only_product_id, @{ $result->{ids} } ),
    'Product.get_enterable_products works successfully and does not return any search only products for privileged users'
);

$call   = $rpc->call('Product.get_accessible_products');
$result = $call->result;
ok( grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_accessible_products works successfully and returns private products for privileged users'
);

$call = $rpc->call(
    'Product.get_products',
    {   ids => [
            $private_product_id, $search_only_product_id,
            $public_product_id
        ]
    }
);
$result = $call->result;
ok( grep( $_->{id} == $private_product_id, @{ $result->{products} } ),
    'Product.get_products works successfully and returns private products for privileged users'
);

$call = $rpc->call('User.logout');

#######################################################################################################

# test with logged in non-privileged user
$call = $rpc->call( 'User.login',
    { login => $non_privs_username, password => $password } );

# Save the cookies in the cookie file
$rpc->transport->cookie_jar->extract_cookies(
    $rpc->transport->http_response );
$rpc->transport->cookie_jar->save;

$call   = $rpc->call('Product.get_selectable_products');
$result = $call->result;

ok( !$call->faultstring,
    'Product.get_selectable_products returns no errors' );
ok( grep( $_ == $search_only_product_id, @{ $result->{ids} } ),
    'Product.get_selectable_products works successfully and returns the search products successfully'
);
ok( !grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_selectable_products works successfully and does not return any private products for non privileged users'
);

$call   = $rpc->call('Product.get_enterable_products');
$result = $call->result;

ok( !$call->faultstring, 'Product.get_enterable_products returns no errors' );
ok( !grep( $_ == $search_only_product_id, @{ $result->{ids} } ),
    'Product.get_enterable_products works successfully and does not return any search only products for non privileged users'
);
ok( !grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_enterable_products works successfully and does not return any private products for non privileged users'
);

$call   = $rpc->call('Product.get_accessible_products');
$result = $call->result;

ok( !$call->faultstring,
    'Product.get_accessible_products returns no errors' );
ok( grep( $_ == $search_only_product_id, @{ $result->{ids} } ),
    'Product.get_accessible_products works successfully and returns search/selectable only products'
);
ok( !grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_accessible_products works successfully and does not return any private products for non privileged users'
);

$call = $rpc->call(
    'Product.get_products',
    {   ids => [
            $private_product_id, $search_only_product_id,
            $public_product_id
        ]
    }
);
$result = $call->result;

ok( !$call->faultstring, 'Product.get_products returns no errors' );
ok( grep( $_->{id} == $search_only_product_id, @{ $result->{products} } ),
    'Product.get_products works successfully and returns search/selectable only products'
);
ok( !grep( $_->{id} == $private_product_id, @{ $result->{products} } ),
    'Product.get_products works successfully and does not return any private products for non privileged users'
);
ok( grep( $_->{id} == $public_product_id, @{ $result->{products} } ),
    'Product.get_products works successfully and returns public products'
);

$call = $rpc->call('User.logout');

##############################################################################################################

# test with non-loggedin user
$call   = $rpc->call('Product.get_selectable_products');
$result = $call->result;
ok( !grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_selectable_products works successfully and does not return any private products for non logged in users'
);

$call   = $rpc->call('Product.get_enterable_products');
$result = $call->result;
ok( !grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_enterable_products works successfully and does not return any private products for non logged in users'
);
ok( !grep( $_ == $search_only_product_id, @{ $result->{ids} } ),
    'Product.get_enterable_products works successfully and does not return any search only products for non logged in users'
);

$call   = $rpc->call('Product.get_accessible_products');
$result = $call->result;
ok( !grep( $_ == $private_product_id, @{ $result->{ids} } ),
    'Product.get_accessible_products works successfully and does not return any private products for non logged in users'
);

$call = $rpc->call(
    'Product.get_products',
    {   ids => [
            $private_product_id, $search_only_product_id,
            $public_product_id
        ]
    }
);
$result = $call->result;
ok( !grep( $_->{id} == $private_product_id, @{ $result->{products} } ),
    'Product.get_products works successfully and does not return any private products for non logged in users'
);

