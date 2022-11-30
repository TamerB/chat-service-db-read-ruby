# Chat Service DB Read Ruby
## Overview
This service listens for DB read messages from [chat service](https://github.com/TamerB/chat-service-ruby) over RabbitMQ (RPC requests), passes them to MySQL DB and replys to chat service with results over RabbitMQ.

This service has the following API endpoints:
```
/readyz             GET
/healthz            GET
```

## Developer setup
#### Setup locally
This service uses Ruby version ruby-3.1.3.
From the project's root directory:

```
# to install ruby and set gemset using rvm
rvm use --create ruby-3.1.3-rvm@chat-read
bundle # to install required gems
# to create database (required if database doesn't exist)
rake db:create # or rails db:create
# to make migrations (reqired if there're missing migrations in database)
rake db:migrate # or rails db:migrate
```

## Running locally
```bash
#!/bin/sh

export PORT=<e.g. 3000>
export MQ_HOST=<e.g. 127.0.0.1>
export MYSQL_USER=<e.g. mydb_user>
export MYSQL_PASS=<e.g. mydb_pwd>
export MYSQL_DEV_HOST=<e.g. 127.0.0.1>
export MYSQL_DEV_PORT=<e.g. 3306>
export DEV_DB=<e.g. mydb>
export SQL_PROD_DB=<e.g. mydb>
export SQL_PROD_HOST=<e.g. 127.0.0.1>
export SQL_PROD_PORT=<e.g. 3306>
export SQL_PROD_USER=<e.g. mydb_user>
export SQL_PROD_PASS=<e.g. mydb_pwd>
export ELASTICSEARCH_URL=<e.g. http://127.0.0.1:9200>

rails s
```

### Environment Variables
#### `PORT`
Ports which the service will be listening on to `http` requests.
#### `MQ_HOST`
RabbitMQ host
#### `MYSQL_USER`
Database username
#### `MYSQL_PASS`
Database password
#### `MYSQL_DEV_HOST`
Database hostname for development run
#### `MYSQL_DEV_PORT`
Database password
#### `DEV_DB`
Database name
#### `SQL_PROD_DB`
Database name for production
#### `SQL_PROD_HOST`
Database password for production
#### `SQL_PROD_PORT`
Disables port for production
#### `SQL_PROD_USER`
Database username for production
#### `SQL_PROD_PASS`
Database password for production
#### `ELASTICSEARCH_URL`
Elasticsearch HOST

## Build Docker image
```
docker build -t chat-read:latest .
```

## Test (not currently present)
To run tests, from the project's root directory, run `rails test ./...` in terminal.

## Notes
- This service uses MySQL for development and production. And uses Sqlite for testing.
- When testing [chat service](https://github.com/TamerB/chat-service-ruby), you will need to run this service. Please make sure to use a testing MySQL database in production or use Sqlite by modifying `config/database.yml`.