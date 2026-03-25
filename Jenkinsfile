pipeline {
    agent any
    environment {
        PATH             = "/opt/sonar-scanner/bin:${env.PATH}"
        AWS_REGION       = 'us-east-1'
        ECR_REGISTRY     = credentials('ecr-registry')
        ECR_REPO         = 'roboshop'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        CLUSTER_NAME     = 'roboshop-eks-cluster'
        NAMESPACE        = 'roboshop'
        APP_URL          = 'http://your-app-loadbalancer-url'
        SONAR_AUTH_TOKEN = credentials('sonar-token')
    }
    stages {

        // STAGE 1: CHECKOUT
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }

        // STAGE 2: TERRAFORM
        stage('Terraform Infra') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform init'
                        sh 'terraform validate'
                        sh 'terraform plan -out=tfplan'
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }

        // STAGE 3: BUILD
        stage('Build Services') {
            steps {
                sh 'cd services/cart && npm install'
                sh 'cd services/catalogue && npm install'
                sh 'cd services/user && npm install'
                sh 'cd services/shipping && mvn clean package'
            }
        }

        // STAGE 4: SONARQUBE
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh 'sonar-scanner -Dsonar.projectKey=roboshop -Dsonar.projectName=roboshop -Dsonar.sources=services -Dsonar.host.url=http://52.66.83.222:9000 -Dsonar.login=$SONAR_AUTH_TOKEN -Dsonar.java.binaries=services/shipping/target/classes -Dsonar.exclusions=**/*.jar'
                }
            }
        }

        // STAGE 5: QUALITY GATE
        stage('Quality Gate') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        // STAGE 6: DOCKER BUILD
        stage('Docker Build') {
            steps {
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/cart"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/catalogue"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/user"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} -f docker/java.Dockerfile services/shipping"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} -f docker/nginx.Dockerfile services/frontend"
            }
        }

        // STAGE 7: TRIVY SCAN
        stage('Trivy Scan') {
            steps {
                sh 'mkdir -p reports/trivy'
                sh "trivy fs --format table --exit-code 0 --severity HIGH,CRITICAL --output reports/trivy/fs-report.txt services/"
                sh "trivy image --format table --exit-code 0 --severity HIGH,CRITICAL --output reports/trivy/cart-report.txt ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}"
                sh "trivy image --format table --exit-code 0 --severity HIGH,CRITICAL --output reports/trivy/catalogue-report.txt ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}"
                sh "trivy image --format table --exit-code 0 --severity HIGH,CRITICAL --output reports/trivy/user-report.txt ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}"
                sh "trivy image --format table --exit-code 0 --severity HIGH,CRITICAL --output reports/trivy/shipping-report.txt ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}"
                sh "trivy image --format table --exit-code 0 --severity HIGH,CRITICAL --output reports/trivy/frontend-report.txt ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}"
            }
        }

        // STAGE 8: PUSH TO ECR
        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}"
                }
            }
        }

        // STAGE 9: DEPLOY TO EKS
        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                    sh "helm upgrade --install cart helm/cart --namespace ${NAMESPACE} --create-namespace --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/cart --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install catalogue helm/catalogue --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/catalogue --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install user helm/user --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/user --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install shipping helm/shipping --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/shipping --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install frontend helm/frontend --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend --set image.tag=${IMAGE_TAG}"
                }
            }
        }

        // STAGE 10: OWASP ZAP SCAN
        stage('OWASP ZAP Scan') {
            steps {
                sh 'mkdir -p reports/zap'
                sh 'docker run --rm -v $(pwd)/reports/zap:/zap/wrk/:rw ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t http://your-app-loadbalancer-url -r zap-report.html -I'
            }
        }

        // STAGE 11: PROWLER
        stage('Prowler AWS Security Scan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh 'mkdir -p reports/prowler'
                    sh 'prowler aws --region us-east-1 --output-formats html json --output-directory reports/prowler -M html'
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
            echo "Security Reports Archived"
        }
        success {
            echo "Pipeline SUCCESS - Build #${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED - Build #${BUILD_NUMBER}"
        }
    }
}
