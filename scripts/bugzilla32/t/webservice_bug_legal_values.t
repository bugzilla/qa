##############################################
# Test for xmlrpc call to Bug.legal_values() #
##############################################

use strict;
use warnings;
use lib qw(lib);
use Test::More tests => 94;
use QA::Util;
my ($rpc, $config) = get_xmlrpc_client();

use constant INVALID_PRODUCT_ID => -1;
use constant INVALID_FIELD_NAME => 'invalid_field';
use constant GLOBAL_FIELDS => 
    qw(bug_severity bug_status op_sys priority rep_platform resolution
       cf_qa_status cf_single_select);
use constant PRODUCT_FIELDS => qw(version target_milestone component);

xmlrpc_log_in($rpc, $config, 'QA_Selenium_TEST');

# get product ids from their names
my $accessible = xmlrpc_call_success($rpc, 'Product.get_accessible_products');
my $prod_call = xmlrpc_call_success($rpc, 'Product.get', $accessible->result);
my %products;
foreach my $prod (@{ $prod_call->result->{products} }) {
    $products{$prod->{name}} = $prod->{id};
}

my $public_product = $products{'Another Product'};
my $private_product = $products{'QA-Selenium-TEST'};

xmlrpc_call_success($rpc, 'User.logout');

my @all_tests;

for my $field (GLOBAL_FIELDS) {
    push(@all_tests, 
         { args => { field => $field },
           test => "Logged-out user can get $field values" });
}

for my $field (PRODUCT_FIELDS) {
    my @tests = (
        { args  => { field => $field },
          error => "argument was not set",
          test  => "$field can't be accessed without a value for 'product'",
        },
        { args  => { product_id => INVALID_PRODUCT_ID, field => $field },
          error => "does not exist",
          test  => "$field cannot be accessed with an invalid product id",
        },

        { args  => { product_id => $private_product, field => $field },
          error => "you don't have access",
          test => "Logged-out user cannot access $field in private product"
        },
        { args  => { product_id => $public_product, field => $field },
          test  => "Logged-out user can access $field in a public product",
        },

        { user  => 'unprivileged',
          args  => { product_id => $private_product, field => $field },
          error => "you don't have access",
          test  => "Unprivileged user cannot access $field in private product",
        },
        { user => 'unprivileged',
          args => { product_id => $public_product, field => $field },
          test => "Logged-in user can access $field in public product",
        },

        { user => 'QA_Selenium_TEST',
          args => { product_id => $private_product, field  => $field },
          test => "Privileged user can access $field in a private product",
        },
    );

    push(@all_tests, @tests);
}

my @extra_tests = (
    { args  => { product_id => $private_product, },
      error => "Can't use  as a field name",
      test  =>  "Passing product_id without 'field' throws an error",
    },
    { args  => { field => INVALID_FIELD_NAME },
      error => "Can't use " . INVALID_FIELD_NAME . " as a field name",
      test  => 'Invalid field name'
    },
);

push(@all_tests, @extra_tests);

for my $t (@all_tests) {
    if ($t->{user}) {
        xmlrpc_log_in($rpc, $config, $t->{user});
    }

    if ($t->{error}) {
        xmlrpc_call_fail($rpc, 'Bug.legal_values', $t->{args}, $t->{error}, 
                         $t->{test});
    }
    else {
        my $response = xmlrpc_call_success($rpc, 'Bug.legal_values', $t->{args},
                                         $t->{test});
        if ($response->result) {
            cmp_ok(scalar @{ $response->result->{'values'} }, '>', 0, 
                   'Got one or more values');
        }
    }

    if ($t->{user}) {
        xmlrpc_call_success($rpc, 'User.logout');
    }
}
