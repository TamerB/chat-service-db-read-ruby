#!/bin/sh

cd /app
export MYSQL_USER=mydb_user
export MYSQL_PASS=mydb_pwd
export MYSQL_DEV_HOST=mysql_master
export MYSQL_DEV_PORT=3306
export MYSQL_DEV_DB=mydb
export MYSQL_TEST_HOST=mysql_master
export MYSQL_TEST_PORT=3306
export MYSQL_TEST_DB=mydb
export MYSQL_PROD_DB=mydb
export MYSQL_PROD_HOST=mysql_master
export MYSQL_PROD_PORT=3306
export MYSQL_PROD_USER=mydb_user
export MYSQL_PROD_PASS=mydb_pwd
export ELASTICSEARCH_URL=http://elasticsearch:9200
bundle update
bundle install
bundle exec rake searchkick:reindex CLASS=Message --silent