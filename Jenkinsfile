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

        // ✅ STAGE 1: CHECKOUT
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }

        // ✅ STAGE 2: BUILD
        stage('Build Services') {
            steps {
                sh '''
                    cd services/cart && npm install
                    cd ../catalogue && npm install
                    cd ../user && npm install
                    cd ../shipping && mvn clean package
                '''
            }
        }

        // ✅ STAGE 3: SONARQUBE
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

        // ✅ STAGE 4: DOCKER BUILD
        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} \
                        -f docker/nodejs.Dockerfile services/cart

                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} \
                        -f docker/nodejs.Dockerfile services/catalogue

                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} \
                        -f docker/nodejs.Dockerfile services/user

                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} \
                        -f docker/java.Dockerfile services/shipping

                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} \
                        -f docker/nginx.Dockerfile services/frontend
                """
            }
        }

        // ✅ STAGE 5: TRIVY SCAN
        stage('Trivy Scan') {
            steps {
                sh """
                    mkdir -p reports/trivy

                    echo "=== Trivy Filesystem Scan ==="
                    trivy fs \
                        --format table \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --output reports/trivy/fs-report.txt \
                        services/

                    echo "=== Trivy Image Scan - cart ==="
                    trivy image \
                        --format table \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --output reports/trivy/cart-report.txt \
                        ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}

                    echo "=== Trivy Image Scan - catalogue ==="
                    trivy image \
                        --format table \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --output reports/trivy/catalogue-report.txt \
                        ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}

                    echo "=== Trivy Image Scan - user ==="
                    trivy image \
                        --format table \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --output reports/trivy/user-report.txt \
                        ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}

                    echo "=== Trivy Image Scan - shipping ==="
                    trivy image \
                        --format table \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --output reports/trivy/shipping-report.txt \
                        ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}

                    echo "=== Trivy Image Scan - frontend ==="
                    trivy image \
                        --format table \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --output reports/trivy/frontend-report.txt \
                        ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}
                """
            }
        }

        // ✅ STAGE 6: PUSH TO ECR
        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        // Create repos if not exists
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/cart \
                            --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository --repository-name ${ECR_REPO}/cart \
                            --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/catalogue \
                            --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository --repository-name ${ECR_REPO}/catalogue \
                            --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/user \
                            --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository --repository-name ${ECR_REPO}/user \
                            --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/shipping \
                            --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository --repository-name ${ECR_REPO}/shipping \
                            --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/frontend \
                            --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository --repository-name ${ECR_REPO}/frontend \
                            --region ${AWS_REGION}

                        // Login and Push
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

        // ✅ STAGE 7: DEPLOY TO EKS
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
                }
            }
        }

        // ✅ STAGE 8: OWASP ZAP - Runs AFTER deploy so it can hit live app
        stage('OWASP ZAP Scan') {
            steps {
                sh """
                    mkdir -p reports/zap

                    docker run --rm \
                        -v \$(pwd)/reports/zap:/zap/wrk/:rw \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py \
                            -t ${APP_URL} \
                            -r zap-report.html \
                            -x zap-report.xml \
                            -J zap-report.json \
                            -I
                """
            }
        }

        // ✅ STAGE 9: PROWLER - AWS Security Audit
        stage('Prowler AWS Security Scan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                        mkdir -p reports/prowler

                        prowler aws \
                            --region us-east-1 \
                            --output-formats html json \
                            --output-directory reports/prowler \
                            --checks ec2_instance_imdsv2_enabled \
                                     s3_bucket_public_access_block \
                                     eks_cluster_secrets_encrypted \
                                     iam_avoid_root_usage \
                            -M html
                    '''
                }
            }
        }

    }

    post {
        always {
            // ✅ Archive ALL security reports
            archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
            echo "=========================================="
            echo "Security Reports Archived:"
            echo "  - reports/trivy/     → Trivy scan results"
            echo "  - reports/zap/       → OWASP ZAP results"
            echo "  - reports/prowler/   → Prowler AWS audit"
            echo "=========================================="
        }
        success {
            echo "✅ Pipeline SUCCESS - Build #${BUILD_NUMBER}"
        }
        failure {
            echo "❌ Pipeline FAILED - Build #${BUILD_NUMBER}"
        }
    }
}
