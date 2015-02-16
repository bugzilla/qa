#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# Setup starts here
cd $TRAVIS_BUILD_DIR

# Allow alias expansion inside shell scripts
shopt -s expand_aliases

alias cpanm='cpanm --quiet --notest --reinstall'

# Basic sanity tests
if [ "$TEST_SUITE" = "sanity" ]; then
    echo -en 'travis_fold:start:perl_dependencies\r'
    echo "== Installing Perl dependencies"a
    cpanm Authen::Radius
    cpanm DBI
    cpanm Daemon::Generic
    cpanm Date::Format
    cpanm DateTime::TimeZone
    cpanm Email::Address
    cpanm Email::MIME
    cpanm Email::Reply
    cpanm Email::Send
    cpanm Email::Sender::Simple
    cpanm File::Slurp
    cpanm JSON::RPC
    cpanm JSON::XS
    cpanm LWP::UserAgent
    cpanm Math::Random::ISAAC
    cpanm Net::LDAP
    cpanm PatchReader
    cpanm Pod::Coverage
    cpanm Template
    cpanm Test::Taint
    cpanm Text::Markdown
    cpanm TheSchwartz
    cpanm URI
    cpanm XMLRPC::Lite
    echo -en 'travis_fold:end:perl_dependencies\r'

    echo "== Running sanity tests"
    prove -v -f t/*.t
    exit $?
fi

echo "== Updating OS packages"
sudo apt-get update -qq -y --fix-missing

# Documentation build testing
if [ "$TEST_SUITE" = "docs" ]; then
    echo -en 'travis_fold:start:packages\r'
    echo "== Installing OS packages"
    sudo apt-get install -qq -y python-sphinx xmlto lynx texlive-lang-cyrillic \
        ldp-docbook-dsssl jade jadetex
    echo -en 'travis_fold:end:packages\r'

    # Environment need for docs building
    export JADE_PUB=/usr/share/sgml/declaration
    export LDP_HOME=/usr/share/sgml/docbook/stylesheet/dsssl/ldp

    echo "== Running documentation build"
    cd docs
    perl makedocs.pl --with-pdf
    exit $?
fi

# Package installation section
EXTRA_PKGS=""
if [ "$DB" = "pg" ]; then
    EXTRA_PKGS="postgresql-server-dev-9.3"
fi
if [ "$DB" = "mysql" ]; then
   EXTRA_PKGS="libmysqlclient-dev"
fi

echo -en 'travis_fold:start:packages\r'
echo "== Installing OS packages"
sudo apt-get install -qq -y perlmagick libssl-dev g++ libgd2-xpm-dev libpq5 \
    apache2 xvfb $EXTRA_PKGS
echo -en 'travis_fold:end:packages\r'

# Install dependencies from Build.PL
echo -en 'travis_fold:start:perl_dependencies\r'
echo "== Installing Perl dependencies"
cpanm Cache::Memcached::GetParserXS # FIXME test-checksetup.pl fails without this
cpanm DateTime
cpanm DBD::mysql
cpanm DBD::Pg
cpanm Module::Build # Need latest build
cpanm Software::License # Needed by Module::Build to find proper Mozilla license
cpanm Test::WWW::Selenium # For webservice and selenium tests
cpanm XMLRPC::Lite # Due to the SOAP::Lite split
cpanm --installdeps --with-recommends .  # Install dependencies reported by Build.PL
echo -en 'travis_fold:end:perl_dependencies\r'

# Link /usr/bin/perl to the current perlbrew perl so that the Bugzilla cgi scripts will work properly
# PERLBREW_ROOT and PERLBREW_PERL are set by the perlbrew binary when switch perl versions
echo "== Fixing Perl"
sudo mv /usr/bin/perl /usr/bin/perl.bak
sudo ln -s $PERLBREW_ROOT/perls/$PERLBREW_PERL/bin/perl /usr/bin/perl

# We need to replace some variables in the config files from the Travis CI environment
echo "== Updating config files"
sed -e "s?%TRAVIS_BUILD_DIR%?$(pwd)?g" --in-place qa/config/selenium_test.conf
sed -e "s?%USER%?$USER?g" --in-place qa/config/checksetup_answers.txt
if [ "$DB" = "" ]; then
    DB=mysql
fi
sed -e "s?%DB%?$DB?g" --in-place qa/config/checksetup_answers.txt
sed -e "s?%TRAVIS_BUILD_DIR%?$(pwd)?g" --in-place qa/config/config-checksetup-mysql
sed -e "s?%TRAVIS_BUILD_DIR%?$(pwd)?g" --in-place qa/config/config-checksetup-pg
if [ "$TEST_SUITE" == "checksetup" ]; then
    sed -e "s?%DB_NAME%?bugs_checksetup?g" --in-place qa/config/checksetup_answers.txt
else
    sed -e "s?%DB_NAME%?bugs?g" --in-place qa/config/checksetup_answers.txt
fi

# MySQL related setup
if [ "$DB" = "mysql" ]; then
    echo "== Setting up MySQL"
    mysql -u root mysql -e "GRANT ALL PRIVILEGES ON *.* TO bugs@localhost IDENTIFIED BY 'bugs'; FLUSH PRIVILEGES;"
fi

# PostgreSQL related setup
if [ "$DB" = "pg" ]; then
    echo "== Setting up PostgreSQL"
    sudo -u postgres createuser --superuser bugs
    sudo -u postgres psql -U postgres -d postgres -c "alter user bugs with password 'bugs';"
fi

# Checksetup test which tests schema changes from older versions to the current
if [ "$TEST_SUITE" = "checksetup" ] && [ "$DB" = "mysql" ]; then
    echo "== Running checksetup upgrade tests for MySQL"
    perl qa/test-checksetup.pl --full --config config/config-checksetup-mysql
    exit $?
fi

if [ "$TEST_SUITE" = "checksetup" ] && [ "$DB" = "pg" ]; then
    echo "== Running checksetup upgrade tests for PostgreSQL"
    perl qa/test-checksetup.pl --full --config config/config-checksetup-pg
    exit $?
fi

# Configure Apache to serve from our build directory and restart
echo "== Setting up Apache"
sed -e "s?%TRAVIS_BUILD_DIR%?$(pwd)?g" --in-place qa/config/bugzilla.conf
sudo cp qa/config/bugzilla.conf /etc/apache2/sites-available/default
sudo sed -e "s?APACHE_RUN_USER=www-data?APACHE_RUN_USER=$USER?g" --in-place /etc/apache2/envvars
sudo sed -e "s?APACHE_RUN_GROUP=www-data?APACHE_RUN_GROUP=$USER?g" --in-place /etc/apache2/envvars
sudo service apache2 stop; sudo rm -rf /var/lock/apache2; sudo service apache2 start

# We have to run checksetup.pl twice as the first run creates localconfig
echo "== Running checksetup"
perl checksetup.pl qa/config/checksetup_answers.txt
perl checksetup.pl qa/config/checksetup_answers.txt

# Add patch file used by tests. FIXME: make this a config option
sudo mkdir -p /var/www/html/selenium/bugzilla
sudo cp qa/config/patch.diff /var/www/html/selenium/bugzilla

# Create test data in the SQLite database for use by the extended test suite
echo "== Generating test data"
cd $TRAVIS_BUILD_DIR/qa/config
perl -Mlib=$TRAVIS_BUILD_DIR/lib generate_test_data.pl
cd $TRAVIS_BUILD_DIR/qa/t

# Selenium UI Tests
if [ "$TEST_SUITE" = "selenium" ]; then
    # Start the virtual frame buffer
    echo "== Starting virtual frame buffer"
    export DISPLAY=:99.0
    sudo sh -e /etc/init.d/xvfb start
    sleep 5

    # Download and start the selenium server
    echo "== Downloading and starting Selenium server"
    wget http://selenium-release.storage.googleapis.com/2.41/selenium-server-standalone-2.41.0.jar
    java -jar selenium-server-standalone-2.41.0.jar -DfirefoxDefaultPath=/usr/lib64/firefox/firefox-bin -log ~/sel-`date +%Y%m%d-%H%M%S`.log &
    sleep 15

    echo "== Running Selenium UI tests"
    perl -Mlib=$TRAVIS_BUILD_DIR/lib /usr/bin/prove -v -f -I$TRAVIS_BUILD_DIR/lib test_*.t
    exit $?
fi

# WebService Tests
if [ "$TEST_SUITE" = "webservices" ]; then
    echo "== Running WebService tests"
    perl -Mlib=$TRAVIS_BUILD_DIR/lib /usr/bin/prove -v -f -I$TRAVIS_BUILD_DIR/lib webservice_*.t
    exit $?
fi

exit 0
