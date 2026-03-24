pipeline {
    agent any

    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = credentials('ecr-registry')
        ECR_REPO     = 'roboshop'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        CLUSTER_NAME = 'roboshop-eks-cluster'
        NAMESPACE    = 'roboshop'
        APP_URL      = ''
        SONAR_AUTH_TOKEN = credentials('sonar-token')   // 🔥 Added
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }

        // ✅ FIXED SONARQUBE STAGE
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=roboshop \
                          -Dsonar.projectName=roboshop \
                          -Dsonar.sources=services \
                          -Dsonar.host.url=http://52.66.83.222:9000 \
                          -Dsonar.login=$SONAR_AUTH_TOKEN
                    '''
                }
            }
        }

        // 🔥 OPTIONAL (only works if webhook configured)
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

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

        stage('Cart Service') {
            steps {
                sh 'cd services/cart && npm install'
            }
        }

        stage('Catalogue Service') {
            steps {
                sh 'cd services/catalogue && npm install'
            }
        }

        stage('User Service') {
            steps {
                sh 'cd services/user && npm install'
            }
        }

        stage('Shipping Service') {
            steps {
                sh 'cd services/shipping && mvn clean package'
            }
        }

        stage('Frontend Service') {
            steps {
                sh 'echo "Frontend - no npm needed"'
            }
        }

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
                        done
                    """
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/cart
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/catalogue
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/user
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} -f docker/java.Dockerfile services/shipping
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} -f docker/nginx.Dockerfile services/frontend
                """
            }
        }

        stage('Push Images') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                        | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        for svc in cart catalogue user shipping frontend; do
                            docker push ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG}
                        done
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

                        for svc in cart catalogue user shipping frontend; do
                            helm upgrade --install \$svc helm/\$svc \
                            --namespace ${NAMESPACE} --create-namespace \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/\$svc \
                            --set image.tag=${IMAGE_TAG}
                        done
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
    }
}
