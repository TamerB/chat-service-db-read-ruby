FROM ruby:3.1.3

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs cron curl

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler --no-document
RUN bundle install

COPY . .

RUN crontab reindex_cron

CMD ["rails", "server", "-b", "0.0.0.0", "e", "production"]