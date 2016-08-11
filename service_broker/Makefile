DOCKER_REPO ?= quay.io/
DOCKER_USER ?= deis
DOCKER_VERSION ?= latest

DOCKER_IMAGE ?= ${DOCKER_REPO}${DOCKER_ORG}/cloudfoundry-github-service-broker:${VERSION}

docker-build:
	docker build -t ${DOCKER_IMAGE} .
docker-push:
	docker push ${DOCKER_IMAGE}
