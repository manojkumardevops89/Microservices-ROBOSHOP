pipeline {
    agent any

    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = credentials('ecr-registry')
        ECR_REPO     = 'roboshop'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        CLUSTER_NAME = 'roboshop-eks-cluster'
        NAMESPACE    = 'roboshop'
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

        // 2. BUILD SERVICES

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

        // 3. DOCKER BUILD

        stage('Docker Build - Cart') {
            steps {
                sh '''
                docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} \
                -f docker/nodejs.Dockerfile services/cart
                '''
            }
        }

        stage('Docker Build - Catalogue') {
            steps {
                sh '''
                docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} \
                -f docker/nodejs.Dockerfile services/catalogue
                '''
            }
        }

        stage('Docker Build - User') {
            steps {
                sh '''
                docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} \
                -f docker/nodejs.Dockerfile services/user
                '''
            }
        }

        stage('Docker Build - Shipping') {
            steps {
                sh '''
                docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} \
                -f docker/java.Dockerfile services/shipping
                '''
            }
        }

        stage('Docker Build - Frontend') {
            steps {
                sh '''
                docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} \
                -f docker/nginx.Dockerfile services/frontend
                '''
            }
        }

        // 4. PUSH TO ECR

        stage('Push Images') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                    aws ecr get-login-password --region ${AWS_REGION} \
                    | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                    docker push ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}
                    '''
                }
            }
        }

        // 5. DEPLOY TO EKS

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

                    helm upgrade --install cart helm/cart --namespace ${NAMESPACE} --create-namespace \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/cart \
                        --set image.tag=${IMAGE_TAG}

                    helm upgrade --install catalogue helm/catalogue --namespace ${NAMESPACE} \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/catalogue \
                        --set image.tag=${IMAGE_TAG}

                    helm upgrade --install user helm/user --namespace ${NAMESPACE} \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/user \
                        --set image.tag=${IMAGE_TAG}

                    helm upgrade --install shipping helm/shipping --namespace ${NAMESPACE} \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/shipping \
                        --set image.tag=${IMAGE_TAG}

                    helm upgrade --install frontend helm/frontend --namespace ${NAMESPACE} \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend \
                        --set image.tag=${IMAGE_TAG}
                    '''
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
