NETWORK_NAME ?= docker-dev
IMAGE_NAME = gatsby-netlify-example

.PHONY: test

.DEFAULT:
	@echo 'App targets:'
	@echo
	@echo '    image            build the Docker image for local development'
	@echo '    deps             install dependancies using Yarn'
	@echo '    local            spin up local environment, e.g. the Gatsby watcher'
	@echo '    local-down       tear down local environment'
	@echo '    test             run unit tests'
	@echo '    serve-staging    build and serve the site pointed to the staging environment'
	@echo '    serve-prod       build and serve the site pointed to the production environment'
	@echo
	@echo 'DevOps targets:'
	@echo
	@echo '    pipeline-build    build the static site for use in the AWS environments'
	@echo '    env-validate      validates that the env variables required for AWS CLI calls are set'
	@echo '    cfn-test          run unit tests and cfn-lint the CloudFormation templates'
	@echo '    cfn-app           create/update the app CloudFormation stack'
	@echo '    cfn-pipeline      create/update the pipeline CloudFormation stack'
	@echo

default: .DEFAULT

image:
	docker build . -f docker/Dockerfile --target dev -t $(IMAGE_NAME):dev

deps:
	docker-compose run --rm --service-ports app yarn

local: local-down
	NETWORK_NAME="$(NETWORK_NAME)" docker-compose up

local-down:
	NETWORK_NAME="$(NETWORK_NAME)" docker-compose down

test:
	docker-compose run --rm app yarn test

serve-staging: image deps
	NETWORK_NAME="$(NETWORK_NAME)" docker-compose run --rm --service-ports app yarn serve-staging

serve-prod: image deps
	NETWORK_NAME="$(NETWORK_NAME)" docker-compose run --rm --service-ports app yarn serve-prod


# Ops targets.
APP_NAME = asa-test
BUILD_TAG ?= latest
APP_PATH = /site

TOOLS_BASE = docker run -v $$(pwd):$(APP_PATH) -v $(HOME)/.aws:/root/.aws:ro -w $(APP_PATH)
TOOLS_IMAGE ?= "495315319309.dkr.ecr.us-east-1.amazonaws.com/kedge-tools"
TOOLS = ${TOOLS_BASE} \
			-e "AWS_REGION=$(AWS_REGION)" \
			-e "ENVIRONMENT_NAME=$(ENVIRONMENT_NAME)" \
			$(TOOLS_IMAGE)

pipeline-build: env-validate
	docker build . -f docker/Dockerfile --target final --build-arg LOCATION="$(ENVIRONMENT_NAME)" -t $(IMAGE_NAME):$(BUILD_TAG)

env-validate:
	@test $(AWS_REGION) || (echo "no AWS_REGION"; exit 1)
	@test $(ENVIRONMENT_NAME) || (echo "no ENVIRONMENT_NAME"; exit 1)
	@echo "AWS_REGION=$(AWS_REGION)\n ENVIRONMENT_NAME=$(ENVIRONMENT_NAME)" && sleep 2

cfn-test: env-validate
	${TOOLS_BASE} $(TOOLS_IMAGE) bash -c "cfn-lint.sh $(APP_PATH)/ops/cloudformation/*.yml"

cfn-app: cfn-test
	${TOOLS} sed 's/GIT_COMMIT/$(BUILD_TAG)/g' ops/$(ENVIRONMENT_NAME)/app.json > app.json
	${TOOLS} cfn.sh \
		app.json \
		ops/cloudformation/app.yml \
		$(update)

cfn-pipeline: cfn-test
	${TOOLS} cfn.sh \
		ops/$(ENVIRONMENT_NAME)/pipeline.json \
		ops/cloudformation/pipeline.yml \
		$(update)
