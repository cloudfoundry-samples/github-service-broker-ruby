# This rack config file is used to start the service broker application
# when it is deployed as an application on Cloud Foundry

require './broker'
run ServiceBroker.new