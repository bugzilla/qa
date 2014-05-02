#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

QA_REPO="dklawren/qa"
QA_BRANCH="$TRAVIS_BRANCH"

# Setup starts here
cd $TRAVIS_BUILD_DIR

# Package installation section
echo "== Installing OS packages"
sudo apt-get install -y perlmagick apache2 libssl-dev g++ libgd2-xpm-dev xvfb

if [ "$TEST_SUITE" = "docs" ]; then
    if [ "$TRAVIS_BRANCH" = "master" ]; then
        sudo apt-get install -y python-sphinx
    elif [ "$TRAVIS_BRANCH" = "4.4" ]; then
        sudo apt-get install -y xmlto lynx texlive-lang-cyrillic
    else
        sudo apt-get install -y ldp-docbook-dsssl jade jadetex lynx
        export JADE_PUB=/usr/share/sgml/declaration
        export LDP_HOME=/usr/share/sgml/docbook/stylesheet/dsssl/ldp
    fi
fi

if [ "$TEST_SUITE" = "selenium" ] || [ "$TEST_SUITE" = "webservices" ]; then
    sudo apt-get install -y apache2 xvfb
fi

# Install dependencies from Build.PL
echo "== Installing Perl dependencies"
cpanm --quiet --notest --reinstall DateTime
cpanm --quiet --notest --reinstall Module::Build # Need latest build
cpanm --quiet --notest --reinstall Software::License # Needed by Module::Build
cpanm --quiet --notest --reinstall Pod::Coverage
cpanm --quiet --notest --reinstall XMLRPC::Lite # Needed for version 4.2 and earlier
cpanm --quiet --notest --installdeps --with-recommends .

# Basic sanity tests
if [ "$TEST_SUITE" = "sanity" ]; then
    echo "== Running sanity tests"
    perl Build.PL
    ./Build
    ./Build test
    exit $?
fi

# Documentation build testing
if [ "$TEST_SUITE" = "docs" ]; then
    echo "== Running documentation build"
    cd docs
    perl makedocs.pl --with-pdf
    exit $?
fi

# Switch to the correct branch for the QA repo
if [ "$TRAVIS_BRANCH" != "master" ]; then
    echo "== Switch to the proper $TRAVIS_BRANCH QA branch for extended tests"
    cd $TRAVIS_BUILD_DIR/qa
    git checkout $TRAVIS_BRANCH
    if [ ! -f config/selenium_test.conf ]; then
        exit 1
    fi
    cd $TRAVIS_BUILD_DIR
fi

# We need to replace some variables in the config files from the Travis CI environment
echo "== Updating config files"
sed -e "s?%TRAVIS_BUILD_DIR%?$(pwd)?g" --in-place qa/config/selenium_test.conf
sed -e "s?%USER%?$USER?g" --in-place qa/config/checksetup_answers.txt

# Configure Apache to serve from our build directory and restart
sed -e "s?%TRAVIS_BUILD_DIR%?$(pwd)?g" --in-place qa/config/bugzilla.conf
sudo cp qa/config/bugzilla.conf /etc/apache2/sites-available/default
sudo sed -e "s?APACHE_RUN_USER=www-data?APACHE_RUN_USER=$USER?g" --in-place /etc/apache2/envvars
sudo sed -e "s?APACHE_RUN_GROUP=www-data?APACHE_RUN_GROUP=$USER?g" --in-place /etc/apache2/envvars
sudo service apache2 stop; sudo rm -rf /var/lock/apache2; sudo service apache2 start

# Link /usr/bin/perl to the current perlbrew perl so that the Bugzilla cgi scripts will work properly
# PERLBREW_ROOT and PERLBREW_PERL are set by the perlbrew binary when switch perl versions
echo "== Fixing Perl"
sudo mv /usr/bin/perl /usr/bin/perl.bak
sudo ln -s $PERLBREW_ROOT/perls/$PERLBREW_PERL/bin/perl /usr/bin/perl

# We will be using SQLite for our database backend
cpanm --quiet --notest DBD::SQLite

# This is needed for the extended test suite
cpanm --quiet --notest Test::WWW::Selenium

# We have to run checksetup.pl twice as the first run creates localconfig
perl checksetup.pl qa/config/checksetup_answers.txt
perl checksetup.pl qa/config/checksetup_answers.txt

# Create test data in the SQLite database for use by the extended test suite
cd $TRAVIS_BUILD_DIR/qa/config
perl -Mlib=$TRAVIS_BUILD_DIR/lib generate_test_data.pl
cd $TRAVIS_BUILD_DIR/qa/t

# Selenium UI Tests
if [ "$TEST_SUITE" = "selenium" ]; then
    # Start the virtual frame buffer
    echo "== Starting virtual frame buffer"
    export DISPLAY=:99.0
    sh -e /etc/init.d/xvfb start
    sleep 5

    # Download and start the selenium server
    echo "== Downloading and starting Selenium server"
    wget http://selenium-release.storage.googleapis.com/2.41/selenium-server-standalone-2.41.0.jar
    sudo java -jar selenium-server-standalone-2.41.0.jar 1> /dev/null &
    sleep 5

    echo "== Running Selenium UI tests"
    perl -Mlib=$TRAVIS_BUILD_DIR/lib /usr/bin/prove -v -j4 -I$TRAVIS_BUILD_DIR/lib test_*.t
    exit $?
fi

# WebService Tests
if [ "$TEST_SUITE" = "webservices" ]; then
    echo "== Running WebService tests"
    perl -Mlib=$TRAVIS_BUILD_DIR/lib /usr/bin/prove -v -I$TRAVIS_BUILD_DIR/lib webservice_*.t
    exit $?
fi

exit 0
