github-service-broker-ruby
==========================

##Build Status

[![Build Status](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby.png?branch=develop)](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby) (develop branch)

[![Build Status](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby.png?branch=master)](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby) (master)


## Introduction

A Service Broker is required to integrate any service with a Cloud Foundry instance (for brevity, we'll refer to such an instance simply as "Cloud Foundry") as a [Managed Service](http://docs.cloudfoundry.org/services/).

This repo contains a service broker written as standalone ruby application (based on [Sinatra](https://github.com/sinatra/sinatra)) that implements the [v2.0 Service Broker API (aka Services API, or Broker API)](http://docs.cloudfoundry.org/services/api.html).

Generally, a Service Broker can be a standalone application that communicates with one or more services, or can be implemented as a component of a service itself. I.e. if the service itself is a Ruby on Rails application, the code in this repository could be added into the application (either copied in, or added as a Rails engine).

This Service Broker is intended to provide a simple yet functional, readable example of how Cloud Foundry service brokers operate. Even if you are developing a broker in another language, this should clearly demonstrate the API endpoints you will need to implement. This broker is not meant as an example of best practices for Ruby software design nor does it demonstrate BOSH packaging; for an example of these concepts see [cf-mysql-release](https://github.com/cloudfoundry/cf-mysql-release). 

## Repo Contents

This repo contains two applications, a service broker and an example app which can use instances of the service advertised by the broker. The root directory for the service broker application can be found at `github-service-broker-ruby/service_broker`.

The service broker has been written to be as simple to read as possible. There are three files of note:

* service_broker_app.rb - This is the service broker.
* github_service_helper.rb - This is how the broker interfaces with GitHub.
* config/settings.yml - The config file contains the service catalog advertised by the broker, credentials used by Cloud Foundry to authenticate with the broker, and credentials used by the broker to authenticate with GitHub. 

## The GitHub repo service

In this example, the service provided is the management of repositories inside a single GitHub account owned by the service administrator.

The Service Broker provides 5 basic functions (see [API documentation](http://docs.cloudfoundry.org/services/api.html)):

Function | Resulting action |
-------- | :--------------- |
catalog | Advertises the GitHub repo services and the plans offered.
create | Creates a public repository inside the account. This repository can be thought of as a service instance.
bind | Generates a GitHub deploy key which gives write access to the repository, and makes the key and repository URL available to the application bound to the service instance.
unbind | Destroys the deploy key bound to the service instance.
delete | Deletes the service instance (repository).

The GitHub credentials of the GitHub account adminstrator should be specified in `settings.yml` if you are deploying your own instance of this broker application. We suggest that you create a dedicated GitHub account solely for the purpose of testing this broker (since it will create and destroy repositories).


## The Service Broker

### Configuring the Service Broker

The file `settings.yml` provides configuration for:

1. Basic auth username and password used by Cloud Foundry to authenticate with the service broker
2. Catalog of services, plans, and associated user-facing metadata
3. GitHub account credentials used by the broker to authenticate with the Github service

For this service to be functional, you only need to provide your Github credentials. An access token is used in place of username and password to access your GitHub account. To generate an access token run the following command then copy the value of "token" from the response into the config file.
```
curl -u <your-github-username> -d '{"scopes": ["repo", "delete_repo"], "note": "CF Service Broker"}' https://api.github.com/authorizations
```

### Deploying the Service Broker

This service broker application can be deployed on any environment or hosting service.

For example, to deploy this broker application to Cloud Foundry

1. install the `cf` or `gcf` command line tool
2. log in as a cloud controller admin using `cf login` or `gcf login`
3. fork or clone this git repository
4. add the credentials (username and access token) for the GitHub account in which you want this service broker to provide repository services in `settings.yml`.
5. edit the Basic Auth username and password in `settings.yml`
6. `cd` into the application root directory: `github-service-broker-ruby/service_broker/`
7. run `cf push github-broker` or `gcf push github-broker` to deploy the application to Cloud Foundry
8. register the service broker with CF (instructions [here](http://docs.cloudfoundry.org/services/managing-service-brokers.html#add-broker))
9. make the service plan public (instructions [here](http://docs.cloudfoundry.org/services/access-control.html#enable-access))


## The GitHub Service Consumer example application

We've provided an example application you can push to Cloud Foundry, which can be bound to an instance of the github-repo service. After binding the example application to a service instance, Cloud Foundry makes credentials available in the VCAP_SERVICES environment variable. The application can then use the credentials to make commits to the GitHub repository represented by the bound service instance.

### Deploying the example app


With `cf`:

```
$ cd github-service-broker-ruby/example_app/
$ cf push github-consumer
$ cf create-service github-repo public github-repo-1
$ cf bind-service github-consumer github-repo-1
$ cf services # can be used to verify the binding was created
$ cf restart github-consumer
```

With `gcf`:

```
$ cd github-service-broker-ruby/example_app/
$ gcf push github-consumer
$ gcf create-service github-repo public github-repo-1
$ gcf bind-service github-consumer github-repo-1
$ gcf services # can be used to verify the binding was created
$ gcf restart github-consumer
```

Point your web browser at `http://github-consumer.<your cf domain>` and you should see the example app's interface. If the app has not been bound to a service instance of the github-repo service, you will see a meaningful error. Once the app has been bound and restarted you can click a submit button to make empty commits to the repo represented by the bound service instance.

### Testing the example app

The integration tests verify that the application can make commits and push them to GitHub.

To run the tests, you'll need to create a test account on GitHub, and store the credentials in environment variables (see `example_app/test/integration/github_integration_test.rb` for details)

The integration tests can be run by `bundle exec rake integration_test`.

