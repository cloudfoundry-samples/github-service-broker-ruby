# This rack config file is used to start the service broker application
# when it is deployed as an application on Cloud Foundry

require './service_broker_app'
run ServiceBrokerApp.new