pipeline {
    agent any
    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }
    parameters {
        booleanParam(name: 'SIMULATE_BAD_RELEASE', defaultValue: false,
          description: 'Local lab only: deploy an unhealthy release to test rollback.')
    }
    environment {
        APP_NAME = 'demo-app'
        NAMESPACE = 'devops-demo'
        IMAGE_NAME = 'demo-app'
        HELM_CHART = 'helm/demo-app'
        PATH = '/opt/homebrew/bin:/usr/local/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git --version'
            }
        }
        stage('Unit Tests') {
            steps {
                sh '''
                    set -eu
                    python3 -m venv .venv
                    .venv/bin/python -m pip install --upgrade pip
                    .venv/bin/pip install -r app/requirements.txt
                    .venv/bin/python -m unittest discover -s tests -v
                '''
            }
        }
        stage('Build Container') {
            steps {
                sh '''
                    set -eu
                    docker version
                    docker build --pull -t "${IMAGE_NAME}:${BUILD_NUMBER}" .
                '''
            }
        }
        stage('Security Scan') {
            steps {
                sh '''
                    set -eu
                    # Informational for this lab. Change exit-code 0 to 1 to block on findings.
                    trivy image --no-progress --severity HIGH,CRITICAL --exit-code 0 "${IMAGE_NAME}:${BUILD_NUMBER}"
                '''
            }
        }
        stage('Load Image into Minikube') {
            steps {
                sh '''
                    set -eu
                    minikube status
                    minikube image load "${IMAGE_NAME}:${BUILD_NUMBER}"
                '''
            }
        }
        stage('Deploy, Verify and Roll Back if Needed') {
            steps {
                sh '''
                    set -eu
                    export APP_NAME="${APP_NAME}"
                    export NAMESPACE="${NAMESPACE}"
                    export IMAGE_NAME="${IMAGE_NAME}"
                    export IMAGE_TAG="${BUILD_NUMBER}"
                    export HELM_CHART="${HELM_CHART}"
                    export SIMULATE_BAD_RELEASE="${SIMULATE_BAD_RELEASE}"
                    bash scripts/deploy_with_rollback.sh
                '''
            }
        }
    }
    post {
        always {
            sh '''
                echo "Build ${BUILD_NUMBER} finished; see Jenkins result above."
                kubectl get pods -n "${NAMESPACE}" 2>/dev/null || true
                helm history "${APP_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
            '''
        }
        success { echo 'Pipeline succeeded: release deployed and health checks passed.' }
        failure { echo 'Pipeline failed. Review stage logs and rollback output.' }
    }
}
