pipeline {
    agent any

    tools {
        jdk 'JDK17'
        maven 'Maven3'
    }

    environment {
        SONAR_PROJECT_KEY = 'devsecops-demo-app'
        DOCKER_IMAGE_NAME = 'devsecops-demo-app'
        DOCKER_IMAGE_TAG  = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                // Pulls the latest code from the GitHub repo configured in the Jenkins job
                checkout scm
            }
        }

        stage('Build with Maven') {
            steps {
                // Compiles the code, runs unit tests, and packages it into a JAR
                sh 'mvn clean package'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                // withSonarQubeEnv pulls in the server URL + token configured in
                // Manage Jenkins -> System -> SonarQube servers (name must match)
                withSonarQubeEnv('MySonarQube') {
                    sh """
                        mvn sonar:sonar \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY}
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                // Pauses the pipeline and waits for SonarQube's pass/fail verdict.
                // abortPipeline: true means a failed quality gate stops the build here.
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('OWASP Dependency-Check') {
            steps {
                // withCredentials pulls the NVD key from Jenkins Credentials store
                // and exposes it as an env var only for this block (not logged/printed)
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_KEY')]) {
                    // Scans pom.xml dependencies against the NVD vulnerability database
                    dependencyCheck additionalArguments: "--scan . --format HTML --format XML --nvdApiKey ${NVD_KEY}", odcInstallation: 'OWASP-DC'
                }
                dependencyCheckPublisher pattern: 'dependency-check-report.xml'
            }
        }

        stage('Docker Build') {
            steps {
                // Builds the image using the multi-stage Dockerfile in the repo root
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ."
            }
        }

        stage('Trivy Scan') {
            steps {
                // Scans the freshly built image. Fails the build if CRITICAL vulns are found.
                sh """
                    trivy image --timeout 15m --exit-code 1 --severity CRITICAL \
                    ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                """
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. Build result: ${currentBuild.result}"
        }
        success {
            echo "Pipeline succeeded! Image ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} is ready."
        }
        failure {
            echo "Pipeline failed. Check the stage logs above to see where it broke."
        }
    }
}
