# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package QA::DB::Pg;

use 5.10.1;
use strict;
use warnings;

use DBI;
use File::Path;
use POSIX;

use base qw(QA::DB);
use fields qw(
    _pg
);

# PostgreSQL 8.3 and above won't let you connect to a SQL_ASCII
# database if you have a UTF-8 LC_CTYPE. It will allow connecting
# to any database from the C locale, though.
POSIX::setlocale(POSIX::LC_CTYPE, 'C');

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub drop_db {
    my ($self, $db) = @_;
    sleep 1; # Give Pg time to disconnect from anything it was connected to.
    $self->_pg->do("DROP DATABASE $db");
}

sub copy_db {
    my ($self, $params) = @_;
    my ($from, $to) = ($params->{from}, $params->{to});
    my $from_host = $params->{from_host};
    my ($user, $pass) = ($self->{_user}, $self->{_password});

    if ($self->db_exists($to)) {
        if ($params->{overwrite}) {
            $self->drop_db($to);
        }
        else {
            die "You attempted to copy to '$to' but that database already"
                . " exists.";
        }
    }

    if ($from_host) {
        # A hack that only works on tinderbox.bugzilla.lan.
        system("/usr/local/bin/pgclone $from $to");
    }
    else {
        $self->_pg->do("CREATE DATABASE $to TEMPLATE $from");
    }
}

sub db_exists {
    my ($self, $db) = @_;
    return $self->_pg->selectrow_array(
        "SELECT 1 FROM pg_stat_database WHERE datname = ?", undef, $db) ? 1 : 0;
}

sub reset {
    system("rm -rf schema-*sorted");
}

sub create_schema_map {
    my ($self, $for_db) = @_;
    my ($user, $pass) = ($self->{_user}, $self->{_password});

    my $schema_dir = "schema-$for_db";
    my $sorted_dir = "$schema_dir-sorted";

    # Create the directories
    mkdir $schema_dir;
    mkdir $sorted_dir;

    chdir $schema_dir || die "ERROR: Can't chdir to $schema_dir";

    # Create the basic map
    my $tables = $self->_tables($for_db);
    foreach my $table (@$tables) {
        system("pg_dump -Oxs -U $user -t $table $for_db > $table.sql");
    }
    foreach my $file (glob '*.sql') {
        _fix_sql_file($file);
    }
    # Create the sorted map
    system("find . -name \\*.sql -exec sort \\{\\}"
           . " -o ../$sorted_dir/\\{\\} \\;");

    chdir '..';

    File::Path::rmtree($schema_dir);
    return $sorted_dir;
}

sub _fix_sql_file {
    my ($name) = @_;
    open(my $fh, '<', $name) || die "$name: $!";
    my $content;
    { local $/; $content = <$fh>; }
    close $fh;
    # Remove the comments
    $content =~ s/^--.*$//gm;
    # Remove commas from ends of lines, because they can cause
    # false positives when we check for schema differences
    $content =~ s/,$//gm;
    # We don't really care about the DB encoding, since Bugzilla
    # doesn't specify one on creation.
    $content =~ s/^SET client_encoding.*$//gm;
    # default_with_oids doesn't matter
    $content =~ s/^SET default_with_oids.*$//gm;
    # "integer DEFAULT nextval" is the same as serial, but in Pg 8.3,
    # that's just represented as "integer" here.
    $content =~ s/integer DEFAULT nextval\(\S+\)/integer/g;
    # START WITH \d+ is some extra sequence stuff that shows up in populated
    # DBs that doesn't show up in empty DBs.
    $content =~ s/^\s+START WITH \d+$//gm;
    # Remove all the lines that are just empty space.
    $content =~ s/^\n//gm;
    open(my $write_fh, '>', $name) || die "$name: $!";
    print $write_fh $content;
    close $write_fh;
}

sub sql_random { return "RANDOM()"; }

sub _tables {
    my ($self, $db_name) = @_;
    my $dbh = $self->_pg($db_name);
    my $table_sth = $dbh->table_info(undef, undef, undef, "TABLE");
    my $list = $dbh->selectcol_arrayref($table_sth, { Columns => [3] });
    # All PostgreSQL system tables start with "pg_" or "sql_"
    @$list = grep(!/(^pg_)|(^sql_)/, @$list);
    $dbh->disconnect;
    return $list;
}

sub _pg {
    my ($self, $db_name) = @_;
    return $self->{_pg} if ($self->{_pg} && !$db_name);
    $db_name ||= 'postgres';
    my $dsn = "DBI:Pg:dbname=$db_name";
    my $connection = DBI->connect($dsn, $self->{_user}, $self->{_password},
        {  RaiseError => 1, AutoCommit => 1, PrintError => 0, TaintIn => 1,
           ShowErrorStatement => 1, FetchHashKeyName => 'NAME_lc' });
    ($self->{_pg} = $connection) if $db_name eq 'postgres';
    return $connection;
}

1;
