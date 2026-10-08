pipeline {
    agent any

    environment {
        DOCKERHUB_USER = "jebin2703"
        IMAGE_NAME     = "react-app"
        BUILD_DATE     = new Date().format('yyyyMMdd-HHmmss')
        IMAGE_TAG      = "${env.DOCKERHUB_USER}/${env.IMAGE_NAME}:${env.BUILD_DATE}"
    }

    stages {
        stage('Notify Start') {
            steps {
                withCredentials([string(credentialsId: 'gchat-webhook-url', variable: 'GCHAT_URL')]) {
                    sh """
                        curl -s -X POST -H 'Content-Type: application/json' \
                        -d '{"text": "🔵 Build STARTED: ${env.JOB_NAME} #${env.BUILD_NUMBER}\\nImage: ${IMAGE_TAG}"}' \
                        "\$GCHAT_URL"
                    """
                }
            }
        }

        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/jebinjamesb/react-app'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_TAG} -t ${DOCKERHUB_USER}/${IMAGE_NAME}:latest ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker push ${IMAGE_TAG}
                        docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

	        stage('Deploy to Minikube') {
            steps {
                sh """
                    sed -E "s|image: ${DOCKERHUB_USER}/${IMAGE_NAME}(:[^[:space:]]*)?|image: ${IMAGE_TAG}|" k8s-deployment.yaml | kubectl apply -f -

                    kubectl apply -f backup-cronjob.yaml

                    if ! kubectl rollout status deployment/react-app --timeout=120s; then
                        echo "Rollout failed, rolling back..."
                        kubectl rollout undo deployment/react-app
                        exit 1
                    fi
                """
            }
        }

    post {
        success {
            withCredentials([string(credentialsId: 'gchat-webhook-url', variable: 'GCHAT_URL')]) {
                sh """
                    curl -s -X POST -H 'Content-Type: application/json' \
                    -d '{"text": "✅ Build SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}\\nDeployed: ${IMAGE_TAG}"}' \
                    "\$GCHAT_URL"
                """
            }
        }
        failure {
            withCredentials([string(credentialsId: 'gchat-webhook-url', variable: 'GCHAT_URL')]) {
                sh """
                    curl -s -X POST -H 'Content-Type: application/json' \
                    -d '{"text": "❌ Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}\\nCheck Jenkins logs."}' \
                    "\$GCHAT_URL"
                """
            }
        }
    }
}
