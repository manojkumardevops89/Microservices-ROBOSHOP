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
        // 1. CHECKOUT
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }
        // 2. TERRAFORM INFRA (EKS, VPC)
        stage('Terraform Infra') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {  // ✅ Capital T
                        sh 'terraform init'
                        sh 'terraform validate'
                        sh 'terraform plan -out=tfplan'
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
        // 3. BUILD
        stage('Build Services') {
            steps {
                sh 'cd services/cart && npm install'
                sh 'cd services/catalogue && npm install'
                sh 'cd services/user && npm install'
                sh 'cd services/shipping && mvn clean package'
            }
        }
        // 4. SONARQUBE
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=roboshop \
                        -Dsonar.projectName=roboshop \
                        -Dsonar.sources=services \
                        -Dsonar.host.url=http://52.66.83.222:9000 \
                        -Dsonar.login=$SONAR_AUTH_TOKEN \
                        -Dsonar.java.binaries=services/shipping/target/classes \
                        -Dsonar.exclusions=**/*.jar
                    '''
                }
            }
        }
        // 5. QUALITY GATE
        stage('Quality Gate') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        // 6. DOCKER BUILD
        stage('Docker Build') {
            steps {
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/cart"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/catalogue"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/user"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} -f docker/java.Dockerfile services/shipping"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} -f docker/nginx.Dockerfile services/frontend"
            }
        }
        // 7. TRIVY
        stage('Trivy Scan') {
            steps {
                sh 'trivy fs --severity HIGH,CRITICAL services/'
            }
        }
        // 8. PUSH TO ECR
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
        // 9. DEPLOY TO EKS + FETCH ALB
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
                    script {
                        // ✅ Retry up to 10 times with 30s gap = 5 mins total
                        def alb = ''
                        retry(10) {
                            sleep(30)
                            alb = sh(
                                script: "kubectl get ingress -n ${NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'",
                                returnStdout: true
                            ).trim()
                            if (alb == '') {
                                error("ALB hostname not yet available, retrying...")
                            }
                        }
                        env.APP_URL = "http://${alb}"
                        echo "✅ APP_URL = ${env.APP_URL}"
                    }
                }
            }
        }
        // 10. TERRAFORM ROUTE53
        stage('Terraform Route53') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    script {
                        // ✅ Safe null check before replace
                        if (!env.APP_URL) {
                            error("APP_URL is empty! Cannot run Terraform Route53.")
                        }
                        def alb_dns = env.APP_URL.replace("http://", "")
                        echo "ALB DNS: ${alb_dns}"
                        dir('Terraform') {  // ✅ Capital T - matches your folder
                            sh """
                                terraform init
                                terraform apply -auto-approve \
                                  -var="alb_dns_name=${alb_dns}"
                            """
                        }
                    }
                }
            }
        }
        // 11. OWASP
        stage('OWASP ZAP Scan') {
            steps {
                script {
                    // ✅ Safe check before using APP_URL
                    if (!env.APP_URL) {
                        error("APP_URL is empty! Cannot run OWASP scan.")
                    }
                    sh """
                        docker run --rm \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py -t ${env.APP_URL} -r zap-report.html -I
                    """
                }
            }
        }
        // 12. PROWLER
        stage('Prowler Scan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh "prowler aws --region ${AWS_REGION}"
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
