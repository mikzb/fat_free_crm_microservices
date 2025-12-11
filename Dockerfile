# Usage:
# docker volume create pgdata
# docker volume create gems
# docker-compose up
# docker-compose exec web bundle exec rake db:create db:schema:load ffcrm:demo:load
# docker-compose exec web bundle exec rails assets:precompile

# --- REVERTED ---
# Go back to Ruby 3.3, as you requested.
FROM ruby:3.3

LABEL author="Steve Kenworthy"

ENV HOME /home/app

RUN mkdir -p $HOME

WORKDIR $HOME

RUN apt-get update && \
    apt-get install -y \
        default-libmysqlclient-dev \
        mariadb-client \
        imagemagick \
        tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoremove -y

# Install gems in a cached layer
COPY Gemfile Gemfile.lock fat_free_crm.gemspec ./
COPY lib ./lib


# Install bundler and bundle gems
# This layer will be cached as long as your Gemfile.lock doesn't change
RUN gem install bundler && \
    bundle config set --local deployment 'true' && \
    bundle install

COPY . $HOME

EXPOSE 3000

CMD ["bundle","exec","rails","s"]