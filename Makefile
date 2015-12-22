include includes.mk

# Short name: Short name, following [a-zA-Z_], used all over the place.
# Some uses for short name:
# - Docker image name
# - Kubernetes service, rc, pod, secret, volume names
SHORT_NAME := registry

VERSION ?= git-$(shell git rev-parse --short HEAD)

# Legacy support for DEV_REGISTRY, plus new support for DEIS_REGISTRY.
DEIS_REGISTRY ?= ${DEV_REGISTRY}

IMAGE_PREFIX ?= deis

# Kubernetes-specific information for RC, Service, and Image.
RC := contrib/kubernetes/manifests/${SHORT_NAME}-rc.yaml
SVC := contrib/kubernetes/manifests/${SHORT_NAME}-service.yaml
IMAGE := ${DEIS_REGISTRY}/${IMAGE_PREFIX}/${SHORT_NAME}:${VERSION}

all:
	@echo "Use a Makefile to control top-level building of the project."

build:
	@echo "Nothing to build. Use 'make docker-build' to build the image."

# For cases where we're building from local
# We also alter the RC file to set the image name.
docker-build: check-docker
	docker build --rm -t ${IMAGE} .

# Push to a registry that Kubernetes can access.
docker-push: check-docker check-registry
	docker push ${IMAGE}

# Deploy is a Kubernetes-oriented target
deploy: kube-service kube-rc

# Some things, like services, have to be deployed before pods. This is an
# example target. Others could perhaps include kube-secret, kube-volume, etc.
kube-service: check-kubectl
	kubectl create -f ${SVC}

# When possible, we deploy with RCs.
kube-rc: check-kubectl
	kubectl create -f ${RC}

kube-clean: check-kubectl
	kubectl delete rc ${SHORT_NAME}

test: check-docker
	contrib/ci/test.sh ${IMAGE}

update-manifests:
	sed 's#\(image:\) .*#\1 $(IMAGE)#' contrib/kubernetes/manifests/${SHORT_NAME}-rc.yaml \
		> ${RC}

.PHONY: all build kube-up kube-down deploy
