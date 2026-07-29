SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

.PHONY: help env build build-backend build-frontend test test-backend \
	test-api test-integration test-frontend test-e2e test-performance \
	test-security results check-config

help: ## Muestra los comandos disponibles
	@awk 'BEGIN {FS = ":.*## "; printf "Uso: make <objetivo>\n\n"} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

env: ## Crea o completa el .env local ignorado (modo 0600)
	./scripts/security/init-secret-env.sh local

build: build-backend build-frontend ## Construye backend y frontend

build-backend: ## Construye el backend
	cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew clean assemble --no-daemon

build-frontend: ## Instala dependencias y construye el frontend
	pnpm --dir frontend install --frozen-lockfile
	pnpm --dir frontend build

test: ## Reproduce localmente las fases automatizadas del pipeline
	./scripts/testing/run_all_local_tests.sh

test-backend: ## Ejecuta unitarias backend y quality gate JaCoCo
	cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon
	$(MAKE) results

test-api: ## Ejecuta pruebas API/contrato RestAssured
	cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew apiTest --no-daemon
	$(MAKE) results

test-integration: ## Ejecuta integración con Testcontainers
	cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew integrationTest jacocoIntegrationTestCoverageVerification --no-daemon
	$(MAKE) results

test-frontend: ## Ejecuta Karma con Chromium Playwright en Docker
	pnpm --dir frontend install --frozen-lockfile
	pnpm --dir frontend test

test-e2e: ## Ejecuta Playwright contra un stack Compose aislado
	pnpm --dir tests/e2e test

test-performance: ## Ejecuta smoke k6 contra un stack Compose aislado
	./tests/performance/run-local.sh

test-security: ## Ejecuta headers, OWASP ZAP y Trivy contra Compose
	./tests/security/run-local.sh

results: ## Centraliza resultados disponibles bajo test-results/
	./scripts/testing/collect_local_test_results.sh

check-config: env ## Valida scripts, recolector y modelo Docker Compose
	bash -n \
		frontend/scripts/test-local.sh \
		scripts/testing/collect_local_test_results.sh \
		scripts/testing/local_compose.sh \
		scripts/testing/run_with_java_21.sh \
		scripts/testing/run_all_local_tests.sh \
		tests/e2e/scripts/run-local.sh \
		tests/performance/run-local.sh \
		tests/security/run-local.sh \
		tests/testing/test_local_compose.sh
	python3 -m unittest tests/testing/test_collect_test_results.py
	./tests/testing/test_local_compose.sh
	docker compose \
		--env-file .env \
		--project-name inventory-config-check \
		--project-directory "$(CURDIR)" \
		--file docker-compose.yml \
		--file docker-compose.override.yml \
		config --quiet
