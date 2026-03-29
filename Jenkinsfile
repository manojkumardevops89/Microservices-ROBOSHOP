pipeline {
    agent any
    environment {
        PATH             = "/opt/sonar-scanner/bin:${env.PATH}"
        AWS_REGION       = 'us-east-1'
        ECR_REGISTRY     = credentials('ecr-registry')
        ECR_REPO         = 'roboshop'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        CLUSTER_NAME     = 'roboshop-eks'
        NAMESPACE        = 'roboshop'
        SONAR_AUTH_TOKEN = credentials('sonar-token')
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }
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
        stage('Build Services') {
            steps {
                // Node.js Services
                sh 'cd services/cart && npm install'
                sh 'cd services/catalogue && npm install'
                sh 'cd services/user && npm install'
                // Java Service
                sh 'cd services/shipping && mvn clean package'
            }
        }
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=roboshop \
                        -Dsonar.projectName=roboshop \
                        -Dsonar.sources=services \
                        -Dsonar.java.binaries=services/shipping/target/classes \
                        '-Dsonar.exclusions=**/*.jar,**/node_modules/**,**/target/**'
                    '''
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        stage('Docker Build') {
            steps {
                // Database Images
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/mongodb:${IMAGE_TAG} Databses/Mongodb"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/mysql:${IMAGE_TAG} Databses/MYSQL"
                // Microservice Images
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} services/cart"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} services/catalogue"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} services/user"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} services/shipping"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} services/frontend"
            }
        }
        stage('Trivy Scan') {
            steps {
                sh 'trivy fs --severity HIGH,CRITICAL services/'
            }
        }
        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    // Push Database Images
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/mongodb:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/mysql:${IMAGE_TAG}"
                    // Push Microservice Images
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}"
                    sh "docker push ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}"
                }
            }
        }
        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                    // Deploy Databases First
                    sh "helm upgrade --install mongodb Databses/Mongodb/helm --namespace ${NAMESPACE} --create-namespace --set deployment.imageURL=${ECR_REGISTRY}/${ECR_REPO}/mongodb --set deployment.imageVersion=${IMAGE_TAG}"
                    sh "helm upgrade --install mysql Databses/MYSQL/helm --namespace ${NAMESPACE} --set deployment.imageURL=${ECR_REGISTRY}/${ECR_REPO}/mysql --set deployment.imageVersion=${IMAGE_TAG}"
                    sh "helm upgrade --install redis Databses/redis/helm --namespace ${NAMESPACE}"
                    sh "helm upgrade --install rabbitmq Databses/RabbitMQ/helm --namespace ${NAMESPACE}"
                    // Wait for Databases Ready
                    sh "kubectl wait --for=condition=ready pod -l app=mongodb -n ${NAMESPACE} --timeout=120s"
                    sh "kubectl wait --for=condition=ready pod -l app=mysql -n ${NAMESPACE} --timeout=120s"
                    sh "kubectl wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=120s"
                    sh "kubectl wait --for=condition=ready pod -l app=rabbitmq -n ${NAMESPACE} --timeout=120s"
                    // Deploy Microservices
                    sh "helm upgrade --install catalogue helm/catalogue --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/catalogue --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install user helm/user --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/user --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install cart helm/cart --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/cart --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install shipping helm/shipping --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/shipping --set image.tag=${IMAGE_TAG}"
                    // Deploy Frontend Last
                    sh "helm upgrade --install frontend helm/frontend --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend --set image.tag=${IMAGE_TAG}"
                    script {
                        def alb = ''
                        for (int i = 0; i < 20; i++) {
                            alb = sh(
                                script: "kubectl get ingress roboshop-ingress -n roboshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                returnStdout: true
                            ).trim()
                            if (alb && !alb.contains(" ")) {
                                echo "✅ ALB Ready: ${alb}"
                                break
                            }
                            echo "⏳ Waiting for ALB... attempt ${i+1}/20"
                            sleep(15)
                        }
                        env.APP_URL = "http://${alb}"
                        echo "✅ APP_URL = ${env.APP_URL}"
                    }
                }
            }
        }
    }
    post {
        success {
            echo "SUCCESS 🚀 - Build #${BUILD_NUMBER}"
        }
        failure {
            echo "FAILED ❌ - Build #${BUILD_NUMBER}"
        }
    }
}
