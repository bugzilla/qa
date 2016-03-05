# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package QA::DB;

use 5.10.1;
use strict;
use warnings;

use fields qw(
    _user
    _password
);

use constant MAX_RETRIES => 3;

sub new {
    my ($class, $params) = @_;

    my $driver = $params->{db_type};
    my $module = "QA/DB/$driver.pm";
    require $module;

    my $self = "QA::DB::$driver"->new(@_);

    $self->{_user} = $params->{user};
    $self->{_password} = $params->{password};

    return $self;
}

sub diff_schema {
    my ($self, $from, $to) = @_;
    my $from_dir = "schema-$from-sorted";
    my $to_dir   = "schema-$to-sorted";
    $self->create_schema_map($from) if !-d $from_dir;
    $self->create_schema_map($to)   if !-d $to_dir;
    return `diff -Nruw $from_dir $to_dir`;
    File::Path::rmtree($to_dir);
}

sub download_dump {
    my ($self, $params) = @_;
    my ($url, $name) = ($params->{url}, $params->{name});

    # Download gzipped dump file
    my $dump_file = "$name.sql.gz";
    my $full = "$url/$dump_file";
    print "Downloading $full...\n";
    my $success = 0;
    my $tries = 0;
    while (!$success && $tries < MAX_RETRIES) {
        $tries++;
        print "Retrying (Try $tries)..." if $tries > 1;
        next if system("curl", "-o", $dump_file, $full) != 0;
        $success = 1;
    }
    die "Error downloading dump file $dump_file" if !$success;

    # Download
    my $md5sum_file = "$name.md5sum";
    $full = "$url/$md5sum_file";
    print "Downloading $full...\n";
    $success = 0;
    $tries = 0;
    while (!$success && $tries < MAX_RETRIES) {
        $tries++;
        print "Retrying (Try $tries)..." if $tries > 1;
        next if system("curl", "-o", $md5sum_file, $full) != 0;
        $success = 1;
    }
    die "Error downloading md5sum file $md5sum_file" if !$success;

    # Check for integrity of file
    print "Verifying integrity of dump file...\n";
    my $rc = system("md5sum", "-c", $md5sum_file);
    die "Error verifying integrity of dump file" if $rc;

    return $dump_file;
}

1;
