pipeline {
    agent { label 'linux && docker' }

    tools {
        jdk 'temurin-21'
    }

    options {
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        GRADLE_USER_HOME = "${WORKSPACE}/.gradle"
        COMPOSE_PROJECT_NAME = "inventory-jenkins-${BUILD_TAG}"
        CI = 'true'
        E2E_STACK_TIMEOUT_MS = '360000'
        PNPM_VERSION = '10.12.1'
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
                    java -version
                    docker version
                    docker compose version
                    chmod +x backend/gradlew
                    corepack enable
                    corepack prepare "pnpm@${PNPM_VERSION}" --activate
                    pnpm --version
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
                        pnpm exec playwright install --with-deps chromium || pnpm exec playwright install chromium
                        E2E_MANAGE_STACK=false pnpm run stack:ready
                        PLAYWRIGHT_JUNIT_OUTPUT_NAME=playwright-results.xml pnpm exec playwright test
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

            junit allowEmptyResults: true, testResults: 'tests/e2e/playwright-results.xml'

            publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'tests/e2e/playwright-report',
                reportFiles: 'index.html',
                reportName: 'Playwright E2E Report'
            ])

            archiveArtifacts allowEmptyArchive: true, artifacts: 'backend/build/libs/*.jar,backend/build/reports/**,backend/build/test-results/**,backend/build/jacoco/*.exec,frontend/dist/**,frontend-audit.json,tests/e2e/playwright-results.xml,tests/e2e/playwright-report/**,tests/e2e/test-results/**'

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