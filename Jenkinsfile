pipeline {
    agent { label 'linux && docker' }

    parameters {
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'develop',
            description: 'Rama confiable que fue seleccionada por el job Jenkins'
        )
        booleanParam(
            name: 'RUN_SONAR',
            defaultValue: false,
            description: 'Ejecutar SonarCloud (requiere la credencial sonarcloud-token)'
        )
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        GRADLE_USER_HOME = "/opt/gradle-cache"
        COMPOSE_PROJECT_NAME = "inventory-jenkins-${BUILD_TAG}"
        CI = 'true'
        E2E_STACK_TIMEOUT_MS = '360000'
        PNPM_VERSION = '10.12.1'
        TESTCONTAINERS_HOST_OVERRIDE = 'docker'
        PLAYWRIGHT_BROWSERS_PATH = '/ms-playwright'
        POSTGRES_PORT = '55433'
        BACKEND_PORT = '18082'
        KEYCLOAK_PORT = '18081'
        FRONTEND_PORT = '15173'
        PROMETHEUS_PORT = '19090'
        GRAFANA_PORT = '13000'
        KEYCLOAK_URL = 'http://docker:18081'
        E2E_BASE_URL = 'http://docker:15173'
        E2E_BACKEND_URL = 'http://docker:18082'
        E2E_KEYCLOAK_URL = 'http://docker:18081'
        PLAYWRIGHT_RETAIN_SENSITIVE_ARTIFACTS = 'false'
        PLAYWRIGHT_SAFE_REPORTING = 'true'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Trusted Pipeline Guard') {
            steps {
                script {
                    if (env.CHANGE_FORK?.trim()) {
                        error('Jenkins pipeline with Docker and secrets is disabled for forked pull requests.')
                    }
                }
            }
        }

        stage('Environment') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    export COMPOSE_PROJECT_NAME="$(printf '%s' "${COMPOSE_PROJECT_NAME}" | tr -c '[:alnum:]_-' '-' | tr '[:upper:]' '[:lower:]')"
                    echo "COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}" > .jenkins-compose.env
                    ./scripts/security/init-secret-env.sh local
                    java -version
                    docker version
                    docker compose version
                    chmod +x backend/gradlew
                    pnpm --version
                    test "$(pnpm --version)" = "${PNPM_VERSION}"
                '''
            }
        }

        stage('Backend Build') {
            steps {
                dir('backend') {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        ./gradlew clean assemble --no-daemon --stacktrace
                    '''
                }
            }
        }

        stage('Unit Tests + Coverage Gate') {
            steps {
                dir('backend') {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon --stacktrace
                    '''
                }
            }
        }

        stage('Integration Tests') {
            steps {
                dir('backend') {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        ./gradlew integrationTest --no-daemon --stacktrace
                    '''
                }
            }
        }

        stage('API Tests') {
            steps {
                dir('backend') {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        ./gradlew apiTest --no-daemon --stacktrace
                    '''
                }
            }
        }

        stage('Frontend Build') {
            steps {
                dir('frontend') {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        pnpm install --frozen-lockfile
                        pnpm build
                    '''
                }
            }
        }

        stage('Security Scan') {
            parallel {
                stage('Frontend Dependency Audit') {
                    steps {
                        dir('frontend') {
                            catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                                sh '''#!/usr/bin/env bash
                                    set -euo pipefail
                                    pnpm audit --prod --json | tee ../frontend-audit.json
                                '''
                            }
                        }
                    }
                }

                stage('SonarCloud Quality Analysis') {
                    when {
                        expression { params.RUN_SONAR }
                    }
                    steps {
                        withCredentials([string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')]) {
                            dir('backend') {
                                sh '''#!/usr/bin/env bash
                                    set -euo pipefail
                                    set +x
                                    ./gradlew sonar --no-daemon
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    . ./.jenkins-compose.env
                    docker compose -p "${COMPOSE_PROJECT_NAME}" build backend frontend
                '''
            }
        }

        stage('Deploy Preview') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    . ./.jenkins-compose.env
                    docker compose -p "${COMPOSE_PROJECT_NAME}" up --build -d
                    docker compose -p "${COMPOSE_PROJECT_NAME}" ps
                '''
            }
        }

        stage('E2E Tests') {
            steps {
                dir('tests/e2e') {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        pnpm install --frozen-lockfile
                        pnpm exec playwright install chromium firefox webkit
                        E2E_MANAGE_STACK=false pnpm run stack:ready
                        pnpm exec playwright test
                    '''
                }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'backend/build/test-results/**/*.xml'

            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'backend/build/reports/tests/test',
                reportFiles: 'index.html',
                reportName: 'Unit Test Report'
            ])

            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'backend/build/reports/tests/integrationTest',
                reportFiles: 'index.html',
                reportName: 'Integration Test Report'
            ])

            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'backend/build/reports/tests/apiTest',
                reportFiles: 'index.html',
                reportName: 'API Test Report'
            ])

            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'backend/build/reports/jacoco/test/html',
                reportFiles: 'index.html',
                reportName: 'JaCoCo Unit Coverage'
            ])

            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'backend/build/reports/jacoco/integrationTest/html',
                reportFiles: 'index.html',
                reportName: 'JaCoCo Integration Coverage'
            ])

            junit allowEmptyResults: true, testResults: 'test-results/e2e/playwright/evidence/junit/*.xml'

            script {
                String suiteStatus = currentBuild.currentResult == 'SUCCESS' ? 'passed' : 'failed'
                sh """#!/usr/bin/env bash
                    set -euo pipefail
                    python3 scripts/testing/collect_test_results.py \
                        --suite backend/unit \
                        --status '${suiteStatus}' \
                        --junit backend/build/test-results/test \
                        --copy junit=backend/build/test-results/test \
                        --copy html=backend/build/reports/tests/test \
                        --copy coverage=backend/build/reports/jacoco/test \
                        --metadata 'workflow=Jenkins'
                    python3 scripts/testing/collect_test_results.py \
                        --suite backend/integration \
                        --status '${suiteStatus}' \
                        --junit backend/build/test-results/integrationTest \
                        --copy junit=backend/build/test-results/integrationTest \
                        --copy html=backend/build/reports/tests/integrationTest \
                        --copy coverage=backend/build/reports/jacoco/integrationTest \
                        --metadata 'workflow=Jenkins'
                    python3 scripts/testing/collect_test_results.py \
                        --suite backend/api \
                        --status '${suiteStatus}' \
                        --junit backend/build/test-results/apiTest \
                        --copy junit=backend/build/test-results/apiTest \
                        --copy html=backend/build/reports/tests/apiTest \
                        --metadata 'workflow=Jenkins'
                    python3 scripts/testing/collect_test_results.py \
                        --suite frontend/unit \
                        --status unknown \
                        --copy coverage=frontend/coverage \
                        --metadata 'workflow=Jenkins' \
                        --metadata 'execution=not-run-by-this-pipeline'
                    python3 scripts/testing/collect_test_results.py \
                        --suite e2e/playwright \
                        --status '${suiteStatus}' \
                        --junit test-results/e2e/playwright/evidence/junit \
                        --metadata 'workflow=Jenkins'
                """
            }

            archiveArtifacts allowEmptyArchive: true, artifacts: 'backend/build/libs/*.jar,frontend/dist/**,frontend-audit.json,test-results/backend/**,test-results/frontend/**'

            script {
                if (fileExists('test-results/e2e/playwright/summary.json')) {
                    int artifactSafetyStatus = sh(
                        script: '''#!/usr/bin/env bash
                            set -euo pipefail
                            ./scripts/security/verify-artifacts.sh test-results/e2e/playwright
                        ''',
                        returnStatus: true
                    )
                    if (artifactSafetyStatus == 0) {
                        archiveArtifacts(
                            allowEmptyArchive: false,
                            artifacts: 'test-results/e2e/playwright/**'
                        )
                    } else {
                        echo 'Playwright evidence was withheld because artifact safety did not pass.'
                        currentBuild.result = 'FAILURE'
                    }
                } else {
                    echo 'No Playwright evidence was generated; nothing was archived.'
                }
            }

            sh '''#!/usr/bin/env bash
                set +e
                if [ -f .jenkins-compose.env ]; then
                    . ./.jenkins-compose.env
                fi
                docker compose -p "${COMPOSE_PROJECT_NAME:-inventory-jenkins-${BUILD_NUMBER}}" down -v --remove-orphans
            '''

            cleanWs(
                deleteDirs: true,
                disableDeferredWipeout: true,
                notFailBuild: true
            )
        }
    }
}
