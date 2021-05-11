FROM ruby:2.6.7
RUN mkdir /sb
COPY . /sb
WORKDIR /sb
RUN bundle install
CMD rackup
