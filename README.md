github-service-broker-ruby
==========================

##Build Status

[![Build Status](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby.png?branch=develop)](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby) (develop branch)

[![Build Status](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby.png?branch=master)](https://travis-ci.org/cloudfoundry-samples/github-service-broker-ruby) (master)


## Introduction

A Service Broker is required to integrate any service with a Cloud Foundry instance (for brevity, we'll refer to such an instance simply as "Cloud Foundry") as a [Managed Service](http://docs.cloudfoundry.com/docs/running/architecture/services/#managed).

This repo contains a service broker written as standalone ruby application (based on [Sinatra](https://github.com/sinatra/sinatra)) that implements the [v2.0 Service Broker API (aka Services API, or Broker API)](http://docs.cloudfoundry.com/docs/running/architecture/services/writing-service.html).

Generally, a Service Broker can be a standalone application that communicates with one or more services, or can be implemented as a component of a service itself. I.e. if the service itself is a Ruby on Rails application, the code in this repository could be added into the application (either copied in, or added as a Rails engine).

This Service Broker is intended to provide a simple yet functional, readable example of how Cloud Foundry service brokers operate. Even if you are developing a broker in another language, this should clearly demonstrate the API endpoints you will need to implement. This broker is not meant as an example of best practices for ruby software design (the entire broker is intentionally one file for readability) nor does it demonstrate BOSH packaging; for an example of these concepts see [cf-mysql-release](https://github.com/cloudfoundry/cf-mysql-release). 

## Repo Contents

This repo contains two applications, a service broker and an example app which can use instances of the service advertised by the broker. The root directory for the service broker application can be found at `github-service-broker-ruby/service_broker`.

The service broker has been written to be as simple to read as possible. There are three files of note:

* service_broker_app.rb - This is the service broker.
* github_service_helper.rb - This is how the broker interfaces with GitHub.
* config/settings.yml - The config file contains the service catalog advertised by the broker, credentials used by Cloud Foundry to authenticate with the broker, and credentials used by the broker to authenticate with GitHub. 

## The GitHub repo service

In this example, the service provided is the management of repositories inside a single GitHub account owned by the service administrator.

The Service Broker provides 5 basic functions:

Function | Resulting action |
-------- | :--------------- |
catalog | advertises the GitHub repo services and the plans offered.
create | creates a public repository inside the account. This repository can be thought of as a service instance.
bind | generates a GitHub deploy key which gives write access to the repository, and makes the key and repository URL available to the application bound to the service instance.
unbind | destroys the deploy key bound to the service instance.
delete | deletes the service instance (repository).

The GitHub credentials of the GitHub account adminstrator should be specified in `settings.yml` if you are deploying your own instance of this broker application. We suggest that you create a dedicated GitHub account solely for the purpose of testing this broker (since it will create and destroy repositories).


## Configuring the Service Broker

The file `settings.yml` provides configuration for:

1. Basic auth username and password used by Cloud Foundry to authenticate with the service broker
2. Catalog of services, plans, and associated user-facing metadata
3. GitHub account credentials used by the broker to authenticate with the Github service

For this service to be functional, you only need to provide your Github credentials. An access token is used in place of username and password to access your GitHub account. To generate an access token run the following command then copy the value of "token" from the response into the config file.
```
curl -u <your-github-username> -d '{"scopes": ["repo", "delete_repo"], "note": "CF Service Broker"}' https://api.github.com/authorizations
```

## Deployment

This service broker application can be deployed on any environment or hosting service.

For example, to deploy this broker application to Cloud Foundry

1. install the `cf` or `gcf` command line tool
2. log in as a cloud controller admin using `cf login` or `gcf login`
3. fork or clone this git repository
4. add the credentials (username and access token) for the GitHub account in which you want this service broker to provide repository services in `settings.yml`.
5. edit the Basic Auth username and password in `settings.yml`
6. `cd` into the application root directory: `github-service-broker-ruby/service_broker/`
7. run `cf push github-broker` or `gcf push github-broker` to deploy the application to Cloud Foundry

## Adding the Service Broker

In order for Cloud Foundry to make a service available to applications deployed on it, the service broker must be added to Cloud Foundry.


Adding a service to Cloud Foundry involves two steps:

1. Register the service broker with Cloud Foundry
2. Make the service plans advertised by the broker public in Cloud Foundry marketplace

### Registering the Service Broker

The `cf add-service-broker` command is used to register the broker. The meaning of each field is described below:

Field | Value |
-------- | :--------------- |
Name | A unique name for the broker
URL | The unique URL at which the service broker is running
Username | Basic Auth username needed for Cloud Foundry to access the endpoints on the service broker
Password | Basic Auth password


```
> cf add-service-broker
Name> github-repo-broker

URL> http://github-repo-service-broker.10.244.0.34.xip.io

Username> admin

Password> password

Adding service broker github-repo-broker... OK
```

If the incorrect credentials are provided, `cf` returns a unhelpful error: 
```
CFoundry::ServerError: 10001: The service broker API returned an error from http://github-broker.primo.cf-app.com/v2/catalog: 404 Not Found
```
`gcf` provides a meaningful error:
```
Server error, status code: 500, error code: 10001, message: Authentication failed for the service broker API. Double-check that the username and password are correct: http://github-broker.primo.cf-app.com/v2/catalog
```
If you receive the following errors, check your broker logs. You may have an internal error.

`cf`
```
CFoundry::ServerError: 10001: The service broker API returned an error from http://github-broker.primo.cf-app.com/v2/catalog: 500 Internal Server Error
```
`gcf`
```
Server error, status code: 500, error code: 10001, message: The service broker API returned an error from http://github-broker.primo.cf-app.com/v2/catalog: 500 Internal Server Error
```

If your unique_ids for service and plan are not unique, you should get an error. Currently these errors aren't helpful, but it's a known issue and will be fixed soon.

For 'gcf' the error isn't helpful:
```
Server error, status code: 400, error code: 10004, message: The request is invalid
```
A similar error for 'cf' 
```
CFoundry::InvalidRequest: 10004: The request is invalid
```


To verify that the broker has been added successfully:

```
> cf service-brokers
Getting service brokers... OK

Name            URL
github-repo     http://github-repo-service-broker.10.244.0.34.xip.io
```

`cf` allows an admin to see services imported from the broker before end users can. `gcf` does not support this. 

```
> cf services --marketplace
Getting services... OK

service       version   provider   plans    description                                           
github-repo   n/a       n/a        public   Provides read and write access to a GitHub repository.
```

### Making the Service Plans Public

Please refer to the "Making a Plan Public" section of [Managing Service Brokers](http://docs.cloudfoundry.com/docs/running/architecture/services/managing-service-brokers.html#make-plan-public) for instructions on making plans public.


### Adding multiple service brokers

Multiple service brokers may be added to a Cloud Foundry, but the following constraints must be kept in mind:

- It's not possible to have multiple brokers with the same name
- It's not possible to have multiple brokers with the same URL
- The service id and plan ids of each service advertised by the broker must be unique across Cloud Foundry (GUIDs should be used for these fields)

## The Github Consumer example application

We've provided an example application you can push to Cloud Foundry, which can be bound to an instance of the github-repo service. After binding the example application to a service instance, Cloud Foundry makes credentials available in the VCAP_SERVICES environment variable. The application can then use the credentials to make commits to the GitHub repo represented by the bound service instance.

### Deploying the example app

```
$ cd github-service-broker-ruby/example_app/
$ gcf push github-consumer
$ gcf create-service github-repo public github-repo-1
$ gcf bind-service github-consumer github-repo-1
$ gcf restart github-consumer
```

Point your web browser at `http://github-consumer.<your cf domain>` and you should see the example app's interface. If the app has not been bound to a service instance of the github-repo service, you will see a meaningful error. Once the app has been bound and restarted you can click a submit button to make empty commits to the repo represented by the bound service instance.

## Misc
The Cloud Foundry commands used in this document were verified using CLI tools of the following versions:

```
cf 5.4.3
```

```
gcf version 6.0.0.rc1-d04428f293
```
