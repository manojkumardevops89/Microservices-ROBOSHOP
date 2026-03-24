pipeline {
    agent any
    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = credentials('ecr-registry')
        ECR_REPO     = 'roboshop'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        CLUSTER_NAME = 'roboshop-eks-cluster'
        NAMESPACE    = 'roboshop'
        APP_URL      = ''   // fetched dynamically after EKS Deploy
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

        // 2. SONARQUBE - Code Quality Scan
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=roboshop \
                          -Dsonar.sources=services \
                          -Dsonar.java.binaries=services/shipping/target/classes
                    '''
                }
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // 3. TERRAFORM - Create Infrastructure
        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform plan'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        // 4. BUILD SERVICES
        stage('Cart Service') {
            steps {
                sh '''
                    cd services/cart
                    npm install
                '''
            }
        }

        stage('Catalogue Service') {
            steps {
                sh '''
                    cd services/catalogue
                    npm install
                '''
            }
        }

        stage('User Service') {
            steps {
                sh '''
                    cd services/user
                    npm install
                '''
            }
        }

        stage('Shipping Service') {
            steps {
                sh '''
                    cd services/shipping
                    mvn clean package
                '''
            }
        }

        stage('Frontend Service') {
            steps {
                sh '''
                    cd services/frontend
                    echo "Frontend - no npm needed"
                '''
            }
        }

        // 5. CREATE ECR REPOSITORIES (if not exists)
        stage('Create ECR Repositories') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        for svc in frontend cart user catalogue shipping; do
                            aws ecr describe-repositories \
                                --repository-names ${ECR_REPO}/\$svc \
                                --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository \
                                --repository-name ${ECR_REPO}/\$svc \
                                --region ${AWS_REGION}
                            echo "ECR repo ready: ${ECR_REPO}/\$svc"
                        done
                    """
                }
            }
        }

        // 6. DOCKER BUILD
        stage('Docker Build - Cart') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} \
                    -f docker/nodejs.Dockerfile services/cart
                """
            }
        }

        stage('Docker Build - Catalogue') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} \
                    -f docker/nodejs.Dockerfile services/catalogue
                """
            }
        }

        stage('Docker Build - User') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} \
                    -f docker/nodejs.Dockerfile services/user
                """
            }
        }

        stage('Docker Build - Shipping') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} \
                    -f docker/java.Dockerfile services/shipping
                """
            }
        }

        stage('Docker Build - Frontend') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} \
                    -f docker/nginx.Dockerfile services/frontend
                """
            }
        }

        // 7. TRIVY - Container Image Scan
        stage('Trivy Scan - Cart') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 \
                        ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}
                """
            }
        }

        stage('Trivy Scan - Catalogue') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 \
                        ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}
                """
            }
        }

        stage('Trivy Scan - User') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 \
                        ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}
                """
            }
        }

        stage('Trivy Scan - Shipping') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 \
                        ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}
                """
            }
        }

        stage('Trivy Scan - Frontend') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 \
                        ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}
                """
            }
        }

        // 8. PUSH TO ECR
        stage('Push Images') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                        | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        docker push ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}
                    """
                }
            }
        }

        // 9. DEPLOY TO EKS
        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

                        helm upgrade --install cart helm/cart \
                            --namespace ${NAMESPACE} --create-namespace \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/cart \
                            --set image.tag=${IMAGE_TAG}

                        helm upgrade --install catalogue helm/catalogue \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/catalogue \
                            --set image.tag=${IMAGE_TAG}

                        helm upgrade --install user helm/user \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/user \
                            --set image.tag=${IMAGE_TAG}

                        helm upgrade --install shipping helm/shipping \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/shipping \
                            --set image.tag=${IMAGE_TAG}

                        helm upgrade --install frontend helm/frontend \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend \
                            --set image.tag=${IMAGE_TAG}
                    """

                    // Dynamically fetch LoadBalancer URL after deployment
                    script {
                        echo "Waiting for Ingress LoadBalancer URL..."
                        def appUrl = ''
                        for (int i = 1; i <= 20; i++) {
                            appUrl = sh(
                                script: """
                                    kubectl get ingress -n ${NAMESPACE} \
                                        -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
                                """,
                                returnStdout: true
                            ).trim()
                            if (appUrl) {
                                echo "LoadBalancer URL: http://${appUrl}"
                                env.APP_URL = "http://${appUrl}"
                                break
                            }
                            if (i == 20) {
                                echo "WARNING: LoadBalancer URL not assigned. OWASP scan will be skipped."
                            } else {
                                echo "Attempt ${i}/20 - not ready yet. Retrying in 15s..."
                                sleep(15)
                            }
                        }
                    }
                }
            }
        }

        // 10. OWASP ZAP - Dynamic Application Security Testing
        stage('OWASP ZAP Scan') {
            steps {
                script {
                    if (!env.APP_URL || env.APP_URL.trim() == '') {
                        echo "APP_URL not set. Skipping OWASP ZAP scan."
                    } else {
                        echo "Running OWASP ZAP scan against: ${env.APP_URL}"
                        sh """
                            mkdir -p zap-reports
                            docker run --rm \
                                -v \$(pwd)/zap-reports:/zap/wrk/:rw \
                                ghcr.io/zaproxy/zaproxy:stable \
                                zap-baseline.py -t ${env.APP_URL} -r zap-report.html -I
                        """
                    }
                }
            }
        }

        // 11. PROWLER - AWS Cloud Security Scan
        stage('Prowler Cloud Scan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        prowler aws \
                            --region ${AWS_REGION} \
                            --services iam s3 eks ec2 \
                            --severity high critical
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS - Build #${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED - Build #${BUILD_NUMBER}"
        }
        always {
            node(null) {
                cleanWs()
            }
        }
    }
}
