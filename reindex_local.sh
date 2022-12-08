#!/bin/sh

cd <directory> # Update <directory> with your local project directory path
source </usr/local/rvm/environments/ruby-3.1.3-rvm@mygemset> # Update <mygemset> with your gemset (for gemset environment variables)
source /home/<username>/.profile # Update <username> with your username (for custom environment variables)
bundle exec rake searchkick:reindex CLASS=Message --silent RAILS_ENV=production 2>&1