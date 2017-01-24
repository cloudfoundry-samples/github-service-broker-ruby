echo && \
echo && \
echo ">>> RUNNING TESTS FOR SERVICE BROKER" && \
cd service_broker && \
bundle install --deployment && \
bundle exec rake test && \
echo && \
echo && \
echo ">>> RUNNING TESTS FOR SERVICE CONSUMER" && \
cd ../example_app && \
bundle install --deployment && \
bundle exec rake test  && \
cd ..
