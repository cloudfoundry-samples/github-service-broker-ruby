FROM ruby:2.0.0
RUN mkdir /sb
COPY . /sb
WORKDIR /sb
RUN bundle install
EXPOSE 9292
CMD rackup
