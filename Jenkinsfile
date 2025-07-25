pipeline {
    agent {
        node {
            label 'docker-agent-python'
        }
    }
    environment {
        DOCKER_HOST = 'tcp://jenkins-proxy:2375'
    }
    triggers {
        pollSCM '* * * * *'
    }
    stages {
        stage('Load env file') {
            steps {
                echo 'Loading environment variables from GCP credentials'
                echo 'Make sure the GCP_ENV_FILE and GCP_KEY_FILE credentials are set up in Jenkins'
                withCredentials([file(credentialsId: 'GCP_ENV_FILE', variable: 'ENV_FILE')]) {
                    sh "cp '$ENV_FILE' '$WORKSPACE/.env'"
                }
                withCredentials([file(credentialsId: 'GCP_KEY_FILE', variable: 'KEY_FILE')]) {
                    sh "cp '$KEY_FILE' '$WORKSPACE/gcp_key.json'"
                }
            }
        }
        stage('Test env variables') {
            steps {
                echo 'Verifying environment variables are set correctly'
                sh '''
                . "$WORKSPACE/.env"
                echo "GCP_PROJECT: $GCP_PROJECT"
                echo "GCP_REGION: $GCP_REGION"
                '''
                echo "Environment variables are set correctly"
            }
        }
        stage('Setup Python Environment') {
            steps {
                echo 'Checking Python version'
                sh 'python3 --version'
                echo 'Creating Python virtual environment'
                sh 'python3 -m venv .venv'
                echo 'Activating virtual environment'
                sh '. .venv/bin/activate'
            }
        }
        stage('Build Console App') {
            steps {
                echo 'Navigating to app directory'
                echo 'Installing application dependencies'
                sh '''
                . .venv/bin/activate
                cd console_app
                pip3 install -r requirements.txt
                '''
            }
        }
        stage('Test Console App') {
            steps {
                echo 'Testing application functionality'
                sh '''
                . .venv/bin/activate
                cd console_app
                python3 HelloWorld.py
                '''
            }
        }
        stage('Install Web App Dependencies') {
            steps {
                echo 'Navigating to webapp directory'
                echo 'Installing Flask dependencies'
                sh '''
                . .venv/bin/activate
                cd website_app
                pip3 install -r requirements.txt
                '''
            }
        }
        stage('Build Container Image') {
            steps {
                echo 'Building Docker container image'
                echo "Using Docker host: ${DOCKER_HOST}"
                sh "docker build -t python-simple-flask:${BUILD_NUMBER} ."
                echo 'Tagging image as latest'
                sh "docker tag python-simple-flask:${BUILD_NUMBER} python-simple-flask:latest"
            }
        }
        stage('Test Container') {
            steps {
                echo 'Verifying Docker container image exists'
                echo "Checking for image python-simple-flask:${BUILD_NUMBER}"
                sh 'docker images | grep python-simple-flask'
                echo 'Displaying Docker host information'
                sh 'docker info'
                echo 'Starting container in test mode'
                sh "docker run -d --name flask-test-container -p 30001:30000 --network jenkins python-simple-flask:${BUILD_NUMBER}"
                echo 'Waiting for container to initialize'
                sh 'sleep 5'
                echo 'Displaying container logs'
                sh 'docker logs flask-test-container'
                echo 'Testing container health endpoint'
                sh 'curl -s http://flask-test-container:30000/ | grep "success" || exit 1'
                echo 'Stopping test container'
                sh 'docker stop flask-test-container'
                echo 'Removing test container'
                sh 'docker rm flask-test-container'
            }
        }
        stage('Deploy Container') {
            steps {
                echo 'Verifying Docker availability'
                sh 'docker --version || (echo "Docker not available" && exit 1)'
                echo 'Stopping existing production container'
                sh 'docker stop flask-production-container || true'
                echo 'Removing existing production container'
                sh 'docker rm flask-production-container || true'
                echo 'Starting new production container'
                sh "docker run -d --name flask-production-container -p 30000:30000 --network jenkins python-simple-flask:${BUILD_NUMBER}"
                echo 'Verifying production container is running'
                sh 'docker ps | grep flask-production-container || (echo "Container failed to start" && exit 1)'
                echo 'Flask server container deployed on port 30000'
            }
        }
        stage('Push to GCR') {
            steps {
                echo 'Pushing Docker image to Google Container Registry'
                echo 'Authenticating with Google Cloud'
                sh '''
                    set +x
                    set -a
                    cat "$WORKSPACE/.env" | tr -d '\r' | sed 's/[[:space:]]*$//' > "$WORKSPACE/.env.clean"
                    . "$WORKSPACE/.env.clean"
                    set +a
                    gcloud auth activate-service-account --key-file="$WORKSPACE/gcp_key.json" --project="$GCP_PROJECT"
                    gcloud config set project "$GCP_PROJECT"
                    gcloud auth configure-docker
                    docker tag python-simple-flask:${BUILD_NUMBER} gcr.io/${GCP_PROJECT}/python-simple-flask:${BUILD_NUMBER}
                    docker push gcr.io/${GCP_PROJECT}/python-simple-flask:${BUILD_NUMBER}
                    docker tag python-simple-flask:latest gcr.io/${GCP_PROJECT}/python-simple-flask:latest
                    docker push gcr.io/${GCP_PROJECT}/python-simple-flask:latest
                '''
            }
        }
        stage('Deploy to Cloud Run') {
            steps {
                sh '''
                    set +x
                    . "$WORKSPACE/.env.clean"
                    gcloud run deploy python-simple-service \
                        --project="$GCP_PROJECT" \
                        --region="$GCP_REGION" \
                        --image=gcr.io/${GCP_PROJECT}/python-simple-flask:latest \
                        --platform=managed \
                        --allow-unauthenticated \
                        --port=30000
                '''
            }
        }
    }
    post {
        always {
            echo 'Starting cleanup process'
            echo 'Deactivating virtual environment'
            sh '''
            if [ -d ".venv" ]; then
              . .venv/bin/activate
              deactivate
              rm -rf .venv
            fi
            '''
            echo 'Cleaning up test containers'
            sh 'docker stop flask-test-container || true'
            sh 'docker rm flask-test-container || true'
            echo 'Cleaning up old Docker images'
            sh '''
            docker image ls 'python-simple-flask:*' --format '{{.Repository}}:{{.Tag}}' |
            grep -v 'latest' | sort -r | tail -n +6 | xargs -r docker image rm || true
            '''
        }
        success {
            echo 'Pipeline completed successfully'
            echo 'Performing deployment health check'
            sh '''
            HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://flask-production-container:30000/)
            if [ "$HEALTH_CHECK" = "200" ]; then
              echo "Deployment verified - service is healthy"
            else
              echo "Warning: Deployment health check returned $HEALTH_CHECK - manual verification recommended"
            fi
            '''
        }
        failure {
            echo 'Pipeline execution failed'
            echo 'Attempting automatic rollback'
            sh '''
            PREVIOUS_IMAGE=$(docker image ls 'python-simple-flask:*' --format '{{.Repository}}:{{.Tag}}' |
                            grep -v 'latest' | grep -v "${BUILD_NUMBER}" | sort -r | head -n 1)

            if [ -n "$PREVIOUS_IMAGE" ]; then
              echo "Rolling back to previous version: $PREVIOUS_IMAGE"
              docker stop flask-production-container || true
              docker rm flask-production-container || true
              docker run -d --name flask-production-container -p 30000:30000 $PREVIOUS_IMAGE
              echo "Rollback completed"
            else
              echo "No previous version found for rollback"
            fi
            '''
        }
    }
}
