include includes.mk

# Short name: Short name, following [a-zA-Z_], used all over the place.
# Some uses for short name:
# - Docker image name
# - Kubernetes service, rc, pod, secret, volume names
SHORT_NAME := registry

VERSION ?= git-$(shell git rev-parse --short HEAD)

# the filepath to this repository, relative to $GOPATH/src
REPO_PATH = github.com/deis/registry

# The following variables describe the containerized development environment
# and other build options
DEV_ENV_IMAGE := quay.io/deis/go-dev:0.7.0
DEV_ENV_WORK_DIR := /go/src/${REPO_PATH}
DEV_ENV_CMD := docker run --rm -v ${CURDIR}:${DEV_ENV_WORK_DIR} -w ${DEV_ENV_WORK_DIR} ${DEV_ENV_IMAGE}
LDFLAGS := "-s -X main.version=${VERSION}"
BINDIR := ./rootfs/opt/registry/sbin

# Legacy support for DEV_REGISTRY, plus new support for DEIS_REGISTRY.
DEIS_REGISTRY ?= ${DEV_REGISTRY}

IMAGE_PREFIX ?= deis


ifeq ($(STORAGE_TYPE),)
  STORAGE_TYPE = fs
endif

# Kubernetes-specific information for Secret, RC, Service, and Image.
SECRET := contrib/kubernetes/manifests/${SHORT_NAME}-${STORAGE_TYPE}-secret.yaml
RC := contrib/kubernetes/manifests/${SHORT_NAME}-rc.yaml
SVC := contrib/kubernetes/manifests/${SHORT_NAME}-service.yaml
IMAGE := ${DEIS_REGISTRY}${IMAGE_PREFIX}/${SHORT_NAME}:${VERSION}

all:
	@echo "Use a Makefile to control top-level building of the project."

build: check-docker
	mkdir -p ${BINDIR}
	${DEV_ENV_CMD} make build-binary

# For cases where we're building from local
# We also alter the RC file to set the image name.
docker-build: check-docker build
	docker build --rm -t ${IMAGE} .

# Push to a registry that Kubernetes can access.
docker-push: check-docker check-registry
	docker push ${IMAGE}

build-binary:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -a -installsuffix cgo -ldflags ${LDFLAGS} -o $(BINDIR)/${SHORT_NAME} main.go

# Deploy is a Kubernetes-oriented target
deploy: kube-secret kube-service kube-rc

kube-secret: check-kubectl
	kubectl create -f ${SECRET}

# Some things, like services, have to be deployed before pods. This is an
# example target. Others could perhaps include kube-volume, etc.
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
