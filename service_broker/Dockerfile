FROM ruby:2.0.0
RUN mkdir /sb
COPY . /sb
WORKDIR /sb
RUN bundle install
CMD rackup
