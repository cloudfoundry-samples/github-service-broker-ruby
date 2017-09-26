FROM ruby:2.4.2
RUN mkdir /sb
COPY . /sb
WORKDIR /sb
RUN bundle install
CMD rackup
