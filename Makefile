ALIAS              = ymir
BUILD_IMAGE_CLI   ?= php:8.1-cli
####

.DEFAULT_GOAL      = help
PLATFORM          ?= $(shell uname -s)
EXEC_PHP           = php
SYMFONY            = $(EXEC_PHP) bin/console
COMPOSER           = composer
BIN                = $(ALIAS)-application
VERSION           ?= `git describe --tags --always --dirty`
REGISTRY          ?= localhost:5000
DOCKER_GATEWAY    ?= $(shell if [ 'Linux' = "${PLATFORM}" ]; then ip addr show docker0 | awk '$$1 == "inet" {print $$2}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; fi)
COMPOSE            = docker-compose
BASE_IMAGE_CLI    ?= $(BIN)-php-cli:latest
BASE_DOCKERFILE   ?= .docker/images/base/Dockerfile
DEV_PATH          ?= .docker/dev
DEV_DOCKERFILE    ?= $(DEV_PATH)/config/php/Dockerfile
PRIVATE_KEY       ?= `cat ~/.ssh/id_rsa`
IMAGE             ?= $(REGISTRY)/$(BIN)
TAG               ?= $(VERSION)
DEVELOPER_UID     ?= $(shell id -u)

#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
ARG := $(word 2, $(MAKECMDGOALS))
%:
	@:
test-run:
	@echo $(PLATFORM)
help:
	@echo -e '\033[1m make [TARGET] \033[0m'
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
# 	@echo && $(MAKE) -s env-info
alias: ## auto update aliases in docker files (.env, docker-compose.yaml)
	@sed -i 's/!{ALIAS}/'"$(shell sed -n 's/^ALIAS *=//p' Makefile | xargs)"'/g' ./.docker/.env
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------

## -- Composer ---------------------------------------------------------------------------------------------------------
install: composer.lock ## Install vendors according to the current composer.lock file
	$(COMPOSER) install --no-progress --no-suggest --prefer-dist --optimize-autoloader

update: composer.json ## Update vendors according to the composer.json file
	$(COMPOSER) update

## -- Xdebug -----------------------------------------------------------------------------------------------------------
xdebug-setup: ## xdebug gateway setup
	@if [ "Linux" = "$(PLATFORM)" ]; then \
		sed "s/DOCKER_GATEWAY/$(DOCKER_GATEWAY)/g" $(DEV_PATH)/config/php/php-ini-overrides.ini.dist > $(DEV_PATH)/config/php/php-ini-overrides.ini; \
	fi

## -- Docker -----------------------------------------------------------------------------------------------------------
build-base: ## Build base image
	@docker build -t $(REGISTRY)/$(BASE_IMAGE_CLI) --build-arg BASE_IMAGE=$(BUILD_IMAGE_CLI)  -f $(BASE_DOCKERFILE) .

build-dev: ## Build dev image
	@docker build -t $(REGISTRY)/$(BASE_IMAGE_CLI)-dev         \
		--build-arg BASE_IMAGE=$(REGISTRY)/$(BASE_IMAGE_CLI)   \
		--build-arg DEVELOPER_UID=$(DEVELOPER_UID)             \
		-f $(DEV_DOCKERFILE) .

build-prod:	## Build prod image
	@docker build -t $(IMAGE)-cli:$(TAG)                       \
		-t $(IMAGE)-cli:latest                                 \
		--build-arg BASE_IMAGE=$(REGISTRY)/$(BASE_IMAGE_CLI) .

build: build-base build-dev ## Build base and dev image to start development

up: alias xdebug-setup ## Start the project docker containers
	@cd ./.docker && $(COMPOSE) --compatibility up -d

down: ## Remove the docker containers
	@cd ./.docker && $(COMPOSE) down

stop: ## Stop the docker containers
	@cd ./.docker && $(COMPOSE) stop

volume-prune: ## Removes docker volumes
	@cd ./.docker && $(COMPOSE) down -v

clean-images: down ## clean all docker images
	docker rmi $$(docker image ls | grep -w "${ALIAS}-*" | awk '{print $$3}')

env-info:
	@echo -e '\033[1mCurrent docker environment variables \033[0m'
	@cat ./.docker/.env

## -- Project ----------------------------------------------------------------------------------------------------------
console: ## Enter into application container
	@if [ "${ARG}" = 'root' ] || [ "${ARG}" = 'r' ]; then docker exec -it -u root $(BIN) zsh; fi
	@if [ "${ARG}" = '' ] || [ "${ARG}" = 'developer' ]; then docker exec -it $(BIN) zsh; fi

serve: ## rr development serve
	@docker exec -it $(BIN) /application/rr serve -d -v -c /application/.rr.dev.yaml

version: ## Show project version
	@echo version: $(VERSION)

## -- Tests ------------------------------------------------------------------------------------------------------------
test: ## Launch main functional and unit tests
	./vendor/bin/phpunit --testsuite=all

test-unit:
	./vendor/bin/phpunit --testsuite=unit

test-external: phpunit.xml ## Launch tests implying external resources (API, services...)
	./vendor/bin/phpunit --testsuite=external --stop-on-failure

unit-tests: phpunit.xml ## Run unit tests
	./vendor/bin/phpunit -d memory_limit=-1 tests/
	phpmd --ignore-violations-on-exit --exclude "*src/AdWords*,*src/PageSpeedInsights/Infrastructure/Repository/Migrations*,*src/ReferenceData/Infrastructure/Repository/Migration*,*src/ReportProjector/Infrastructure/Repository/Migrations*,*src/ReportSubscription/Infrastructure/Repository/Migrations*" ./src html ./phpmd.xml > md.html

tests-coverage: phpunit.xml ## Run tests with coverage
	php -dxdebug.mode=coverage ./vendor/bin/phpunit -d memory_limit=-1 --testsuite=unit --coverage-text --colors=never --stop-on-failure \
		--coverage-clover clover-coverage.xml --coverage-cobertura=cobertura-coverage.xml --log-junit=junit-coverage.xml \
	&& sed -e 's#/component</source>#</source>#' -e 's#filename="#filename="component/#' cobertura-coverage.xml > cobertura-coverage-adjusted.xml

test-report: clover-coverage.xml ## Show clover coverage report
	php ./tests/coverage/clover-coverage.php analyse ./clover-coverage.xml
## ---------------------------------------------------------------------------------------------------------------------
