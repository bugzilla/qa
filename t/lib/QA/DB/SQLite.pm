# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;
use warnings;

package QA::DB::SQLite;

use DBI;
use File::Basename;
use File::Path;
use File::Temp;
use IPC::Cmd;

use base qw(QA::DB);

our $DB_DIR = "data/db";

sub new {
    my $class = shift;
    my $params = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub drop_db {
    my ($self, $db) = @_;
    print "Dropping $db...\n";
    system("rm", "-f", "$DB_DIR/$db");
}

sub copy_db {
    my ($self, $params_ref) = @_;
    my %params = %$params_ref;
    my ($from, $to) = ($params{from}, $params{to});
    my $from_host = $params{from_host};

    if ($self->db_exists($to)) {
        if ($params{overwrite}) {
            $self->drop_db($to);
        }
        else {
            die "You attempted to copy to '$to' but that database already"
                . " exists.";
        }
    }

    if ($from_host) {
        system('scp', "$from_host:$from.sql", "$DB_DIR/$to.sql");
        system('sqlite3', "-init", "$DB_DIR/$to.sql", "$DB_DIR/$to");
        unlink "$DB_DIR/$to.sql";
        return;
    }

    system('cp', '-a', "$DB_DIR/$from", "$DB_DIR/$to");
}


sub db_exists {
    my ($self, $db) = @_;
    return -e "$DB_DIR/$db" ? 1 : 0;
}

sub reset {
}

sub sql_random { return "RANDOM()"; }

1;
