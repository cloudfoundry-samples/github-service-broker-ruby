# This rack config file is used to start the service consumer application
# when it is deployed as an application on Cloud Foundry

require './service_consumer_app'
run ServiceConsumerApp.new