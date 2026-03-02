// RF Automation Jenkins Pipeline
// Professional CI/CD pipeline for Robot Framework test execution
// Supports: Build, Test, Report, and Archive

pipeline {
    agent any

    // Environment variables
    environment {
        DOCKER_IMAGE = "rf-test-runner"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        RESULTS_DIR = "${env.WORKSPACE}/results"
        LOGS_DIR = "${env.WORKSPACE}/logs"
        ALLURE_RESULTS_DIR = "${env.WORKSPACE}/allure-results"
        ALLURE_REPORT_DIR = "${env.WORKSPACE}/allure-report"
        ELASTIC_ENDPOINT = "http://localhost:9200"
        PROJECT_NAME = "RF-Automation"
    }

    // Build parameters
    parameters {
        choice(
            name: 'TEST_SUITE',
            choices: ['all', 'rf_functional', 'calibration'],
            description: 'Which test suite to run?'
        )
        choice(
            name: 'LOG_LEVEL',
            choices: ['INFO', 'DEBUG', 'TRACE'],
            description: 'Robot Framework log level'
        )
        booleanParam(
            name: 'SKIP_DOCKER_BUILD',
            defaultValue: false,
            description: 'Skip Docker image rebuild (use cached image)'
        )
    }

    // Pipeline options
    options {
        buildDiscarder(logRotator(numToKeepStr: '30', daysToKeepStr: '60'))
        timestamps()
        timeout(time: 2, unit: 'HOURS')
        disableConcurrentBuilds()
    }

    stages {

        stage('Initialize') {
            steps {
                script {
                    echo "=========================================="
                    echo "RF Automation Pipeline - Build #${env.BUILD_NUMBER}"
                    echo "=========================================="
                    echo "Branch: ${env.GIT_BRANCH}"
                    echo "Test Suite: ${params.TEST_SUITE}"
                    echo "Log Level: ${params.LOG_LEVEL}"
                    echo "=========================================="
                }

                // Create directories
                sh '''
                    mkdir -p ${RESULTS_DIR}
                    mkdir -p ${LOGS_DIR}
                    mkdir -p ${ALLURE_RESULTS_DIR}
                    mkdir -p ${ALLURE_REPORT_DIR}
                    rm -rf ${RESULTS_DIR}/*
                    rm -rf ${LOGS_DIR}/*
                    rm -rf ${ALLURE_RESULTS_DIR}/*
                    rm -rf ${ALLURE_REPORT_DIR}/*
                '''

                // Verify prerequisites
                sh '''
                    echo "Checking prerequisites..."
                    docker --version
                    python3 --version
                    curl --version
                '''
            }
        }

        stage('Build Docker Image') {
            when {
                expression { params.SKIP_DOCKER_BUILD == false }
            }
            steps {
                script {
                    echo "Building Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }

                sh '''
                    docker build \
                        -t ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        -t ${DOCKER_IMAGE}:latest \
                        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                        --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                        .
                '''

                sh 'docker images | grep ${DOCKER_IMAGE}'
            }
        }

        stage('Verify Infrastructure') {
            steps {
                script {
                    echo "Verifying ELK Stack availability..."
                }

                sh '''
                    # Check Elasticsearch
                    curl -s -f ${ELASTIC_ENDPOINT}/_cluster/health || {
                        echo "WARNING: Elasticsearch not available at ${ELASTIC_ENDPOINT}"
                        echo "Test results will be saved locally only"
                    }

                    # Check Kibana (optional)
                    curl -s -f http://localhost:5601/api/status || {
                        echo "WARNING: Kibana not available"
                    }
                '''
            }
        }

        stage('Execute Tests') {
            steps {
                script {
                    def testPath = params.TEST_SUITE == 'all' ? 'tests/' : "tests/${params.TEST_SUITE}.robot"
                    echo "Executing tests: ${testPath}"
                }

                sh '''
                    # Determine test path
                    if [ "${TEST_SUITE}" = "all" ]; then
                        TEST_PATH="tests/"
                    else
                        TEST_PATH="tests/${TEST_SUITE}.robot"
                    fi

                    # Run tests in Docker with host network mode
                    # Enable Allure listener for result collection
                    docker run --rm \
                        --network host \
                        -v ${RESULTS_DIR}:/app/results \
                        -v ${LOGS_DIR}:/app/logs \
                        -v ${ALLURE_RESULTS_DIR}:/app/allure-results \
                        -e LOG_LEVEL=${LOG_LEVEL} \
                        ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        --outputdir results \
                        --loglevel ${LOG_LEVEL} \
                        --timestampoutputs \
                        --name "${PROJECT_NAME}_Build_${BUILD_NUMBER}" \
                        --listener allure_robotframework \
                        ${TEST_PATH}
                '''
            }
        }

        stage('Process Results') {
            steps {
                script {
                    echo "Processing test results..."
                }

                // Parse Robot Framework results
                sh '''
                    if [ -f ${RESULTS_DIR}/output.xml ]; then
                        echo "Test execution completed - output.xml found"
                        ls -lh ${RESULTS_DIR}/
                    else
                        echo "ERROR: No output.xml found!"
                        exit 1
                    fi
                '''
            }
        }

        stage('Upload to Elasticsearch') {
            steps {
                script {
                    echo "Uploading results to Elasticsearch..."
                }

                sh '''
                    # Run upload script
                    python3 scripts/upload_to_elastic.py \
                        --results-file ${RESULTS_DIR}/output.xml \
                        --elastic-url ${ELASTIC_ENDPOINT} \
                        --build-number ${BUILD_NUMBER} \
                        --branch ${GIT_BRANCH} || {
                        echo "WARNING: Failed to upload to Elasticsearch"
                        echo "Results are still available locally"
                    }
                '''
            }
        }

        stage('Generate Allure Report') {
            steps {
                script {
                    echo "Generating Allure report..."
                }

                sh '''
                    # Check if allure-results exist
                    if [ -d ${ALLURE_RESULTS_DIR} ] && [ "$(ls -A ${ALLURE_RESULTS_DIR})" ]; then
                        echo "Allure results found, generating report..."

                        # Generate Allure report using Docker container
                        docker run --rm \
                            -v ${ALLURE_RESULTS_DIR}:/app/allure-results \
                            -v ${ALLURE_REPORT_DIR}:/app/allure-report \
                            ${DOCKER_IMAGE}:${DOCKER_TAG} \
                            bash -c "allure generate /app/allure-results -o /app/allure-report --clean"

                        echo "Allure report generated successfully"
                        ls -lh ${ALLURE_REPORT_DIR}/
                    else
                        echo "WARNING: No Allure results found"
                    fi
                '''
            }
        }

        stage('Archive Artifacts') {
            steps {
                script {
                    echo "Archiving test artifacts..."
                }

                // Archive Robot Framework reports
                archiveArtifacts artifacts: 'results/*.html, results/*.xml, results/*.png',
                                 allowEmptyArchive: false,
                                 fingerprint: true

                // Archive logs
                archiveArtifacts artifacts: 'logs/*.log',
                                 allowEmptyArchive: true

                // Archive Allure report
                archiveArtifacts artifacts: 'allure-report/**/*',
                                 allowEmptyArchive: true

                // Publish Allure report (requires Allure Jenkins plugin)
                script {
                    try {
                        allure([
                            includeProperties: false,
                            jdk: '',
                            properties: [],
                            reportBuildPolicy: 'ALWAYS',
                            results: [[path: 'allure-results']]
                        ])
                    } catch (Exception e) {
                        echo "Allure plugin not available: ${e.message}"
                    }
                }

                // Publish Robot Framework results (requires Robot Framework plugin)
                script {
                    try {
                        step([
                            $class: 'RobotPublisher',
                            outputPath: 'results',
                            reportFileName: 'report.html',
                            logFileName: 'log.html',
                            outputFileName: 'output.xml',
                            disableArchiveOutput: false,
                            passThreshold: 100.0,
                            unstableThreshold: 75.0,
                            otherFiles: '**/*.png'
                        ])
                    } catch (Exception e) {
                        echo "Robot Framework plugin not available: ${e.message}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                echo "=========================================="
                echo "Pipeline Execution Summary"
                echo "=========================================="
                echo "Build: #${env.BUILD_NUMBER}"
                echo "Status: ${currentBuild.result ?: 'SUCCESS'}"
                echo "Duration: ${currentBuild.durationString}"
                echo "=========================================="
            }

            sh '''
                echo "Updating Allure report..."
                if [ -d "${ALLURE_RESULTS_DIR}" ] && [ "$(ls -A ${ALLURE_RESULTS_DIR} 2>/dev/null)" ]; then
                    cp -r ${ALLURE_RESULTS_DIR}/* /opt/rf-automation/allure-results/ 2>/dev/null || true
                    allure generate /opt/rf-automation/allure-results -o /opt/rf-automation/allure-report --clean 2>/dev/null || true
                    echo "Allure report updated - view at http://44.203.135.53:9090"
                fi
            '''

            sh '''
                echo "Cleaning up Docker resources..."
                docker system prune -f --volumes || true
            '''
        }

        success {
            echo "✓ Pipeline completed successfully!"

            // Optional: Send notification (configure according to your setup)
            // emailext subject: "RF Automation - Build #${BUILD_NUMBER} - SUCCESS",
            //          body: "Tests passed successfully. View results in Kibana.",
            //          to: "automation-team@company.com"
        }

        failure {
            echo "✗ Pipeline failed!"

            // Optional: Send failure notification
            // emailext subject: "RF Automation - Build #${BUILD_NUMBER} - FAILED",
            //          body: "Tests failed. Check Jenkins console output.",
            //          to: "automation-team@company.com"
        }

        unstable {
            echo "⚠ Pipeline unstable - some tests failed"
        }

        cleanup {
            // Clean workspace if needed
            // cleanWs()
            echo "Cleanup completed"
        }
    }
}
