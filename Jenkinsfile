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
                sh 'cd services/cart && npm install'
                sh 'cd services/catalogue && npm install'
                sh 'cd services/user && npm install'
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
                        -Dsonar.host.url=http://52.66.83.222:9000 \
                        -Dsonar.login=$SONAR_AUTH_TOKEN \
                        -Dsonar.java.binaries=services/shipping/target/classes \
                        -Dsonar.exclusions=**/*.jar
                    '''
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        stage('Docker Build') {
            steps {
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/cart"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/catalogue"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/user"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} -f docker/java.Dockerfile services/shipping"
                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} -f docker/nginx.Dockerfile services/frontend"
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
                    sh "helm upgrade --install cart helm/cart --namespace ${NAMESPACE} --create-namespace --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/cart --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install catalogue helm/catalogue --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/catalogue --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install user helm/user --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/user --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install shipping helm/shipping --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/shipping --set image.tag=${IMAGE_TAG}"
                    sh "helm upgrade --install frontend helm/frontend --namespace ${NAMESPACE} --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend --set image.tag=${IMAGE_TAG}"
                    script {
                        // Wait for ALB to be ready
def alb_dns = ""
for (int i = 0; i < 20; i++) {
    alb_dns = sh(
        script: "kubectl get ingress roboshop-ingress -n roboshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
        returnStdout: true
    ).trim()
    if (alb_dns && !alb_dns.contains(" ")) {
        echo "✅ ALB Ready: ${alb_dns}"
        break
    }
    echo "⏳ Waiting for ALB... attempt ${i+1}/20"
    sleep(15)
}
if (!alb_dns) {
    error("❌ ALB not ready after waiting")
}

dir('Terraform') {
    sh """
        terraform init
        terraform apply -auto-approve \
            -var="alb_dns_name=${alb_dns}"
    """
}
                        }
                        // FIX 3: Store clean ALB DNS separately
                        env.ALB_DNS = alb
                        env.APP_URL = "http://${alb}"
                        echo "✅ ALB_DNS = ${env.ALB_DNS}"
                        echo "✅ APP_URL = ${env.APP_URL}"
                    }
                }
            }
        }
        stage('Terraform Route53') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    script {
                        if (!env.ALB_DNS) {
                            error("ALB_DNS is empty! Cannot run Terraform Route53.")
                        }
                        // FIX 4: Use ALB_DNS directly, no string manipulation needed
                        echo "ALB DNS: ${env.ALB_DNS}"
                        dir('Terraform') {
                            sh """
                                terraform init
                                terraform apply -auto-approve \
                                  -var="alb_dns_name=${env.ALB_DNS}"
                            """
                        }
                    }
                }
            }
        }
        stage('OWASP ZAP Scan') {
            steps {
                script {
                    if (!env.APP_URL) {
                        error("APP_URL is empty! Cannot run OWASP scan.")
                    }
                    sh "mkdir -p ${WORKSPACE}/zap-reports"
                    sh """
                      docker run --rm \
                     -v ${WORKSPACE}/zap-reports:/zap/wrk/:rw \
                     ghcr.io/zaproxy/zaproxy:stable \
                    zap-baseline.py \
                   -t ${env.APP_URL} \
                   -r zap-report.html \
                   -I
                """
                }
            }
        }
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
