# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::Tests;
use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(
    PRIVATE_BUG_USER
    STANDARD_BUG_TESTS
);

use constant INVALID_BUG_ID => -1;
use constant INVALID_BUG_ALIAS => 'aaaaaaa12345';
use constant PRIVATE_BUG_USER => 'QA_Selenium_TEST';

use constant STANDARD_BUG_TESTS => [
    { args  => { ids => ['private_bug'] },
      error => "You are not authorized to access",
      test  => 'Logged-out user cannot access a private bug',
    },
    { args => { ids => ['public_bug'] },
      test => 'Logged-out user can access a public bug.',
    },
    { args  =>  { ids => [INVALID_BUG_ID] },
      error =>  "not a valid bug number",
      test  =>  'Passing invalid bug id returns error "Invalid Bug ID"',
    },
    { args  =>  { ids => [undef] },
      error => "You must enter a valid bug number",
      test  =>  'Passing undef as bug id param returns error "Invalid Bug ID"',
    },
    { args  => { ids => [INVALID_BUG_ALIAS] },
      error =>  "nor an alias to a bug",
      test  => 'Passing invalid bug alias returns error "Invalid Bug Alias"',
    },

    { user  =>  'unprivileged',
      args  =>  { ids => ['private_bug'] },
      error =>  "You are not authorized to access",
      test  => 'Access to a private bug is denied to a user without privs',
    },
    { user => 'unprivileged',
      args => { ids => ['public_bug'] },
      test => 'User without privs can access a public bug by alias.',
    },
    { user => 'admin',
      args => { ids => ['public_bug'] },
      test => 'Admin can access a public bug.',
    },
    { user => PRIVATE_BUG_USER,
      args =>  { ids => ['private_bug'] },
      test =>  'User with privs can successfully access a private bug',
    },
];

1;
